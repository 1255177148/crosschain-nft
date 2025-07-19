import * as fs from 'fs';
import * as path from 'path';

// ==== 可自定义配置 ====
const baseCID: string = "QmbZMmxeVREr3HyPHd2veHrJcGJwgmqhDLc2xvsL5QSKPP"; // 替换成你的图片 CID
const outputDir: string = "./metadata"; // metadata 输出目录
const baseName: string = "Elvis NFT";
const baseDescription: string = "A sample NFT stored on IPFS via Filebase";
const tokenId: number = 0; // token ID，可迭代或从命令行传参也行
const attributes: { trait_type: string; value: string }[] = [
  { trait_type: "Artist", value: "Elvis Presley" },
  { trait_type: "Genre", value: "Rock" },
  { trait_type: "Year", value: "1956" }
];

// ==== 元数据结构 ====
interface NFTMetadata {
  name: string;
  description: string;
  image: string;
  attributes?: { trait_type: string; value: string }[]; // 可选属性
  external_url?: string; // 可选外部链接
}

// ==== 创建输出目录（如果不存在） ====
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir);
}

// ==== 构建 metadata 对象 ====
const metadata: NFTMetadata = {
  name: `${baseName} #${tokenId}`,
  description: baseDescription,
  image: `ipfs://${baseCID}`,
  attributes: attributes,
};

// ==== 写入 metadata JSON 文件 ====
const metadataPath: string = path.join(outputDir, `${tokenId}.json`);
fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2), 'utf-8');

console.log(`✅ Metadata written to ${metadataPath}`);
