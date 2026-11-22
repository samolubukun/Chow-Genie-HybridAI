enum MeshMessageType { text, recipe, photo, voice, mealPlan, pantry, poll }

class MeshMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? receiverId;
  final String? groupId;
  final MeshMessageType messageType;
  final String content;
  final String? attachmentPath;
  final String? recipeJson;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final bool isRelayed;
  final String? replyToId;

  const MeshMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    this.groupId,
    this.messageType = MeshMessageType.text,
    required this.content,
    this.attachmentPath,
    this.recipeJson,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    this.isRelayed = false,
    this.replyToId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'groupId': groupId,
    'messageType': messageType.name,
    'content': content,
    'attachmentPath': attachmentPath,
    'recipeJson': recipeJson,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead ? 1 : 0,
    'isDelivered': isDelivered ? 1 : 0,
    'isRelayed': isRelayed ? 1 : 0,
    'replyToId': replyToId,
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
    id: json['id'] ?? '',
    senderId: json['senderId'] ?? '',
    senderName: json['senderName'] ?? '',
    receiverId: json['receiverId'],
    groupId: json['groupId'],
    messageType: MeshMessageType.values.firstWhere(
      (t) => t.name == json['messageType'],
      orElse: () => MeshMessageType.text,
    ),
    content: json['content'] ?? '',
    attachmentPath: json['attachmentPath'],
    recipeJson: json['recipeJson'],
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    isRead: json['isRead'] == 1 || json['isRead'] == true,
    isDelivered: json['isDelivered'] == 1 || json['isDelivered'] == true,
    isRelayed: json['isRelayed'] == 1 || json['isRelayed'] == true,
    replyToId: json['replyToId'],
  );

  MeshMessage copyWith({bool? isRead, bool? isDelivered}) => MeshMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    receiverId: receiverId,
    groupId: groupId,
    messageType: messageType,
    content: content,
    attachmentPath: attachmentPath,
    recipeJson: recipeJson,
    timestamp: timestamp,
    isRead: isRead ?? this.isRead,
    isDelivered: isDelivered ?? this.isDelivered,
    isRelayed: isRelayed,
    replyToId: replyToId,
  );
}

class MeshGroup {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? inviteCode;

  const MeshGroup({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    this.memberIds = const [],
    required this.createdAt,
    this.inviteCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'creatorId': creatorId,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
    'inviteCode': inviteCode,
  };

  factory MeshGroup.fromJson(Map<String, dynamic> json) => MeshGroup(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    creatorId: json['creatorId'] ?? '',
    memberIds: List<String>.from(json['memberIds'] ?? []),
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    inviteCode: json['inviteCode'],
  );
}
