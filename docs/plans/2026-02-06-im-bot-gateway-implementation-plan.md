# im-bot-gateway MVP 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 实现MVP版本，包括服务端WebSocket服务器和Flutter客户端App，实现手机端发送命令给OpenClaw并接收执行结果

**架构:** C/S架构，服务端提供WebSocket长连接服务，作为消息路由中转；Flutter客户端提供对话框界面；OpenClaw作为另一个客户端连接服务端

**技术栈:** Node.js + ws (服务端), Flutter (客户端), JSON (消息格式)

---

## 阶段一：服务端开发

### Task 1: 初始化Node.js项目

**文件:**
- 创建: `server/package.json`
- 创建: `server/config.json`

**Step 1: 创建package.json**

```json
{
  "name": "im-bot-gateway-server",
  "version": "1.0.0",
  "description": "IM Bot Gateway WebSocket Server",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "ws": "^8.14.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

**Step 2: 创建config.json**

```json
{
  "port": 8767,
  "heartbeatInterval": 30000,
  "maxClients": 100
}
```

**Step 3: 初始化npm并安装依赖**

```bash
cd server
npm init -y
npm install ws
npm install --save-dev nodemon
```

**Step 4: 提交**

```bash
git add server/package.json server/config.json
git commit -m "feat: 初始化服务端项目结构"
```

---

### Task 2: 实现WebSocket服务器核心

**文件:**
- 创建: `server/src/index.js`
- 创建: `server/src/WebSocketServer.js`
- 创建: `server/src/types.js`

**Step 1: 创建types.js**

```javascript
// 消息类型定义
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
```

**Step 2: 创建WebSocketServer.js**

```javascript
const WebSocket = require('ws');
const { MessageType, ClientType } = require('./types');

class GatewayWebSocketServer {
  constructor(config) {
    this.wss = null;
    this.config = config;
    this.sessions = new Map(); // sessionId -> { ws, type, createdAt }
    this.openclawConnections = new Map(); // clientId -> ws
    this.appConnections = new Map(); // clientId -> ws
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

    // 发送连接确认
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
```

**Step 3: 创建index.js**

```javascript
const GatewayWebSocketServer = require('./WebSocketServer');
const config = require('../config.json');

const server = new GatewayWebSocketServer(config);
server.start();

console.log('im-bot-gateway-server started');
```

**Step 4: 提交**

```bash
git add server/src/
git commit -m "feat: 实现WebSocket服务器核心框架"
```

---

### Task 3: 实现消息路由和连接管理

**文件:**
- 修改: `server/src/WebSocketServer.js`
- 创建: `server/src/ConnectionManager.js`
- 创建: `server/src/MessageRouter.js`

**Step 1: 创建ConnectionManager.js**

```javascript
const { ClientType, MessageType } = require('./types');

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
```

**Step 2: 创建MessageRouter.js**

```javascript
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
```

**Step 3: 修改WebSocketServer.js集成新模块**

```javascript
const WebSocket = require('ws');
const { MessageType, ClientType } = require('./types');
const ConnectionManager = require('./ConnectionManager');
const MessageRouter = require('./MessageRouter');

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
        this.connectionManager.unregister(clientId, null);
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
```

**Step 4: 提交**

```bash
git add server/src/
git commit -m "feat: 实现消息路由和连接管理"
```

---

### Task 4: 实现简单日志系统

**文件:**
- 创建: `server/src/Logger.js`
- 修改: `server/src/WebSocketServer.js`

**Step 1: 创建Logger.js**

```javascript
class Logger {
  constructor() {
    this.logs = [];
    this.maxLogs = 1000;
  }

  log(level, message, data = null) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      data
    };
    
    this.logs.push(entry);
    
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
    
    const formatted = `[${level.toUpperCase()}] ${message}${data ? ' ' + JSON.stringify(data) : ''}`;
    console.log(formatted);
    
    return entry;
  }

  info(message, data) {
    return this.log('info', message, data);
  }

  error(message, data) {
    return this.log('error', message, data);
  }

  warn(message, data) {
    return this.log('warn', message, data);
  }

  debug(message, data) {
    return this.log('debug', message, data);
  }

  getRecentLogs(count = 100) {
    return this.logs.slice(-count);
  }

  clear() {
    this.logs = [];
  }
}

module.exports = new Logger();
```

**Step 2: 修改WebSocketServer.js使用日志**

在文件顶部添加：
```javascript
const logger = require('./Logger');
```

在handleConnection方法中添加：
```javascript
logger.info('New connection', { clientId });
```

在各类事件中添加相应日志

**Step 3: 提交**

```bash
git add server/src/
git commit -m "feat: 实现简单日志系统"
```

---

## 阶段二：Flutter客户端开发

### Task 5: 初始化Flutter项目

**文件:**
- 创建: `app/pubspec.yaml`
- 创建: `app/lib/main.dart`

**Step 1: 创建pubspec.yaml**

```yaml
name: im_bot_gateway
description: IM Bot Gateway Mobile Client

publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  web_socket_channel: ^2.4.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

**Step 2: 创建main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:im_bot_gateway/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IM Bot Gateway',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

**Step 3: 提交**

```bash
git add app/pubspec.yaml app/lib/main.dart
git commit -m "feat: 初始化Flutter项目"
```

---

### Task 6: 实现消息模型

**文件:**
- 创建: `app/lib/models/message.dart`

**Step 1: 创建message.dart**

```dart
enum MessageType { cmd, result, ping, pong, connect }

class Message {
  final MessageType type;
  final String? id;
  final String? content;
  final String? status;
  final String? cmdId;
  final String? targetClientId;
  final int timestamp;

  Message({
    required this.type,
    this.id,
    this.content,
    this.status,
    this.cmdId,
    this.targetClientId,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.cmd,
      ),
      id: json['id'],
      content: json['content'],
      status: json['status'],
      cmdId: json['cmd_id'],
      targetClientId: json['target_client_id'],
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().replaceAll('MessageType.', ''),
      'id': id,
      'content': content,
      'cmd_id': cmdId,
      'target_client_id': targetClientId,
      'timestamp': timestamp,
    };
  }

  Message copyWith({
    MessageType? type,
    String? id,
    String? content,
    String? status,
    String? cmdId,
    String? targetClientId,
    int? timestamp,
  }) {
    return Message(
      type: type ?? this.type,
      id: id ?? this.id,
      content: content ?? this.content,
      status: status ?? this.status,
      cmdId: cmdId ?? this.cmdId,
      targetClientId: targetClientId ?? this.targetClientId,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
```

**Step 2: 提交**

```bash
git add app/lib/models/message.dart
git commit -m "feat: 实现消息模型"
```

---

### Task 7: 实现WebSocket服务

**文件:**
- 创建: `app/lib/services/websocket_service.dart`
- 创建: `app/lib/services/logger.dart`

**Step 1: 创建logger.dart**

```dart
class Logger {
  static void info(String message, [dynamic data]) {
    print('[INFO] $message${data != null ? ' $data' : ''}');
  }

  static void error(String message, [dynamic data]) {
    print('[ERROR] $message${data != null ? ' $data' : ''}');
  }

  static void debug(String message, [dynamic data]) {
    print('[DEBUG] $message${data != null ? ' $data' : ''}');
  }

  static void warn(String message, [dynamic data]) {
    print('[WARN] $message${data != null ? ' $data' : ''}');
  }
}
```

**Step 2: 创建websocket_service.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String serverUrl;
  final void Function(Message) onMessage;
  final void Function() onConnected;
  final void Function() onDisconnected;
  final void Function(String) onError;
  
  String? _clientId;
  bool _isConnected = false;
  final _uuid = const Uuid();
  Timer? _heartbeatTimer;

  WebSocketService({
    required this.serverUrl,
    required this.onMessage,
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
  });

  Future<void> connect() async {
    try {
      Logger.info('Connecting to $serverUrl...');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _handleError(error),
        onDone: () => _handleDone(),
      );
    } catch (e) {
      Logger.error('Connection failed', e);
      onError(e.toString());
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final msg = Message.fromJson(data);
      
      Logger.debug('Received: $msg');
      
      if (msg.type == MessageType.connect) {
        _clientId = msg.id;
        _isConnected = true;
        _startHeartbeat();
        onConnected();
      } else {
        onMessage(msg);
      }
    } catch (e) {
      Logger.error('Failed to parse message', e);
    }
  }

  void _handleError(dynamic error) {
    Logger.error('WebSocket error', error);
    _cleanup();
    onError(error.toString());
  }

  void _handleDone() {
    Logger.info('WebSocket connection closed');
    _cleanup();
    onDisconnected();
  }

  void sendCommand(String content, {String? targetClientId}) {
    if (!_isConnected || _channel == null) {
      Logger.error('Not connected');
      return;
    }

    final message = Message(
      type: MessageType.cmd,
      id: _uuid.v4(),
      content: content,
      targetClientId: targetClientId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _channel!.sink.add(jsonEncode(message.toJson()));
    Logger.info('Command sent: $content');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendPing(),
    );
  }

  void _sendPing() {
    if (!_isConnected || _channel == null) return;
    
    final ping = Message(
      type: MessageType.ping,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _channel!.sink.add(jsonEncode(ping.toJson()));
  }

  void _cleanup() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void disconnect() {
    _channel?.sink.close();
    _cleanup();
  }

  bool get isConnected => _isConnected;
  String? get clientId => _clientId;
}
```

**Step 3: 提交**

```bash
git add app/lib/services/
git commit -m "feat: 实现WebSocket服务"
```

---

### Task 8: 实现UI组件

**文件:**
- 创建: `app/lib/widgets/command_input.dart`
- 创建: `app/lib/widgets/message_list.dart`
- 修改: `app/lib/screens/home_screen.dart`

**Step 1: 创建command_input.dart**

```dart
import 'package:flutter/material.dart';

class CommandInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const CommandInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: '输入命令...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: enabled ? (_) => onSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
            label: const Text('发送'),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: 创建message_list.dart**

```dart
import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;

  const MessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageTile(message);
      },
    );
  }

  Widget _buildMessageTile(Message message) {
    final isCommand = message.type == MessageType.cmd;
    final isResult = message.type == MessageType.result;
    
    return Align(
      alignment: isCommand ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCommand 
              ? Colors.blue[100] 
              : isResult 
                  ? Colors.green[100] 
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isResult && message.status != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.status == 'success' 
                        ? Icons.check_circle 
                        : Icons.error,
                    size: 16,
                    color: message.status == 'success' 
                        ? Colors.green 
                        : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.status!,
                    style: TextStyle(
                      fontSize: 12,
                      color: message.status == 'success' 
                          ? Colors.green 
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(message.content ?? ''),
            Text(
              _formatTime(message.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
```

**Step 3: 创建home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/logger.dart';
import '../widgets/command_input.dart';
import '../widgets/message_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _commandController = TextEditingController();
  final List<Message> _messages = [];
  final _uuid = const Uuid();
  
  late WebSocketService _wsService;
  bool _isConnected = false;
  String _connectionStatus = '未连接';
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsService = WebSocketService(
      serverUrl: 'ws://localhost:8767',
      onMessage: _handleMessage,
      onConnected: _handleConnected,
      onDisconnected: _handleDisconnected,
      onError: _handleError,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wsService.connect();
    });
  }

  void _handleMessage(Message message) {
    setState(() {
      _messages.add(message);
    });
  }

  void _handleConnected() {
    setState(() {
      _isConnected = true;
      _connectionStatus = '已连接';
      _clientId = _wsService.clientId;
    });
    Logger.info('Connected with clientId: $_clientId');
  }

  void _handleDisconnected() {
    setState(() {
      _isConnected = false;
      _connectionStatus = '已断开';
      _clientId = null;
    });
    Logger.info('Disconnected');
  }

  void _handleError(String error) {
    setState(() {
      _connectionStatus = '连接错误';
    });
    Logger.error('Error', error);
  }

  void _sendCommand() {
    final content = _commandController.text.trim();
    if (content.isEmpty || !_isConnected) return;
    
    final message = Message(
      type: MessageType.cmd,
      id: _uuid.v4(),
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    setState(() {
      _messages.add(message);
    });
    
    _wsService.sendCommand(content);
    _commandController.clear();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IM Bot Gateway'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_clientId != null)
                    Text(
                      'ID: ${_clientId!.substring(0, 8)}...',
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageList(messages: _messages),
          ),
          CommandInput(
            controller: _commandController,
            onSend: _sendCommand,
            enabled: _isConnected,
          ),
        ],
      ),
    );
  }
}
```

**Step 4: 提交**

```bash
git add app/lib/widgets/ app/lib/screens/
git commit -m "feat: 实现UI组件"
```

---

### Task 9: Android平台配置

**文件:**
- 创建: `app/android/app/build.gradle` (修改)
- 创建: `app/android/app/src/main/AndroidManifest.xml` (修改)

**Step 1: 确保Android配置正确**

```gradle
android {
    namespace "com.example.im_bot_gateway"
    compileSdk 34
    defaultConfig {
        applicationId "com.example.im_bot_gateway"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
```

**Step 2: AndroidManifest.xml**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="IM Bot Gateway"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

**Step 3: 提交**

```bash
git add app/android/
git commit -m "feat: 配置Android平台"
```

---

## 阶段三：集成测试

### Task 10: 服务端测试

**文件:**
- 创建: `server/test/server.test.js`

**Step 1: 创建测试文件**

```javascript
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
  
  // 模拟OpenClaw连接
  openclawClient = new WebSocket('ws://localhost:8768');
  openclawClient.on('open', () => {
    console.log('OpenClaw connected');
    openclawClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'openclaw'
    }));
  });
  
  await sleep(500);
  
  // 模拟App连接
  appClient = new WebSocket('ws://localhost:8768');
  appClient.on('open', () => {
    console.log('App connected');
    appClient.send(JSON.stringify({
      type: 'connect',
      clientType: 'app'
    }));
  });
  
  await sleep(500);
  
  // 测试发送命令
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
```

**Step 2: 运行测试**

```bash
cd server
node test/server.test.js
```

**Step 3: 提交**

```bash
git add server/test/
git commit -m "test: 添加服务端测试"
```

---

### Task 11: 端到端集成测试

**Step 1: 启动服务端**

```bash
cd server
npm start
```

**Step 2: 运行Flutter应用**

```bash
cd app
flutter run -d android
```

**Step 3: 验证功能**

1. 检查服务端日志，确认两个客户端连接
2. 在App中发送测试命令
3. 检查服务端是否正确路由消息
4. 验证消息格式正确

**Step 4: 提交**

```bash
git commit -m "test: 端到端集成测试"
```

---

## 阶段四：文档和完善

### Task 12: 编写README和协议文档

**文件:**
- 创建: `README.md`
- 创建: `docs/protocol.md`

**Step 1: 创建README.md**

```markdown
# im-bot-gateway

IM Bot Gateway - 一个独立的IM通信App，用于与OpenClaw设备进行人机交互。

## 快速开始

### 服务端

```bash
cd server
npm install
npm start
```

### 客户端

```bash
cd app
flutter pub get
flutter run -d android
```

## 架构

- 服务端: Node.js + WebSocket
- 客户端: Flutter (跨平台)
- 协议: JSON over WebSocket

## 功能

- [x] WebSocket长连接
- [x] 命令发送和结果回传
- [x] 简单日志
- [ ] 用户认证
- [ ] 离线消息
```

**Step 2: 创建protocol.md**

```markdown
# 消息协议

## 消息格式

所有消息均为JSON格式。

## 消息类型

### CONNECT - 连接
```json
{
  "type": "connect",
  "clientType": "app|openclaw"
}
```

### CMD - 命令
```json
{
  "type": "cmd",
  "id": "uuid",
  "content": "命令内容",
  "target_client_id": "openclaw-client-id",
  "timestamp": 1234567890
}
```

### RESULT - 结果
```json
{
  "type": "result",
  "cmd_id": "command-uuid",
  "status": "success|error",
  "content": "执行结果",
  "timestamp": 1234567890
}
```

### PING/PONG - 心跳
```json
{"type": "ping", "timestamp": 1234567890}
```

## 连接流程

1. 客户端连接WebSocket
2. 发送CONNECT消息
3. 服务端返回CONNECT响应（含clientId）
4. 开始正常消息交互
```

**Step 3: 提交**

```bash
git add README.md docs/
git commit -m "docs: 添加README和协议文档"
```

---

## 计划完成摘要

| 阶段 | 任务数 | 预计时间 |
|------|--------|----------|
| 服务端开发 | 4 | 2-3小时 |
| Flutter客户端开发 | 5 | 3-4小时 |
| 集成测试 | 2 | 1-2小时 |
| 文档完善 | 1 | 30分钟 |

**总计: 6.5-9.5小时**
