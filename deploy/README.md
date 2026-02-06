# freshyx-bot 部署指南

## 仓库地址

GitHub: https://github.com/freshyx724/freshyx-bot

## 目录结构

```
deploy/
├── scripts/
│   ├── deploy.bat          # Windows批处理部署脚本
│   ├── deploy.ps1          # PowerShell部署脚本
│   ├── server-setup.sh    # 服务器初始化脚本
│   ├── server-deploy.sh   # 服务器部署脚本
│   └── health-check.sh    # 健康检查脚本
└── config/
    └── ecosystem.config.js # PM2进程配置
```

## 快速部署

### 前提条件

**本地环境 (Windows 11):**
- Flutter SDK >= 3.0
- Android SDK
- Git (含SSH)
- ADB (用于安装APK)

**服务器环境 (Alibaba Cloud Linux):**
- Root访问权限
- 开放端口: 80, 443, 8767

### 部署步骤

#### 步骤1: 初始化服务器

```bash
# 连接到服务器
ssh root@your_server_ip

# 下载并运行初始化脚本
curl -sL https://raw.githubusercontent.com/freshyx724/freshyx-bot/main/deploy/scripts/server-setup.sh | bash

# 完成后退出
exit
```

#### 步骤2: 本地部署

```bash
# 进入项目目录
cd freshyx-bot

# 运行部署脚本
deploy.bat your_server_ip

# 或使用PowerShell
.\deploy.ps1 -ServerIP your_server_ip
```

#### 步骤3: 安装APK

```bash
# 连接Android设备
adb devices

# 安装APK
adb install app/build/app/outputs/flutter-apk/app-release.apk
```

### 手动部署

如果自动化脚本失败，可以手动部署：

#### 服务器端

```bash
# 1. 安装Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18

# 2. 安装PM2
npm install -g pm2

# 3. 上传代码
scp -r server/* root@your_server_ip:/opt/im-bot-gateway/

# 4. 安装依赖
cd /opt/im-bot-gateway/server
npm install --production

# 5. 配置PM2
cp ecosystem.config.js /opt/im-bot-gateway/
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# 6. 配置Nginx
# 编辑 /etc/nginx/conf.d/im-bot-gateway.conf
nginx -t
systemctl reload nginx
```

## 配置文件说明

### ecosystem.config.js

| 参数 | 说明 | 默认值 |
|------|------|--------|
| instances | 实例数量 | 1 |
| max_memory_restart | 最大内存限制 | 500M |
| autorestart | 自动重启 | true |
| watch | 监听模式 | false |

### 环境变量

在 `/opt/im-bot-gateway/server/.env` 中配置:

```bash
NODE_ENV=production    # 运行环境
PORT=8767              # 监听端口
LOG_LEVEL=info        # 日志级别
```

## 管理命令

### PM2 管理

```bash
# 查看状态
pm2 status

# 查看日志
pm2 logs im-bot-gateway

# 重启服务
pm2 restart im-bot-gateway

# 停止服务
pm2 stop im-bot-gateway

# 查看监控
pm2 monit
```

### 健康检查

```bash
# 运行健康检查
bash /opt/im-bot-gateway/deploy/scripts/health-check.sh

# 或添加到cron定时任务
# 0 */1 * * * /opt/im-bot-gateway/deploy/scripts/health-check.sh
```

### 日志管理

```bash
# 查看实时日志
tail -f /var/log/im-bot-gateway/combined.log

# 查看错误日志
tail -f /var/log/im-bot-gateway/error.log

# 日志轮转配置
cat /etc/logrotate.d/im-bot-gateway
```

## 故障排除

### 服务无法启动

```bash
# 检查错误日志
pm2 logs im-bot-gateway --lines 100

# 检查端口占用
netstat -tlnp | grep 8767

# 杀掉占用进程
kill $(lsof -t -i:8767)
```

### WebSocket连接失败

```bash
# 检查防火墙
firewall-cmd --list-ports

# 测试本地连接
curl -N http://localhost:8767

# 检查Nginx代理
nginx -t
systemctl status nginx
```

### 内存不足

```bash
# 查看内存使用
free -m

# 增加swap
dd if=/dev/zero of=/swapfile bs=1M count=1024
mkswap /swapfile
swapon /swapfile
```

## 安全建议

### 生产环境

1. **配置SSL证书**
```bash
# 使用Let's Encrypt
certbot --nginx -d your-domain.com
```

2. **启用防火墙**
```bash
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

3. **配置Fail2Ban**
```bash
yum install -y fail2ban
systemctl enable fail2ban
```

### 监控告警

添加监控脚本到cron:

```bash
# 每5分钟检查服务状态
*/5 * * * * pm2 list | grep -q "online" || pm2 restart im-bot-gateway
```

## 常见问题

Q: 部署脚本运行失败?
A: 确保服务器已运行server-setup.sh初始化脚本

Q: APK无法安装?
A: 检查Android设备的USB调试是否开启

Q: WebSocket连接被拒绝?
A: 检查防火墙规则和Nginx配置

Q: 如何更新应用?
A: 重新运行deploy.bat脚本，会自动备份和更新
