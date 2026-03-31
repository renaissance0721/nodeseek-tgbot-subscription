#!/bin/bash

# ==========================================
# Flowerss-bot TG RSS 订阅机器人一键管理脚本
# ==========================================

# 定义颜色输出，提升脚本的视觉体验
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

# 定义安装目录全局变量
BASE_DIR="/opt/flowerss"

# ------------------------------------------
# 功能模块 1：安装与配置机器人
# ------------------------------------------
install_bot() {
    echo -e "\n${YELLOW}▶ 开始执行安装/重装流程...${RESET}"
    
    # 检查并安装 Docker 环境
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}未检测到 Docker，正在自动安装...${RESET}"
        curl -fsSL https://get.docker.com | bash -s docker
        systemctl start docker
        systemctl enable docker
    else
        echo -e "${GREEN}[+] Docker 已安装，跳过此步骤。${RESET}"
    fi

    # 交互式获取 Bot Token
    read -p "请输入你的 Telegram Bot Token: " BOT_TOKEN

    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RED}错误：Token 不能为空！已返回主菜单。${RESET}"
        return
    fi

    # 初始化目录结构
    echo -e "${GREEN}[+] 正在清理旧配置并创建工作目录: ${BASE_DIR}${RESET}"
    mkdir -p ${BASE_DIR}/data
    rm -f ${BASE_DIR}/config.yml ${BASE_DIR}/docker-compose.yml

    # 自动生成配置文件
    echo -e "${GREEN}[+] 正在生成 config.yml...${RESET}"
    cat <<EOF > ${BASE_DIR}/config.yml
bot_token: "${BOT_TOKEN}"
update_interval: 1
sqlite_path: "/root/.flowerss/data/flowerss.db"
EOF

    # 自动生成 Docker Compose 文件
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

    # 执行容器构建与启动
    echo -e "${GREEN}[+] 正在启动 Docker 容器...${RESET}"
    cd ${BASE_DIR}

    if docker compose version &> /dev/null; then
        docker compose down &> /dev/null
        docker compose up -d
    else
        docker-compose down &> /dev/null
        docker-compose up -d
    fi

    echo -e "\n${GREEN}=== 部署完成！ ===${RESET}"
}

# ------------------------------------------
# 功能模块 2：查看运行日志
# ------------------------------------------
view_logs() {
    if [ -d "$BASE_DIR" ]; then
        echo -e "\n${YELLOW}▶ 正在实时显示机器人日志 (按 Ctrl+C 退出查看)...${RESET}"
        docker logs -f flowerss-bot
    else
        echo -e "\n${RED}未找到安装目录，请先执行安装步骤！${RESET}"
    fi
}

# ------------------------------------------
# 功能模块 3：查看已订阅列表 (新增)
# ------------------------------------------
view_subscriptions() {
    DB_FILE="${BASE_DIR}/data/flowerss.db"
    if [ -f "$DB_FILE" ]; then
        echo -e "\n${CYAN}=== 当前机器人已订阅列表 ===${RESET}"
        
        # 检查并安装 sqlite3 工具（如果不存在）
        if ! command -v sqlite3 &> /dev/null; then
            echo -e "${YELLOW}[!] 检测到未安装 sqlite3，正在自动安装以读取数据库...${RESET}"
            apt update && apt install sqlite3 -y &> /dev/null || yum install sqlite -y &> /dev/null
        fi
        
        # 从数据库中提取标题和链接
        # flowerss-bot 的数据库表名为 sources，字段为 title 和 link
        LIST=$(sqlite3 "$DB_FILE" "SELECT title, link FROM sources;" 2>/dev/null)
        
        if [ -z "$LIST" ]; then
            echo -e "${RED}目前还没有任何订阅数据。${RESET}"
            echo -e "提示：请先在 Telegram 中使用 /sub 命令添加订阅。"
        else
            # 格式化输出列表
            echo "$LIST" | awk -F'|' '{printf "\033[32m● %s\033[0m\n   🔗 %s\n", $1, $2}'
        fi
        echo -e "${CYAN}========================================${RESET}"
    else
        echo -e "\n${RED}未找到数据库文件，请确认机器人已成功启动并至少添加过一个订阅。${RESET}"
    fi
}

# ------------------------------------------
# 功能模块 4：彻底卸载
# ------------------------------------------
uninstall_bot() {
    echo -e "\n${RED}⚠️ 警告：这将删除机器人的所有配置和订阅数据！${RESET}"
    read -p "确定要彻底卸载吗？(y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        echo -e "${YELLOW}正在卸载并清理环境...${RESET}"
        if [ -d "$BASE_DIR" ]; then
            cd ${BASE_DIR}
            if docker compose version &> /dev/null; then
                docker compose down
            else
                docker-compose down
            fi
            rm -rf ${BASE_DIR}
            echo -e "${GREEN}卸载完成！${RESET}"
        fi
    else
        echo -e "${GREEN}已取消。${RESET}"
    fi
}

# ------------------------------------------
# 功能模块 5：展示推荐 RSS 节点
# ------------------------------------------
show_rss_links() {
    echo -e "\n${CYAN}=== 推荐 NodeSeek RSS 订阅源 ===${RESET}"
    echo -e "🔗 全站监控: https://www.nodeseek.com/rss.xml"
    echo -e "🔗 二手交易: https://www.nodeseek.com/categories/trade/rss.xml"
    echo -e "🔗 优惠情报: https://www.nodeseek.com/categories/offers/rss.xml"
    echo -e "-----------------------------------------"
}

# ------------------------------------------
# 主控逻辑：交互式菜单循环
# ------------------------------------------
while true; do
    echo -e "\n${GREEN}========================================${RESET}"
    echo -e "${GREEN}       Flowerss-bot 一键管理工具箱      ${RESET}"
    echo -e "${GREEN}========================================${RESET}"
    echo -e "  1. 安装 / 重装 RSS 机器人"
    echo -e "  2. 查看机器人实时运行日志"
    echo -e "  3. 查看当前已订阅列表 (新)"
    echo -e "  4. 重启机器人容器"
    echo -e "  5. 停止机器人容器"
    echo -e "  6. 获取 NodeSeek 常用 RSS 源"
    echo -e "  7. 彻底卸载机器人及数据"
    echo -e "  0. 退出脚本"
    echo -e "${GREEN}========================================${RESET}"
    read -p "请输入选项序号 [0-7]: " CHOICE

    case $CHOICE in
        1) install_bot ;;
        2) view_logs ;;
        3) view_subscriptions ;;
        4)
            docker restart flowerss-bot &> /dev/null && echo -e "\n${GREEN}▶ 重启成功！${RESET}" || echo -e "\n${RED}失败：机器人未运行。${RESET}"
            ;;
        5)
            docker stop flowerss-bot &> /dev/null && echo -e "\n${YELLOW}▶ 机器人已停止！${RESET}" || echo -e "\n${RED}失败：机器人未运行。${RESET}"
            ;;
        6) show_rss_links ;;
        7) uninstall_bot ;;
        0) echo -e "\n${GREEN}再见！${RESET}"; exit 0 ;;
        *) echo -e "\n${RED}输入错误，请重新选择。${RESET}" ;;
    esac
done
