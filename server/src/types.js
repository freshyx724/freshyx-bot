const MessageType = {
  CMD: 'cmd',
  RESULT: 'result',
  PING: 'ping',
  PONG: 'pong',
  CONNECT: 'connect',
  DISCONNECT: 'disconnect'
};

const ClientType = {
  APP: 'app',
  OPENCLAW: 'openclaw'
};

module.exports = { MessageType, ClientType };
