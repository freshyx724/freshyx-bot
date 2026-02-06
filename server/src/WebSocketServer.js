const WebSocket = require('ws');
const { MessageType, ClientType } = require('./types');
const ConnectionManager = require('./ConnectionManager');
const MessageRouter = require('./MessageRouter');
const logger = require('./Logger');

class GatewayWebSocketServer {
  constructor(config) {
    this.wss = null;
    this.config = config;
    this.connectionManager = new ConnectionManager();
    this.messageRouter = new MessageRouter(this.connectionManager);
  }

  start() {
    this.wss = new WebSocket.Server({ port: this.config.port });
    
    this.wss.on('connection', (ws, req) => {
      this.handleConnection(ws);
    });

    console.log(`WebSocket server running on port ${this.config.port}`);
  }

  handleConnection(ws) {
    const clientId = this.generateClientId();
    let registered = false;

    ws.on('message', (data) => {
      const messageStr = data.toString();
      let message;
      
      try {
        message = JSON.parse(messageStr);
      } catch {
        console.error('Invalid JSON received');
        return;
      }

      if (message.type === MessageType.CONNECT) {
        const clientType = message.clientType;
        this.connectionManager.register(ws, clientId, clientType);
        registered = true;
        
        ws.send(JSON.stringify({
          type: MessageType.CONNECT,
          clientId,
          timestamp: Date.now()
        }));
      } else if (registered) {
        this.messageRouter.route(ws, messageStr, clientId);
      }
    });

    ws.on('close', () => {
      if (registered) {
        this.connectionManager.unregister(clientId);
      }
    });

    ws.on('error', (error) => {
      console.error(`Client ${clientId} error:`, error.message);
    });
  }

  generateClientId() {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

module.exports = GatewayWebSocketServer;
