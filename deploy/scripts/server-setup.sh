#!/bin/bash
echo "========================================"
echo "  im-bot-gateway 服务器初始化脚本"
echo "========================================"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统
check_system() {
    log "检查系统环境..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log "操作系统: $PRETTY_NAME"
        log "内核版本: $(uname -r)"
    else
        warn "无法识别操作系统"
    fi
    
    # 检查是否是Alibaba Cloud Linux
    if [[ "$ID" == "alinux" ]] || [[ "$ID" == "anolis" ]]; then
        log "检测到阿里云Linux系统"
    fi
    
    log "系统检查完成"
}

# 安装Node.js
install_node() {
    log "开始安装Node.js..."
    
    if command -v node &> /dev/null; then
        log "Node.js已安装: $(node --version)"
        read -p "是否重新安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # 安装NVM
    if [ ! -d "$HOME/.nvm" ]; then
        log "安装NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    fi
    
    # 加载NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # 安装Node.js 18 LTS
    log "安装Node.js 18 LTS..."
    nvm install 18
    nvm use 18
    
    # 验证安装
    log "Node.js版本: $(node --version)"
    log "npm版本: $(npm --version)"
    
    log "Node.js安装完成"
}

# 安装PM2
install_pm2() {
    log "安装PM2..."
    
    if command -v pm2 &> /dev/null; then
        log "PM2已安装: $(pm2 --version)"
    else
        npm install -g pm2
        log "PM2安装完成: $(pm2 --version)"
    fi
    
    # 配置开机自启
    log "配置PM2开机自启..."
    pm2 startup | tail -1
}

# 创建用户
create_user() {
    log "检查部署用户..."
    
    if id "deploy" &>/dev/null; then
        log "用户deploy已存在"
    else
        log "创建deploy用户..."
        useradd -m -s /bin/bash deploy
        log "用户deploy创建完成"
    fi
    
    # 配置sudo权限
    if ! grep -q "^deploy ALL=" /etc/sudoers 2>/dev/null; then
        echo "deploy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        log "已配置deploy用户sudo权限"
    fi
}

# 配置SSH
configure_ssh() {
    log "配置SSH安全选项..."
    
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # 禁用root登录
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # 重启SSH服务
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd
    fi
    
    log "SSH配置完成"
}

# 安装Docker
install_docker() {
    log "检查Docker..."
    
    if command -v docker &> /dev/null; then
        log "Docker已安装: $(docker --version)"
    else
        log "安装Docker..."
        
        # Alibaba Cloud Linux安装Docker
        if [[ "$ID" == "alinux" ]] || [[ "$ID" == "anolis" ]]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
        else
            curl -fsSL https://get.docker.com | bash
            systemctl start docker
            systemctl enable docker
        fi
        
        log "Docker安装完成: $(docker --version)"
    fi
    
    # 添加用户到docker组
    usermod -aG docker deploy 2>/dev/null || true
}

# 安装Nginx
install_nginx() {
    log "检查Nginx..."
    
    if command -v nginx &> /dev/null; then
        log "Nginx已安装: $(nginx -v 2>&1)"
    else
        log "安装Nginx..."
        
        if command -v yum &> /dev/null; then
            yum install -y nginx
        elif command -v dnf &> /dev/null; then
            dnf install -y nginx
        fi
        
        systemctl start nginx
        systemctl enable nginx
        
        log "Nginx安装完成"
    fi
}

# 配置防火墙
configure_firewall() {
    log "检查防火墙..."
    
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            log "配置firewalld..."
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=8767/tcp
            firewall-cmd --reload
            log "firewalld配置完成"
        else
            log "firewalld未运行"
        fi
    elif command -v ufw &> /dev/null; then
        log "配置UFW..."
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 8767/tcp
        ufw --force enable
        log "UFW配置完成"
    else
        warn "未检测到防火墙，请手动配置"
    fi
}

# 创建项目目录
create_project_dir() {
    log "创建项目目录..."
    
    mkdir -p /opt/im-bot-gateway
    mkdir -p /opt/im-bot-gateway/{server,backups,logs}
    mkdir -p /var/log/im-bot-gateway
    
    # 设置权限
    chmod 755 /opt/im-bot-gateway
    chmod 755 /var/log/im-bot-gateway
    
    log "项目目录创建完成"
}

# 配置日志轮转
configure_logrotate() {
    log "配置日志轮转..."
    
    cat > /etc/logrotate.d/im-bot-gateway << EOF
/var/log/im-bot-gateway/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
    
    log "日志轮转配置完成"
}

# 生成SSL证书（自签名，用于测试）
generate_ssl_cert() {
    log "生成自签名SSL证书（测试用途）..."
    
    mkdir -p /etc/nginx/ssl
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/im-bot-gateway.key \
        -out /etc/nginx/ssl/im-bot-gateway.crt \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=im-bot-gateway/CN=localhost"
    
    chmod 600 /etc/nginx/ssl/im-bot-gateway.key
    chmod 644 /etc/nginx/ssl/im-bot-gateway.crt
    
    log "SSL证书生成完成"
}

# 创建系统服务
create_systemd_service() {
    log "创建systemd服务..."
    
    cat > /etc/systemd/system/im-bot-gateway.service << EOF
[Unit]
Description=IM Bot Gateway WebSocket Server
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/im-bot-gateway/server
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=8767

# 日志
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=im-bot-gateway

# 安全加固
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/im-bot-gateway

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log "systemd服务创建完成"
}

# 显示总结
show_summary() {
    echo ""
    echo "========================================"
    echo "  服务器初始化完成!"
    echo "========================================"
    echo ""
    echo "已安装组件:"
    echo "  ✓ Node.js 18 LTS"
    echo "  ✓ PM2 进程管理器"
    echo "  ✓ Nginx 反向代理"
    echo "  ✓ Docker (可选)"
    echo ""
    echo "安全配置:"
    echo "  ✓ SSH root登录已禁用"
    echo "  ✓ 防火墙已配置"
    echo "  ✓ 日志轮转已配置"
    echo ""
    echo "目录结构:"
    echo "  /opt/im-bot-gateway/  - 项目目录"
    echo "  /var/log/im-bot-gateway/ - 日志目录"
    echo ""
    echo "后续步骤:"
    echo "  1. 上传部署文件"
    echo "  2. 运行 deploy.sh 部署应用"
    echo "  3. 配置SSL证书（生产环境）"
    echo ""
}

# 主函数
main() {
    echo ""
    log "开始服务器初始化..."
    echo ""
    
    check_system
    install_node
    install_pm2
    create_user
    configure_ssh
    install_nginx
    configure_firewall
    create_project_dir
    configure_logrotate
    generate_ssl_cert
    create_systemd_service
    
    show_summary
    
    log "初始化完成!"
}

main "$@"
