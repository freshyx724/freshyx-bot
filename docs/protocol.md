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
