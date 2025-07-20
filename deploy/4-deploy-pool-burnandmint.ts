import "@nomicfoundation/hardhat-toolbox";
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const deployNFTPoolBurnAndMint: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const isLiveNetwork =
        network.name !== "hardhat" && network.name !== "localhost";
    log("Deploying NFTPoolBurnAndMint and waiting for confirmations...");
    const cCIPLocalSimulatorDeployment = await deployments.get("CCIPLocalSimulator");
    const cCIPLocalSimulator = await hre.ethers.getContractAt("CCIPLocalSimulator", cCIPLocalSimulatorDeployment.address);
    const ccipConfig = await cCIPLocalSimulator.configuration();
    const destinationRouter = ccipConfig.destinationRouter_;// 获取目的链路由地址
    const linkTokenAddr = ccipConfig.linkToken_;// 获取 LINK 代币地址
    const wnftAddress = await deployments.get("WrapperMyToken").then(deployment => deployment.address); // 获取 MyToken 合约地址
    const nftAddress = await deployments.get("NFTPoolLockAndRelease").then(deployment => deployment.address); // 获取 MyToken 合约地址
    const chainSelector = ccipConfig.chainSelector_;// 获取链选择器
    const args = [destinationRouter, linkTokenAddr, wnftAddress, nftAddress, chainSelector]; // 传入合约的构造函数参数
    const NFTPoolBurnAndMint = await deploy("NFTPoolBurnAndMint", {
        contract: "NFTPoolBurnAndMint",
        from: deployer,
        log: true,
        args: args,
        waitConfirmations: isLiveNetwork ? 5 : 1, // 如果是主网或测试网,等待5个区块确认,否则等待1个区块确认
    });
    log("NFTPoolBurnAndMint deployed successfully!");
    // 部署后手动调用验证插件
    if (isLiveNetwork) {
        console.log(`Verifying contract on ${network.name}...`);
        await hre.run("verify:verify", {
            address: NFTPoolBurnAndMint.address,
            constructorArguments: args,
        });
        console.log(`Contract verified on ${network.name}`);
    }
};
deployNFTPoolBurnAndMint.tags = ["sourceChain", "NFTPoolBurnAndMint", "all"];
export default deployNFTPoolBurnAndMint;
