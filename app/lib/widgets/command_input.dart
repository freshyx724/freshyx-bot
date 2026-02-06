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
