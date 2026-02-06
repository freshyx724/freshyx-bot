#!/bin/bash
# Freshyx Bot - 服务器初始化脚本
# 用法: curl -sL https://raw.githubusercontent.com/freshyx724/freshyx-bot/main/deploy/scripts/server-setup.sh | bash

set -e

echo "========================================"
echo "  Freshyx Bot 服务器初始化"
echo "========================================"

# 安装Node.js 18
echo "[1/4] 安装Node.js 18..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 18
    nvm use 18
fi
echo "Node.js版本: $(node --version)"

# 安装PM2
echo "[2/4] 安装PM2..."
npm install -g pm2
pm2 startup | tail -1

# 安装Nginx
echo "[3/4] 安装Nginx..."
if ! command -v nginx &> /dev/null; then
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx
fi

# 配置防火墙
echo "[4/4] 配置防火墙..."
firewall-cmd --permanent --add-port=8767/tcp
firewall-cmd --reload

# 创建目录
mkdir -p /opt/freshyx-bot
mkdir -p /var/log/freshyx-bot

echo ""
echo "========================================"
echo "  初始化完成!"
echo "========================================"
echo ""
echo "下一步: 部署应用"
echo "  git clone https://github.com/freshyx724/freshyx-bot.git"
echo "  cd freshyx-bot/server"
echo "  npm install --production"
echo "  pm2 start ecosystem.config.js"
echo ""
