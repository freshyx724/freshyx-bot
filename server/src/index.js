const GatewayWebSocketServer = require('./WebSocketServer');
const config = require('../config.json');

const server = new GatewayWebSocketServer(config);
server.start();

console.log('im-bot-gateway-server started');
