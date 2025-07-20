import {ethers, deployments, getNamedAccounts, network} from "hardhat";
import {
    MyToken,
    NFTPoolLockAndRelease,
    NFTPoolBurnAndMint,
    CCIPLocalSimulator,
    WrapperMyToken
} from "../typechain-types";
import {assert, expect} from "chai";
import {Typed, BigNumberish} from "@ethers/lib.commonjs";

let myToken: MyToken;
let nftPoolLockAndRelease: NFTPoolLockAndRelease;
let nftPoolBurnAndMint: NFTPoolBurnAndMint;
let ccipLocalSimulator: CCIPLocalSimulator;
let wrapperMyToken: WrapperMyToken;
let deployer: any;
let chainSelector: bigint;
before(async () => {
    // 初始化测试环境
    // 连接到源链和目标链
    // 部署必要的合约
    deployer = (await getNamedAccounts()).deployer;
    console.log("deployer is", deployer);
    await deployments.fixture(["all"]);
    myToken = await ethers.getContract("MyToken", deployer);
    nftPoolLockAndRelease = await ethers.getContract("NFTPoolLockAndRelease", deployer);
    nftPoolBurnAndMint = await ethers.getContract("NFTPoolBurnAndMint", deployer);
    ccipLocalSimulator = await ethers.getContract("CCIPLocalSimulator", deployer);
    wrapperMyToken = await ethers.getContract("WrapperMyToken", deployer);
    const config = await ccipLocalSimulator.configuration();
    chainSelector = config.chainSelector_;
    // 添加白名单
    console.log("add whitelist address", deployer)
    await myToken.addToWhitelistBatch([deployer, nftPoolLockAndRelease.target]);
});

describe(
    "测试从源链到目标链的跨链转移NFT流程",
    async () => {
        // 测试用户mint一个nft
        it("测试用户mint一个nft", async () => {
            const tx = await myToken.safeMint(deployer);
            const receipt = await tx.wait();
            if (!receipt) {
                throw new Error("交易失败，未能获取到 receipt");
            }
            const filter = myToken.filters.Transfer(undefined, deployer);
            const events = await myToken.queryFilter(filter, receipt.blockNumber, receipt.blockNumber);
            const tokenId = events[0]?.args?.tokenId;
            const tokenOwner = await myToken.ownerOf(tokenId);
            expect(tokenOwner).to.equal(deployer);
        })

        it("测试用户锁定一个nft并发送跨链消息", async () => {
            // token的持有者owner需要先授权nftPoolLockAndRelease合约可以将token从owner转移到nftPoolLockAndRelease合约中
            await myToken.approve(nftPoolLockAndRelease.target, 0);
            // 从水龙头那里获取link
            await ccipLocalSimulator.requestLinkFromFaucet(nftPoolLockAndRelease, ethers.parseEther("10"));
            // 加上白名单，只有白名单里的地址才能mint一个nft
            await wrapperMyToken.addToWhitelist(nftPoolBurnAndMint.target);
            await nftPoolLockAndRelease.lockAndSendNFT(0, deployer, chainSelector, nftPoolBurnAndMint.target);
            const owner = await myToken.ownerOf(0);
            console.log("test");
            // 判断tokenId为0的拥有者address是否为nftPoolLockAndRelease合约地址，是的话，就说明nft已经转移到了pool里面了
            expect(owner).to.equal(nftPoolLockAndRelease.target);
        })

        it('测试用户在目标链上接收并mint一个wnft', async () => {
            const owner = await wrapperMyToken.ownerOf(0);
            // 判断wnft的tokenId为0的拥有者address是否为跨链传递的owner
            expect(owner).to.equal(deployer);
        })
    }
)

describe("测试用户从目标链到源链的跨链NFT流程", async () => {
    it('测试用户burn一个wnft并发送跨链消息到源链', async () => {
        // 给nftPoolBurnAndMint合约授权可以操作token id为0的nft
        await wrapperMyToken.approve(nftPoolBurnAndMint.target, 0);
        await nftPoolBurnAndMint.burnAndSendNFT(0, deployer, chainSelector, nftPoolLockAndRelease.target);
        const amount = await wrapperMyToken.totalSupply();
        expect(amount).to.equal(0);
    })

    it("测试用户在源链上接收并解锁一个nft", async () => {
        const owner = await myToken.ownerOf(0);
        // 判断wnft的tokenId为0的拥有者address是否为跨链传递的owner
        expect(owner).to.equal(deployer);
    })
})
