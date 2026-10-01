class ChatMessage {
  final String content;
  final bool isUser;
  final List<String> citations;
  final Map<String, String> documentLinks;
  final String? imageUrl;
  final bool isRewritten;
  final String? rewrittenQuery;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.citations = const [],
    this.documentLinks = const {},
    this.imageUrl,
    this.isRewritten = false,
    this.rewrittenQuery,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromMap(Map<String, dynamic> map, {required bool isUser}) {
    return ChatMessage(
      content: map['answer'] ?? map['query'] ?? '',
      isUser: isUser,
      citations: List<String>.from(map['citations'] ?? []),
      documentLinks: (map['document_links'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      imageUrl: map['image_url'],
      isRewritten: map['rewritten'] ?? false,
      rewrittenQuery: map['rewritten_query'],
    );
  }
}
