const { MessageType } = require('./types');

class MessageRouter {
  constructor(connectionManager) {
    this.connectionManager = connectionManager;
  }

  route(ws, message, senderId) {
    const msg = typeof message === 'string' ? JSON.parse(message) : message;
    
    switch (msg.type) {
      case MessageType.CMD:
        return this.routeCommand(msg, senderId);
      case MessageType.RESULT:
        return this.routeResult(msg);
      default:
        console.log(`Unknown message type: ${msg.type}`);
        return null;
    }
  }

  routeCommand(message, senderId) {
    const { targetClientId } = message;
    const openclaw = this.connectionManager.getOpenClaw(targetClientId);
    
    if (openclaw && openclaw.ws.readyState === 1) {
      openclaw.ws.send(JSON.stringify(message));
      return { success: true, delivered: true };
    }
    
    return { success: false, delivered: false, reason: 'Target not connected' };
  }

  routeResult(message) {
    const { cmdId, fromClientId } = message;
    const sender = this.connectionManager.getAppConnection(fromClientId);
    
    if (sender && sender.ws.readyState === 1) {
      sender.ws.send(JSON.stringify(message));
      return { success: true, delivered: true };
    }
    
    return { success: false, delivered: false, reason: 'Sender not connected' };
  }
}

module.exports = MessageRouter;
