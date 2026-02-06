import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/logger.dart';
import '../widgets/command_input.dart';
import '../widgets/message_list.dart';
import '../config.dart';

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
      serverUrl: AppConfig.serverUrl,
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
