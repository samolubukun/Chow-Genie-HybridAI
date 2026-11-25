enum MessageType { user, ai, system }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? imagePath;
  final List<String> imagePaths;
  final String? modelName;
  final bool? isOnDevice;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.imagePath,
    this.imagePaths = const [],
    this.modelName,
    this.isOnDevice,
  });

  factory ChatMessage.user({
    required String content,
    String? imagePath,
    List<String> imagePaths = const [],
  }) {
    final effectivePaths = imagePaths.isNotEmpty
        ? imagePaths
        : (imagePath != null ? [imagePath] : <String>[]);
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
      imagePath: effectivePaths.isNotEmpty ? effectivePaths.first : null,
      imagePaths: effectivePaths,
    );
  }

  factory ChatMessage.ai({
    required String content,
    String? modelName,
    bool? isOnDevice,
  }) =>
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        content: content,
        type: MessageType.ai,
        timestamp: DateTime.now(),
        modelName: modelName,
        isOnDevice: isOnDevice,
      );

  factory ChatMessage.system({required String content}) =>
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        content: content,
        type: MessageType.system,
        timestamp: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
    'imagePaths': imagePaths,
    'modelName': modelName,
    'isOnDevice': isOnDevice,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final paths = (json['imagePaths'] as List?)?.map((e) => e.toString()).toList() ??
        (json['imagePath'] != null ? [json['imagePath'].toString()] : <String>[]);
    return ChatMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.system,
      ),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      imagePath: json['imagePath'] ?? (paths.isNotEmpty ? paths.first : null),
      imagePaths: paths,
      modelName: json['modelName'] as String?,
      isOnDevice: json['isOnDevice'] as bool?,
    );
  }

  bool get hasImage => (imagePath != null && imagePath!.isNotEmpty) || imagePaths.isNotEmpty;
  List<String> get allImagePaths => imagePaths.isNotEmpty ? imagePaths : (imagePath != null ? [imagePath!] : []);
}
