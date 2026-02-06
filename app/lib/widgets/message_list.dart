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
