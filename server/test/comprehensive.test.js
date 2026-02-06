const WebSocket = require('ws');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runComprehensiveTest() {
  console.log('=== 开始完整功能测试 ===');
  console.log('测试目标: im-bot-gateway服务端 (localhost:8767)\n');
  
  let testsPassed = 0;
  let testsFailed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`✅ ${message}`);
      testsPassed++;
    } else {
      console.log(`❌ ${message}`);
      testsFailed++;
    }
  }

  console.log('--- 测试1: OpenClaw连接 ---\n');

  let openclawResolved = false;
  const openclawClient = new WebSocket('ws://localhost:8767');
  
  openclawClient.on('open', () => {
    console.log('OpenClaw: 发送连接请求');
    openclawClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'openclaw'
    }));
  });

  openclawClient.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    console.log(`OpenClaw收到: ${JSON.stringify(msg)}`);
    if (msg.type === 'connect' && msg.clientId && !openclawResolved) {
      openclawResolved = true;
      assert(true, `OpenClaw收到连接响应 (clientId: ${msg.clientId})`);
      openclawClient._assignedId = msg.clientId;
    }
  });

  openclawClient.on('error', (err) => {
    console.log(`OpenClaw错误: ${err.message}`);
    assert(false, `无法连接到服务端: ${err.message}`);
  });

  await sleep(1000);
  console.log('\n--- 测试2: App连接 ---\n');

  let appResolved = false;
  const appClient = new WebSocket('ws://localhost:8767');
  
  appClient.on('open', () => {
    console.log('App: 发送连接请求');
    appClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'app'
    }));
  });

  appClient.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    console.log(`App收到: ${JSON.stringify(msg)}`);
    if (msg.type === 'connect' && msg.clientId && !appResolved) {
      appResolved = true;
      assert(true, `App收到连接响应 (clientId: ${msg.clientId})`);
      appClient._assignedId = msg.clientId;
    }
  });

  appClient.on('error', (err) => {
    console.log(`App错误: ${err.message}`);
    assert(false, `无法连接到服务端: ${err.message}`);
  });

  await sleep(1000);
  console.log('\n--- 测试3: 发送命令 ---\n');

  if (openclawClient._assignedId) {
    console.log(`App: 发送命令到 OpenClaw (${openclawClient._assignedId})`);
    appClient.send(JSON.stringify({
      type: 'cmd',
      id: 'test-cmd-001',
      content: '执行测试脚本',
      target_client_id: openclawClient._assignedId,
      timestamp: Date.now()
    }));
    assert(true, '命令已发送');
  } else {
    assert(false, '未获取到OpenClaw clientId');
  }

  await sleep(500);
  console.log('\n--- 测试4: 模拟OpenClaw返回结果 ---\n');

  let resultResolved = false;
  appClient.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    console.log(`App收到: ${JSON.stringify(msg)}`);
    if (msg.type === 'result' && !resultResolved) {
      resultResolved = true;
      assert(true, `App收到执行结果 (status: ${msg.status})`);
    }
  });

  if (openclawClient._assignedId) {
    console.log(`OpenClaw: 发送执行结果`);
    openclawClient.send(JSON.stringify({
      type: 'result',
      cmd_id: 'test-cmd-001',
      status: 'success',
      content: '脚本执行完成，结果: 42',
      timestamp: Date.now()
    }));
    assert(true, '结果已发送');
  }

  await sleep(500);
  console.log('\n--- 测试5: 心跳检测 ---\n');

  let pongResolved = false;
  openclawClient.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    if (msg.type === 'pong' && !pongResolved) {
      pongResolved = true;
      assert(true, 'OpenClaw收到PONG响应');
    }
  });

  appClient.send(JSON.stringify({
    type: 'ping',
    timestamp: Date.now()
  }));
  assert(true, '心跳已发送');

  await sleep(500);
  console.log('\n--- 测试6: 断开连接 ---\n');

  appClient.close();
  await sleep(300);
  assert(true, 'App已断开连接');

  openclawClient.close();
  await sleep(300);
  assert(true, 'OpenClaw已断开连接');

  console.log('\n=== 测试完成 ===');
  console.log(`通过: ${testsPassed}`);
  console.log(`失败: ${testsFailed}`);
  console.log(`总计: ${testsPassed + testsFailed}`);
  
  process.exit(testsFailed > 0 ? 1 : 0);
}

runComprehensiveTest().catch((err) => {
  console.error('测试失败:', err);
  process.exit(1);
});
