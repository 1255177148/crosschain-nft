import "@nomicfoundation/hardhat-toolbox";
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import networkConfig from "../helper.config";

const deployPoolLockAndRelease: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const isLiveNetwork =
        network.name !== "hardhat" && network.name !== "localhost";
    log("Deploying NFTPoolLockAndRelease and waiting for confirmations...");
    console.log("当前网络:", network.name);
    console.log("当前部署记录文件夹:", deployments.getNetworkName && deployments.getNetworkName());

    const allDeployments = await deployments.all();
    console.log("当前已部署合约:", Object.keys(allDeployments));
    let sourceChainRouter: any;
    let linkTokenAddr;
    if (isLiveNetwork){
        sourceChainRouter = networkConfig[network.name].router;
        linkTokenAddr = networkConfig[network.name].linkToken;
    } else {
        const cCIPLocalSimulatorDeployment = await deployments.get("CCIPLocalSimulator");
        const cCIPLocalSimulator = await hre.ethers.getContractAt("CCIPLocalSimulator", cCIPLocalSimulatorDeployment.address);
        const ccipConfig = await cCIPLocalSimulator.configuration();
        sourceChainRouter = ccipConfig.sourceRouter_;// 获取源链路由地址
        linkTokenAddr = ccipConfig.linkToken_;// 获取 LINK 代币地址
    }
    const nftAddress = await deployments.get("MyToken").then(deployment => deployment.address); // 获取 MyToken 合约地址
    const args = [sourceChainRouter, linkTokenAddr, nftAddress]; // 传入合约的构造函数参数
    const NFTPoolLockAndRelease = await deploy("NFTPoolLockAndRelease", {
        contract: "NFTPoolLockAndRelease",
        from: deployer,
        log: true,
        args: args,
        waitConfirmations: isLiveNetwork ? 5 : 1, // 如果是主网或测试网,等待5个区块确认,否则等待1个区块确认
    });
    log("NFTPoolLockAndRelease deployed successfully!");
    // 部署后手动调用验证插件
    if (isLiveNetwork) {
        console.log(`Verifying contract on ${network.name}...`);
        await hre.run("verify:verify", {
            address: NFTPoolLockAndRelease.address,
            constructorArguments: args,
        });
        console.log(`Contract verified on ${network.name}`);
    }
};
deployPoolLockAndRelease.tags = ["sourceChain", "NFTPoolLockAndRelease", "all"];
export default deployPoolLockAndRelease;
