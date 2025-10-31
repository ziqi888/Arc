#!/bin/bash

# Arc Testnet 自动化部署和交互脚本
# 作者：基于 Arc 官方教程生成
# 用法：./deploy-arc.sh（在 hello-arc 目录运行）

set -e  # 遇到错误立即退出

echo "=== 开始 Arc Testnet 自动化部署和交互 ==="

# 步骤2: 确保 .env 存在并添加 RPC URL（如果缺少）
if [ ! -f .env ]; then
    touch .env
fi
if ! grep -q "ARC_TESTNET_RPC_URL" .env; then
    echo 'ARC_TESTNET_RPC_URL="https://rpc.testnet.arc.network"' >> .env
fi
source .env  # 加载环境变量

# 步骤3: 生成新钱包
echo "生成新钱包..."
PRIVATE_KEY=$(openssl rand -hex 32 | sed 's/^/0x/')
ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "新钱包地址: $ADDRESS"
echo "私钥: $PRIVATE_KEY"  # 注意：仅显示一次，生产环境勿打印
echo "请访问 https://faucet.circle.com，选择 Arc Testnet，输入地址 $ADDRESS 请求测试 USDC（gas 费）..."
read -p "资助完成后按 Enter 继续..."

# 步骤4: 更新 .env 中的 PRIVATE_KEY
sed -i.bak "s/^PRIVATE_KEY=.*/PRIVATE_KEY=\"$PRIVATE_KEY\"/" .env 2>/dev/null || echo "PRIVATE_KEY=\"$PRIVATE_KEY\"" >> .env
rm -f .env.bak  # 清理备份
source .env

# 步骤5: 编译合约
echo "编译合约..."
forge build

# 步骤6: 部署合约
echo "部署 HelloArchitect 合约..."
DEPLOY_OUTPUT=$(forge create src/HelloArchitect.sol:HelloArchitect \
  --rpc-url "$ARC_TESTNET_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast 2>&1)

echo "$DEPLOY_OUTPUT"

# 解析部署地址
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | sed 's/.*Deployed to: //')
if [ -z "$CONTRACT_ADDRESS" ]; then
    echo "部署失败！请检查 gas 费或网络。"
    exit 1
fi
echo "合约部署地址: $CONTRACT_ADDRESS"

# 更新 .env 中的 HELLOARCHITECT_ADDRESS
sed -i.bak "s/^HELLOARCHITECT_ADDRESS=.*/HELLOARCHITECT_ADDRESS=\"$CONTRACT_ADDRESS\"/" .env 2>/dev/null || echo "HELLOARCHITECT_ADDRESS=\"$CONTRACT_ADDRESS\"" >> .env
rm -f .env.bak
source .env

# 步骤7: 交互 - 设置新问候语（例如包含时间戳）
TIMESTAMP=$(date +%s)
NEW_GREETING="Hello Arc from new deploy at $(date -d "@$TIMESTAMP")!"
echo "设置新问候语: $NEW_GREETING"
cast send "$HELLOARCHITECT_ADDRESS" "setGreeting(string)" "$NEW_GREETING" \
  --rpc-url "$ARC_TESTNET_RPC_URL" \
  --private-key "$PRIVATE_KEY"

# 步骤8: 交互 - 获取问候语验证
echo "获取当前问候语..."
GREETING=$(cast call "$HELLOARCHITECT_ADDRESS" "getGreeting()(string)" \
  --rpc-url "$ARC_TESTNET_RPC_URL")
echo "当前问候语: $GREETING"

echo "=== 部署和交互完成！==="
echo "交易可在 https://testnet.arcscan.app 查看（使用部署输出中的 tx hash）。"
echo "下次运行将生成新钱包并重复过程。"
