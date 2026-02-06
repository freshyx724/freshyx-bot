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
