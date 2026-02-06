# im-bot-gateway 设计方案

> **项目概述:** 一个独立的IM通信App，用于与OpenClaw设备进行人机交互

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│                    云服务器                               │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │              im-bot-gateway-server              │   │
│   │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │   │
│   │  │ WS Server│  │  Router │  │ Session │         │   │
│   │  │  (8767)  │  │         │  │ Manager │         │   │
│   │  └─────────┘  └─────────┘  └─────────┘         │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
         │                              │
         │ WebSocket                    │ WebSocket
         ▼                              ▼
┌─────────────────┐            ┌─────────────────┐
│   Flutter App   │            │    OpenClaw     │
│  (手机用户端)    │            │   (设备客户端)   │
│                 │            │                 │
│ • 对话框UI      │            │ • 命令解析执行   │
│ • 命令发送      │            │ • 结果回传      │
│ • 结果展示      │            │ • 心跳保活      │
│ • 简单日志      │            │                 │
└─────────────────┘            └─────────────────┘
```

## 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| **服务端** | Node.js + ws | 轻量、WebSocket成熟 |
| **手机端** | Flutter | 跨平台、高性能 |
| **消息格式** | JSON | 便于调试 |
| **日志** | 内存缓存 + 控制台 | MVP简单方案 |

## 消息协议

### 命令消息 (手机端 → 服务端 → OpenClaw)
```json
{
  "type": "cmd",
  "id": "uuid-xxx",
  "content": "执行xxx自动化脚本",
  "timestamp": 1234567890
}
```

### 结果回传 (OpenClaw → 服务端 → 手机端)
```json
{
  "type": "result",
  "cmd_id": "uuid-xxx",
  "status": "success|error",
  "content": "执行完成，结果...",
  "timestamp": 1234567891
}
```

### 心跳 (双向)
```json
{
  "type": "ping",
  "timestamp": 1234567890
}
```

## MVP功能范围

| 功能 | 状态 |
|------|------|
| WebSocket长连接 | ✅ |
| 用户对话框界面 | ✅ |
| 命令发送 | ✅ |
| 结果回显 | ✅ |
| 简单日志（内存） | ✅ |
| OpenClaw连接管理 | ✅ |
| 用户认证 | ❌ |
| 离线消息 | ❌ |
| 消息持久化 | ❌ |

## 目录结构

```
im-bot-gateway/
├── server/                    # 服务端
│   ├── src/
│   │   ├── index.js          # 入口
│   │   ├── WebSocketServer.js
│   │   ├── SessionManager.js
│   │   └── MessageHandler.js
│   ├── package.json
│   └── config.json
├── app/                       # Flutter客户端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── services/
│   │   │   ├── websocket_service.dart
│   │   │   └── logger.dart
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   ├── widgets/
│   │   │   ├── command_input.dart
│   │   │   └── message_list.dart
│   │   └── models/
│   │       └── message.dart
│   ├── pubspec.yaml
│   └── android/
├── docs/
│   └── protocol.md
└── README.md
```

## 连接方式说明

1. OpenClaw设备作为客户端，主动连接云服务器的WebSocket服务
2. 手机App用户端也作为客户端，连接同一个WebSocket服务
3. 服务端负责路由转发：手机端发送的命令 → 转发给对应的OpenClaw设备
4. OpenClaw执行完成后，结果回传给服务端 → 转发给手机端显示

## 关键设计决策

1. **不处理离线消息** - MVP阶段命令发不出去就算了
2. **暂不需要用户认证** - MVP验证功能为主
3. **需要消息确认** - 确保命令送达并获取执行结果
4. **简单日志** - 仅内存缓存用于调试
