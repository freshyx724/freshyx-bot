#!/bin/bash
set -e

echo "========================================"
echo "  im-bot-gateway 服务器部署脚本"
echo "  操作系统: Alibaba Cloud Linux"
echo "========================================"
echo ""

# 配置变量
PROJECT_DIR="/opt/im-bot-gateway"
BACKUP_DIR="/opt/im-bot-gateway/backups"
DEPLOY_TIME=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/im-bot-deploy-$DEPLOY_TIME.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "请使用root权限运行"
        exit 1
    fi
}

# 安装Node.js
install_node() {
    log "检查Node.js环境..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log "Node.js已安装: $NODE_VERSION"
        
        # 检查版本是否满足要求
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_MAJOR" -lt 18 ]; then
            warn "Node.js版本过低，将进行升级"
            install_node_nvm
        fi
    else
        log "安装Node.js..."
        install_node_nvm
    fi
}

# 使用nvm安装Node.js
install_node_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    fi
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install 18
    nvm use 18
    
    # 添加到.bashrc
    if ! grep -q "NVM_DIR" ~/.bashrc; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
    fi
    
    log "Node.js安装完成: $(node --version)"
}

# 安装PM2
install_pm2() {
    log "检查PM2..."
    
    if ! command -v pm2 &> /dev/null; then
        log "安装PM2..."
        npm install -g pm2
        
        # 设置开机自启
        pm2 startup | tail -1
    fi
    
    log "PM2版本: $(pm2 --version)"
}

# 安装其他依赖
install_dependencies() {
    log "安装系统依赖..."
    
    # Alibaba Cloud Linux使用yum/dnf
    if command -v yum &> /dev/null; then
        yum install -y curl wget git nginx
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget git nginx
    fi
    
    log "系统依赖安装完成"
}

# 备份现有部署
backup_existing() {
    if [ -d "$PROJECT_DIR" ]; then
        log "备份现有部署..."
        
        mkdir -p "$BACKUP_DIR"
        
        # 备份配置和日志
        if [ -d "$PROJECT_DIR/server" ]; then
            tar -czf "$BACKUP_DIR/server-$DEPLOY_TIME.tar.gz" -C "$PROJECT_DIR" server 2>/dev/null || true
        fi
        
        log "备份已保存到: $BACKUP_DIR/server-$DEPLOY_TIME.tar.gz"
    fi
}

# 部署服务端
deploy_server() {
    log "部署服务端..."
    
    mkdir -p "$PROJECT_DIR"
    
    # 解压服务端代码
    if [ -f "/tmp/im-bot-deploy/server-deploy-$DEPLOY_TIME.tar.gz" ]; then
        tar -xzf "/tmp/im-bot-deploy/server-deploy-$DEPLOY_TIME.tar.gz" -C "$PROJECT_DIR"/
    elif [ -f "/tmp/im-bot-deploy/server.tar.gz" ]; then
        tar -xzf "/tmp/im-bot-deploy/server.tar.gz" -C "$PROJECT_DIR"/
    fi
    
    # 清理旧目录
    rm -rf "$PROJECT_DIR/server/node_modules"
    
    # 安装依赖
    cd "$PROJECT_DIR/server"
    npm install --production
    
    log "服务端依赖安装完成"
}

# 配置PM2
configure_pm2() {
    log "配置PM2进程管理..."
    
    # 停止现有实例
    pm2 stop im-bot-gateway 2>/dev/null || true
    pm2 delete im-bot-gateway 2>/dev/null || true
    
    # 复制PM2配置
    if [ -f "/tmp/im-bot-deploy/ecosystem.config.js" ]; then
        cp /tmp/im-bot-deploy/ecosystem.config.js "$PROJECT_DIR/"
    fi
    
    # 创建环境变量文件
    cat > "$PROJECT_DIR/server/.env" << EOF
NODE_ENV=production
PORT=8767
LOG_LEVEL=info
EOF
    
    # 启动服务
    cd "$PROJECT_DIR/server"
    pm2 start ecosystem.config.js
    
    # 保存PM2配置
    pm2 save
    
    log "PM2配置完成"
}

# 配置防火墙
configure_firewall() {
    log "配置防火墙..."
    
    # Alibaba Cloud Linux可能使用firewalld或直接配置
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8767/tcp
        firewall-cmd --reload
        log "firewalld配置完成"
    elif [ -f "/etc/iptables/rules.v4" ]; then
        iptables -A INPUT -p tcp --dport 8767 -j ACCEPT
        log "iptables配置完成"
    else
        warn "未检测到防火墙配置，请手动配置"
    fi
}

# 配置Nginx
configure_nginx() {
    log "配置Nginx反向代理..."
    
    if ! command -v nginx &> /dev/null; then
        warn "Nginx未安装，跳过配置"
        return
    fi
    
    # 创建配置文件
    cat > /etc/nginx/conf.d/im-bot-gateway.conf << EOF
upstream im_bot_gateway {
    server 127.0.0.1:8767;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://im_bot_gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # 测试配置
    nginx -t
    
    # 重启Nginx
    systemctl reload nginx
    
    log "Nginx配置完成"
}

# 验证部署
verify_deployment() {
    log "验证部署..."
    
    sleep 2
    
    # 检查PM2状态
    PM2_STATUS=$(pm2 status im-bot-gateway | grep -c "online" || echo "0")
    if [ "$PM2_STATUS" -eq 0 ]; then
        error "服务启动失败"
        pm2 logs im-bot-gateway --lines 50
        exit 1
    fi
    log "PM2服务状态正常"
    
    # 检查端口监听
    if command -v ss &> /dev/null; then
        if ss -tlnp | grep -q ":8767 "; then
            log "端口8767已监听"
        else
            warn "端口8767未监听"
        fi
    fi
    
    # 测试本地连接
    if command -v curl &> /dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health 2>/dev/null || echo "000")
        if [ "$HTTP_STATUS" != "000" ]; then
            log "HTTP服务正常 (状态码: $HTTP_STATUS)"
        fi
    fi
}

# 显示部署信息
show_summary() {
    echo ""
    echo "========================================"
    echo "  部署完成!"
    echo "========================================"
    echo ""
    echo "服务状态:"
    pm2 status
    echo ""
    echo "查看日志:"
    echo "  pm2 logs im-bot-gateway"
    echo ""
    echo "重启服务:"
    echo "  pm2 restart im-bot-gateway"
    echo ""
    echo "停止服务:"
    echo "  pm2 stop im-bot-gateway"
    echo ""
    echo "日志文件: $LOG_FILE"
    echo ""
}

# 主函数
main() {
    log "开始部署流程..."
    
    check_root
    install_dependencies
    install_node
    install_pm2
    backup_existing
    deploy_server
    configure_pm2
    configure_firewall
    configure_nginx
    verify_deployment
    show_summary
    
    log "部署成功完成!"
}

# 执行主函数
main "$@"
