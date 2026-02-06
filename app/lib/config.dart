class AppConfig {
  // ==================== 服务器配置 ====================
  
  // 开发环境: 使用localhost
  // static const String serverUrl = 'ws://localhost:8767';
  
  // 生产环境: 修改为你的服务器IP
  // 例如: ws://192.168.1.100:8767
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'ws://localhost:8767'
  );
  
  // ==================== 应用配置 ====================
  
  static const String appName = 'Freshyx Bot';
  static const String appVersion = '1.0.0';
  
  // 心跳间隔 (毫秒)
  static const int heartbeatInterval = 30000;
  
  // 连接超时 (毫秒)
  static const int connectionTimeout = 10000;
  
  // 重连间隔 (毫秒)
  static const int reconnectInterval = 5000;
  
  // 最大重连次数
  static const int maxReconnectAttempts = 5;
  
  // ==================== 日志配置 ====================
  
  static bool enableDebugLog = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false
  );
}

// 使用示例:
//
// 1. 默认连接 (localhost):
//    flutter run
//
// 2. 指定服务器地址:
//    flutter run --dart-define=SERVER_URL=ws://192.168.1.100:8767
//
// 3. 发布版本:
//    flutter build apk --release --dart-define=SERVER_URL=ws://YOUR_SERVER_IP:8767
//
// 4. 调试模式:
//    flutter run --dart-define=DEBUG=true
