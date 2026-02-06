const WebSocket = require('ws');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runTest() {
  const wss = new WebSocket.Server({ port: 8768 });
  console.log('Test server started on port 8768');
  
  let appClient, openclawClient;
  
  wss.on('connection', (ws) => {
    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      console.log('Server received:', msg);
    });
  });
  
  await sleep(500);
  
  openclawClient = new WebSocket('ws://localhost:8768');
  openclawClient.on('open', () => {
    console.log('OpenClaw connected');
    openclawClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'openclaw'
    }));
  });
  
  await sleep(500);
  
  appClient = new WebSocket('ws://localhost:8768');
  appClient.on('open', () => {
    console.log('App connected');
    appClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'app'
    }));
  });
  
  await sleep(500);
  
  console.log('Sending command...');
  appClient.send(JSON.stringify({
    type: 'cmd',
    id: 'test-cmd-1',
    content: '执行测试脚本',
    timestamp: Date.now()
  }));
  
  await sleep(1000);
  
  console.log('Test completed');
  
  appClient.close();
  openclawClient.close();
  wss.close();
}

runTest().catch(console.error);
