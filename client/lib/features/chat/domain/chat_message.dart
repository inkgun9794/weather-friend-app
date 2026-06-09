enum ChatSender { user, character }

enum ChatMessageKind { conversation, briefing, nudge }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.kind = ChatMessageKind.conversation,
    this.audioUrl,
    this.isAttentionNudge = false,
  });

  final String id;
  final ChatSender sender;
  final String text;
  final DateTime createdAt;
  final ChatMessageKind kind;
  final String? audioUrl;
  final bool isAttentionNudge;

  Map<String, Object?> toJson() => {
    'id': id,
    'sender': sender.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
    'audioUrl': audioUrl,
    'isAttentionNudge': isAttentionNudge,
  };

  static ChatMessage? fromJson(Object? value) {
    if (value is! Map) return null;

    final id = value['id'];
    final senderName = value['sender'];
    final text = value['text'];
    final createdAt = value['createdAt'];
    if (id is! String ||
        senderName is! String ||
        text is! String ||
        createdAt is! String) {
      return null;
    }

    final sender = ChatSender.values
        .where((e) => e.name == senderName)
        .firstOrNull;
    final kindName = value['kind'];
    final kind = kindName is String
        ? ChatMessageKind.values.where((e) => e.name == kindName).firstOrNull
        : ChatMessageKind.conversation;
    final timestamp = DateTime.tryParse(createdAt);
    if (sender == null || kind == null || timestamp == null) return null;

    return ChatMessage(
      id: id,
      sender: sender,
      text: text,
      createdAt: timestamp,
      kind: kind,
      audioUrl: value['audioUrl'] as String?,
      isAttentionNudge: value['isAttentionNudge'] == true,
    );
  }
}
