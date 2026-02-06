const { ClientType } = require('./types');

class ConnectionManager {
  constructor() {
    this.openclawConnections = new Map();
    this.appConnections = new Map();
  }

  register(ws, clientId, clientType) {
    if (clientType === ClientType.OPENCLAW) {
      this.openclawConnections.set(clientId, { ws, connectedAt: Date.now() });
    } else if (clientType === ClientType.APP) {
      this.appConnections.set(clientId, { ws, connectedAt: Date.now() });
    }
    console.log(`Registered ${clientType}: ${clientId}`);
  }

  unregister(clientId, clientType) {
    if (clientType === ClientType.OPENCLAW) {
      this.openclawConnections.delete(clientId);
    } else if (clientType === ClientType.APP) {
      this.appConnections.delete(clientId);
    }
    console.log(`Unregistered ${clientType}: ${clientId}`);
  }

  getOpenClaw(clientId) {
    return this.openclawConnections.get(clientId);
  }

  getAllOpenClawConnections() {
    return Array.from(this.openclawConnections.entries());
  }

  getAppConnection(clientId) {
    return this.appConnections.get(clientId);
  }

  getAllAppConnections() {
    return Array.from(this.appConnections.entries());
  }

  broadcastToApps(message) {
    const messageStr = JSON.stringify(message);
    for (const [clientId, { ws }] of this.appConnections) {
      if (ws.readyState === 1) {
        ws.send(messageStr);
      }
    }
  }

  getOpenClawCount() {
    return this.openclawConnections.size;
  }

  getAppCount() {
    return this.appConnections.size;
  }
}

module.exports = ConnectionManager;
