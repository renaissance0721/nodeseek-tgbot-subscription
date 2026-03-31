#!/bin/bash

# 定义颜色输出，提升脚本的视觉体验
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${GREEN}=== Flowerss-bot 一键部署脚本 ===${RESET}"

# 第一步：检查并安装 Docker 环境
if ! command -v docker &> /dev/null; then
    echo -e "${RED}未检测到 Docker，正在自动安装...${RESET}"
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl start docker
    systemctl enable docker
else
    echo -e "${GREEN}[+] Docker 已安装，跳过此步骤。${RESET}"
fi

# 第二步：交互式获取 Bot Token
read -p "请输入你的 Telegram Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}错误：Token 不能为空！部署中止。${RESET}"
    exit 1
fi

# 第三步：初始化目录结构
BASE_DIR="/opt/flowerss"
echo -e "${GREEN}[+] 正在清理旧配置并创建工作目录: ${BASE_DIR}${RESET}"
mkdir -p ${BASE_DIR}/data
rm -f ${BASE_DIR}/config.yml ${BASE_DIR}/docker-compose.yml

# 第四步：自动生成配置文件 (利用 EOF 避免手动输入的缩进错误)
echo -e "${GREEN}[+] 正在生成 config.yml...${RESET}"
cat <<EOF > ${BASE_DIR}/config.yml
bot_token: "${BOT_TOKEN}"
update_interval: 1
sqlite_path: "/root/.flowerss/data/flowerss.db"
EOF

# 第五步：自动生成 Docker Compose 文件
echo -e "${GREEN}[+] 正在生成 docker-compose.yml...${RESET}"
cat <<EOF > ${BASE_DIR}/docker-compose.yml
services:
  flowerss:
    image: indes/flowerss-bot:latest
    container_name: flowerss-bot
    restart: always
    volumes:
      - ${BASE_DIR}/config.yml:/root/.flowerss/config.yml
      - ${BASE_DIR}/data:/root/.flowerss/data
    environment:
      - TZ=Asia/Shanghai
EOF

# 第六步：执行容器构建与启动
echo -e "${GREEN}[+] 正在启动 Docker 容器...${RESET}"
cd ${BASE_DIR}

# 兼容新老版本的 docker-compose 命令
if docker compose version &> /dev/null; then
    docker compose down &> /dev/null
    docker compose up -d
else
    docker-compose down &> /dev/null
    docker-compose up -d
fi

echo -e "${GREEN}=== 部署完成！ ===${RESET}"
echo "请前往 Telegram 给你的机器人发送 /start"
echo "订阅指令: /sub https://www.nodeseek.com/rss.xml"
echo "查看运行日志: cd ${BASE_DIR} && docker compose logs -f"
