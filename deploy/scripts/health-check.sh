#!/bin/bash

echo "========================================"
echo "  im-bot-gateway 健康检查"
echo "========================================"
echo ""

# 配置
PROJECT_DIR="/opt/im-bot-gateway"
LOG_FILE="/var/log/im-bot-gateway/health-check.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "[PASS] $1" >> "$LOG_FILE"
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "$LOG_FILE"
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "[FAIL] $1" >> "$LOG_FILE"
}

echo "[检查时间: $(date '+%Y-%m-%d %H:%M:%S')]"
echo ""

# 1. PM2服务检查
echo "=== PM2 服务状态 ==="
if command -v pm2 &> /dev/null; then
    STATUS=$(pm2 status im-bot-gateway 2>/dev/null | grep -c "online" || echo "0")
    if [ "$STATUS" -gt 0 ]; then
        check_pass "PM2服务运行中"
        pm2 status im-bot-gateway | grep -E "(id|name|status|cpu|memory)" | head -5
    else
        check_fail "PM2服务未运行"
    fi
else
    check_fail "PM2未安装"
fi

echo ""

# 2. 端口检查
echo "=== 端口监听 ==="
if ss -tlnp 2>/dev/null | grep -q ":8767 "; then
    check_pass "端口8767已监听"
    ss -tlnp | grep 8767
else
    check_warn "端口8767未监听"
fi

echo ""

# 3. 进程检查
echo "=== 进程状态 ==="
if pgrep -f "node.*index.js" > /dev/null; then
    check_pass "Node进程运行中"
    ps aux | grep "node.*index.js" | grep -v grep | head -3
else
    check_fail "Node进程未找到"
fi

echo ""

# 4. 内存使用
echo "=== 内存使用 ==="
if command -v free &> /dev/null; then
    free -h
    echo ""
fi

if [ -d "$PROJECT_DIR/server" ]; then
    du -sh "$PROJECT_DIR" 2>/dev/null
    echo "项目目录大小"
fi

echo ""

# 5. 日志检查
echo "=== 日志状态 ==="
if [ -d "/var/log/im-bot-gateway" ]; then
    LOG_SIZE=$(du -sh /var/log/im-bot-gateway 2>/dev/null | cut -f1)
    check_pass "日志目录存在 ($LOG_SIZE)"
    
    LATEST_LOG=$(ls -t /var/log/im-bot-gateway/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        LAST_LINE=$(tail -5 "$LATEST_LOG" 2>/dev/null | head -1)
        echo "最新日志: $LAST_LINE"
    fi
else
    check_warn "日志目录不存在"
fi

echo ""

# 6. 连接数
echo "=== WebSocket连接数 ==="
if ss -tn 2>/dev/null | grep -c ":8767" | grep -q "[0-9]"; then
    CONNECTIONS=$(ss -tn | grep ":8767" | wc -l)
    echo "当前连接数: $CONNECTIONS"
else
    echo "当前连接数: 0"
fi

echo ""

# 7. Nginx状态
echo "=== Nginx状态 ==="
if command -v nginx &> /dev/null; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        check_pass "Nginx运行中"
    else
        check_warn "Nginx未运行"
    fi
else
    check_warn "Nginx未安装"
fi

echo ""

# 8. 磁盘空间
echo "=== 磁盘空间 ==="
df -h / | tail -1
df -h /opt | tail -1

echo ""

# 总结
echo "========================================"
echo "  检查完成"
echo "========================================"
echo ""
echo "相关命令:"
echo "  查看日志: pm2 logs im-bot-gateway"
echo "  重启服务: pm2 restart im-bot-gateway"
echo "  查看监控: pm2 monit"
echo ""
