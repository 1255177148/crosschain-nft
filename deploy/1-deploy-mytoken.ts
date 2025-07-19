import "@nomicfoundation/hardhat-toolbox";
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const deployMyToken: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const isLiveNetwork =
    network.name !== "hardhat" && network.name !== "localhost";
  log("Deploying MyToken and waiting for confirmations...");
  deploy("MyToken", {
    contract: "MyToken",
    from: deployer,
    log: true,
    args: ["MyToken", "MTK", deployer], // 传入合约的构造函数参数
    waitConfirmations: isLiveNetwork ? 5 : 1, // 如果是主网或测试网,等待5个区块确认,否则等待1个区块确认
  });
  log("MyToken deployed successfully!");
};
deployMyToken.tags = ["sourceChain", "MyToken", "all"];
export default deployMyToken;

