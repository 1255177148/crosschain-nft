import "@nomicfoundation/hardhat-toolbox";
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const deployCCIPLocalSimulator: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const isLiveNetwork =
        network.name !== "hardhat" && network.name !== "localhost";
    if (isLiveNetwork) {
        console.warn(
            "CCIPLocalSimulator should not be deployed on live networks. Skipping deployment."
        );
        return; // 如果是主网或测试网,则不部署 CCIPLocalSimulator
    }
    log("Deploying CCIPLocalSimulator and waiting for confirmations...");
    const CCIPLocalSimulator = await deploy("CCIPLocalSimulator", {
        contract: "CCIPLocalSimulator",
        from: deployer,
        log: true,
        args: [], // 传入合约的构造函数参数
        waitConfirmations: isLiveNetwork ? 5 : 1, // 如果是主网或测试网,等待5个区块确认,否则等待1个区块确认
    });
    log("CCIPLocalSimulator deployed successfully!");
    // 部署后手动调用验证插件
    if (isLiveNetwork) {
        console.log(`Verifying contract on ${network.name}...`);
        await hre.run("verify:verify", {
            address: CCIPLocalSimulator.address,
            constructorArguments: [], // 构造函数参数
        });
        console.log(`Contract verified on ${network.name}`);
    }
};
deployCCIPLocalSimulator.tags = ["test", "CCIPLocalSimulator", "all"];
export default deployCCIPLocalSimulator;

