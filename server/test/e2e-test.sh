#!/bin/bash

echo "=== IM Bot Gateway 端到端测试 ==="
echo ""

echo "步骤1: 启动服务端..."
cd server
node src/index.js &
SERVER_PID=$!
echo "服务端已启动 (PID: $SERVER_PID)"
sleep 2

echo ""
echo "步骤2: 检查服务端是否运行..."
if curl -s http://localhost:8767 > /dev/null 2>&1; then
    echo "✅ 服务端运行正常"
else
    echo "❌ 服务端无法访问"
    kill $SERVER_PID 2>/dev/null
    exit 1
fi

echo ""
echo "步骤3: 运行集成测试..."
node test/server.test.js
TEST_RESULT=$?

echo ""
echo "步骤4: 停止服务端..."
kill $SERVER_PID 2>/dev/null

if [ $TEST_RESULT -eq 0 ]; then
    echo ""
    echo "=== 端到端测试完成 ==="
    exit 0
else
    echo ""
    echo "=== 端到端测试失败 ==="
    exit 1
fi
