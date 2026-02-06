const WebSocket = require('ws');
const { MessageType, ClientType } = require('./types');

class GatewayWebSocketServer {
  constructor(config) {
    this.wss = null;
    this.config = config;
    this.sessions = new Map();
    this.openclawConnections = new Map();
    this.appConnections = new Map();
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
    let clientType = null;
    let heartbeatTimer = null;

    const sendPing = () => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: MessageType.PING, timestamp: Date.now() }));
      }
    };

    ws.on('message', (data) => {
      this.handleMessage(ws, data, clientId);
    });

    ws.on('close', () => {
      if (heartbeatTimer) clearInterval(heartbeatTimer);
      this.handleDisconnect(clientId, clientType);
    });

    ws.on('error', (error) => {
      console.error(`Client ${clientId} error:`, error.message);
    });

    ws.send(JSON.stringify({
      type: MessageType.CONNECT,
      clientId,
      timestamp: Date.now()
    }));
  }

  handleMessage(ws, data, clientId) {
    try {
      const message = JSON.parse(data.toString());
      
      switch (message.type) {
        case MessageType.PING:
          ws.send(JSON.stringify({ type: MessageType.PONG, timestamp: Date.now() }));
          break;
        default:
          console.log(`Received:`, message);
      }
    } catch (error) {
      console.error('Failed to parse message:', error.message);
    }
  }

  handleDisconnect(clientId, clientType) {
    if (clientType === ClientType.OPENCLAW) {
      this.openclawConnections.delete(clientId);
    } else if (clientType === ClientType.APP) {
      this.appConnections.delete(clientId);
    }
    console.log(`Client ${clientId} disconnected`);
  }

  generateClientId() {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

module.exports = GatewayWebSocketServer;
