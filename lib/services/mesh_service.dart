import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mesh_peer.dart';
import '../models/mesh_message.dart';
import 'local_db_service.dart';

class MeshService extends ChangeNotifier {
  final LocalDbService _db = LocalDbService.instance;
  List<MeshPeer> _discoveredPeers = [];
  List<MeshPeer> _connectedPeers = [];
  bool _isScanning = false;
  String? _localPeerId;
  String? _localDisplayName;
  Timer? _heartbeatTimer;
  Timer? _lanBroadcastTimer;

  // LAN multicast (100% offline Wi-Fi P2P & Local Lounge)
  RawDatagramSocket? _lanSocket;
  StreamSubscription<RawSocketEvent>? _lanSubscription;
  static const String _multicastGroup = '239.255.0.100';
  static const int _multicastPort = 55555;

  List<MeshPeer> get discoveredPeers => _discoveredPeers;
  List<MeshPeer> get connectedPeers => _connectedPeers;
  bool get isScanning => _isScanning;
  String? get localPeerId => _localPeerId;
  String? get localDisplayName => _localDisplayName;
  bool get isWifiReady => true;
  String get adapterStateString => 'Wi-Fi Lounge Ready';

  MeshService() {
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    final identity = await _db.getMeshIdentity();
    _localPeerId = identity['id'];
    _localDisplayName = identity['displayName'];
  }

  Future<void> setDisplayName(String name) async {
    await _db.setMeshDisplayName(name);
    _localDisplayName = name;
    notifyListeners();
  }

  // ======================== SCANNING ========================

  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    await _startLanDiscovery();
  }

  Future<void> stopScanning() async {
    _isScanning = false;
    await _stopLanDiscovery();
    notifyListeners();
  }

  // ======================== LAN MULTICAST ========================

  Future<void> _startLanDiscovery() async {
    try {
      _lanSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _multicastPort,
        reuseAddress: true,
      );
      _lanSocket!.multicastHops = 4;
      _lanSocket!.broadcastEnabled = true;

      _lanSocket!.joinMulticast(InternetAddress(_multicastGroup));

      _lanSubscription = _lanSocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _lanSocket!.receive();
        if (datagram == null) return;

        try {
          final data = utf8.decode(datagram.data);
          final json = jsonDecode(data) as Map<String, dynamic>;
          final type = json['type'] as String?;

          if (type == 'group_message' || type == 'direct_message') {
            final msgMap = json['msg'] as Map<String, dynamic>;
            final msg = MeshMessage.fromJson(msgMap);
            if (msg.senderId != _localPeerId) {
              if (type == 'direct_message' && msg.receiverId != _localPeerId) {
                return; // Not meant for us
              }
              _db.insertMeshMessage(msg);
              notifyListeners();
            }
            return;
          }

          final peerId = json['id'] as String?;
          final peerName = json['name'] as String?;
          if (peerId == null || peerName == null || peerId == _localPeerId) return;

          _upsertPeer(peerId, peerName, MeshConnectionMethod.lan, DateTime.now());
          notifyListeners();
        } catch (_) {}
      });

      _lanBroadcastTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _broadcastPresence();
      });
      _broadcastPresence();
    } catch (e) {
      debugPrint('LAN multicast failed: $e');
    }
  }

  void _broadcastPresence() {
    if (_lanSocket == null || _localPeerId == null) return;
    try {
      final payload = jsonEncode({
        'id': _localPeerId,
        'name': _localDisplayName ?? 'Chef',
        'type': 'chowgenie',
      });
      final data = utf8.encode(payload);
      _lanSocket!.send(data, InternetAddress(_multicastGroup), _multicastPort);
    } catch (_) {}
  }

  Future<void> _stopLanDiscovery() async {
    _lanBroadcastTimer?.cancel();
    _lanBroadcastTimer = null;
    await _lanSubscription?.cancel();
    _lanSubscription = null;
    _lanSocket?.close();
    _lanSocket = null;
  }

  // ======================== PEER MANAGEMENT ========================

  void _upsertPeer(String id, String name, MeshConnectionMethod method, DateTime now, {int? rssi}) {
    final idx = _discoveredPeers.indexWhere((p) => p.id == id);
    if (idx == -1) {
      _discoveredPeers.add(MeshPeer(
        id: id,
        displayName: name,
        connectionMethod: method,
        isOnline: true,
        lastSeen: now,
        rssi: rssi,
      ));
      _db.insertPeer(_discoveredPeers.last);
    } else {
      _discoveredPeers[idx] = _discoveredPeers[idx].copyWith(
        lastSeen: now,
        isOnline: true,
        rssi: rssi ?? _discoveredPeers[idx].rssi,
      );
    }
  }

  // ======================== CONNECTION ========================

  Future<void> connectToPeer(String peerId) async {
    if (_connectedPeers.any((p) => p.id == peerId)) return;

    final peer = _discoveredPeers.firstWhere((p) => p.id == peerId);
    _connectedPeers.add(peer);

    await _db.insertPeer(peer);
    notifyListeners();
  }

  Future<void> disconnectPeer(String peerId) async {
    _connectedPeers.removeWhere((p) => p.id == peerId);
    notifyListeners();
  }

  // ======================== MESSAGING ========================

  Future<void> sendMessage({
    required String receiverId,
    required String content,
    MeshMessageType type = MeshMessageType.text,
    String? recipeJson,
    String? attachmentPath,
  }) async {
    if (_localPeerId == null) return;

    final msg = MeshMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      senderId: _localPeerId!,
      senderName: _localDisplayName ?? 'Me',
      receiverId: receiverId,
      messageType: type,
      content: content,
      recipeJson: recipeJson,
      attachmentPath: attachmentPath,
      timestamp: DateTime.now(),
    );

    await _db.insertMeshMessage(msg);
    
    try {
      final payload = jsonEncode({
        'type': 'direct_message',
        'msg': msg.toJson(),
      });
      final data = utf8.encode(payload);
      _lanSocket?.send(data, InternetAddress(_multicastGroup), _multicastPort);
    } catch (e) {
      debugPrint('Failed to send multicast direct message: $e');
    }

    Future.delayed(const Duration(seconds: 1), () async {
      await _db.markMessageDelivered(msg.id);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String content,
    MeshMessageType type = MeshMessageType.text,
    String? recipeJson,
  }) async {
    if (_localPeerId == null) return;

    final msg = MeshMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      senderId: _localPeerId!,
      senderName: _localDisplayName ?? 'Me',
      groupId: groupId,
      messageType: type,
      content: content,
      recipeJson: recipeJson,
      timestamp: DateTime.now(),
    );

    await _db.insertMeshMessage(msg);

    try {
      final payload = jsonEncode({
        'type': 'group_message',
        'msg': msg.toJson(),
      });
      final data = utf8.encode(payload);
      _lanSocket?.send(data, InternetAddress(_multicastGroup), _multicastPort);
    } catch (e) {
      debugPrint('Failed to send multicast group message: $e');
    }

    notifyListeners();
  }

  Future<List<MeshMessage>> getConversation(String peerId) async {
    return await _db.getMeshMessages(peerId);
  }

  Future<List<MeshMessage>> getGroupConversation(String groupId) async {
    return await _db.getGroupMessages(groupId);
  }

  // ======================== LIFECYCLE ========================

  void startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _broadcastPresence();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  @override
  void dispose() {
    _stopLanDiscovery();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
