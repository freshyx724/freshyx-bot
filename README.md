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
