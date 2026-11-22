class MeshPeer {
  final String id;
  final String displayName;
  final String? deviceId;
  final MeshConnectionMethod connectionMethod;
  final bool isOnline;
  final DateTime lastSeen;
  final String? publicKey;
  final int? rssi;

  const MeshPeer({
    required this.id,
    required this.displayName,
    this.deviceId,
    this.connectionMethod = MeshConnectionMethod.ble,
    this.isOnline = false,
    required this.lastSeen,
    this.publicKey,
    this.rssi,
  });

  MeshPeer copyWith({
    String? id,
    String? displayName,
    String? deviceId,
    MeshConnectionMethod? connectionMethod,
    bool? isOnline,
    DateTime? lastSeen,
    String? publicKey,
    int? rssi,
  }) => MeshPeer(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    deviceId: deviceId ?? this.deviceId,
    connectionMethod: connectionMethod ?? this.connectionMethod,
    isOnline: isOnline ?? this.isOnline,
    lastSeen: lastSeen ?? this.lastSeen,
    publicKey: publicKey ?? this.publicKey,
    rssi: rssi ?? this.rssi,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'deviceId': deviceId,
    'connectionMethod': connectionMethod.name,
    'isOnline': isOnline ? 1 : 0,
    'lastSeen': lastSeen.toIso8601String(),
    'publicKey': publicKey,
    'rssi': rssi,
  };

  factory MeshPeer.fromJson(Map<String, dynamic> json) => MeshPeer(
    id: json['id'] ?? '',
    displayName: json['displayName'] ?? 'Unknown',
    deviceId: json['deviceId'],
    connectionMethod: MeshConnectionMethod.values.firstWhere(
      (m) => m.name == json['connectionMethod'],
      orElse: () => MeshConnectionMethod.ble,
    ),
    isOnline: json['isOnline'] == 1 || json['isOnline'] == true,
    lastSeen: DateTime.parse(json['lastSeen'] ?? DateTime.now().toIso8601String()),
    publicKey: json['publicKey'],
    rssi: json['rssi'],
  );
}

enum MeshConnectionMethod { ble, wifiDirect, lan, qr, nfc }
