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
	const MyToken = await deploy("MyToken", {
		contract: "MyToken",
		from: deployer,
		log: true,
		args: [deployer], // 传入合约的构造函数参数
		waitConfirmations: isLiveNetwork ? 5 : 1, // 如果是主网或测试网,等待5个区块确认,否则等待1个区块确认
	});
	log("MyToken deployed successfully!");
	// 部署后手动调用验证插件
	if (isLiveNetwork) {
		console.log(`Verifying contract on ${network.name}...`);
		await hre.run("verify:verify", {
			address: MyToken.address,
			constructorArguments: [deployer], // 构造函数参数
		});
		console.log(`Contract verified on ${network.name}`);
	}
};
deployMyToken.tags = ["sourceChain", "MyToken", "all"];
export default deployMyToken;

