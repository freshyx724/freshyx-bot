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
