import 'package:flutter/foundation.dart';
import '../models/mesh_peer.dart';
import '../models/mesh_message.dart';
import '../services/mesh_service.dart';
import '../services/local_db_service.dart';

class MeshViewModel extends ChangeNotifier {
  final MeshService _meshService;
  final LocalDbService _db = LocalDbService.instance;
  List<MeshMessage> _messages = [];
  List<MeshPeer> _historicalPeers = [];
  String? _activePeerId;
  String? _activeGroupId;
  bool _isLoading = false;

  MeshViewModel(this._meshService);

  List<MeshPeer> get discoveredPeers => _meshService.discoveredPeers;
  List<MeshPeer> get connectedPeers => _meshService.connectedPeers;
  List<MeshPeer> get historicalPeers => _historicalPeers;
  bool get isScanning => _meshService.isScanning;
  String? get localDisplayName => _meshService.localDisplayName;
  String? get localPeerId => _meshService.localPeerId;
  String get adapterStateString => _meshService.adapterStateString;
  bool get isBluetoothReady => true;
  bool get isWifiReady => _meshService.isWifiReady;
  List<MeshMessage> get messages => _messages;
  String? get activePeerId => _activePeerId;
  String? get activeGroupId => _activeGroupId;

  Future<void> loadHistoricalPeers() async {
    _historicalPeers = await _db.getPeers();
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    await _meshService.setDisplayName(name);
    notifyListeners();
  }

  Future<void> startScanning() async {
    await _meshService.startScanning();
    notifyListeners();
  }

  Future<void> stopScanning() async {
    await _meshService.stopScanning();
    notifyListeners();
  }

  Future<void> connectToPeer(String peerId) async {
    await _meshService.connectToPeer(peerId);
    notifyListeners();
  }

  Future<void> disconnectPeer(String peerId) async {
    await _meshService.disconnectPeer(peerId);
    notifyListeners();
  }

  Future<void> openConversation(String peerId) async {
    _activePeerId = peerId;
    _activeGroupId = null;
    _messages = await _meshService.getConversation(peerId);
    notifyListeners();
  }

  Future<void> openGroupConversation(String groupId) async {
    _activePeerId = null;
    _activeGroupId = groupId;
    _messages = await _meshService.getGroupConversation(groupId);
    notifyListeners();
  }

  Future<void> sendMessage(String content, {String? recipeJson}) async {
    if (_activePeerId != null) {
      await _meshService.sendMessage(
        receiverId: _activePeerId!,
        content: content,
        type: recipeJson != null ? MeshMessageType.recipe : MeshMessageType.text,
        recipeJson: recipeJson,
      );
      _messages = await _meshService.getConversation(_activePeerId!);
    } else if (_activeGroupId != null) {
      await _meshService.sendGroupMessage(
        groupId: _activeGroupId!,
        content: content,
        type: recipeJson != null ? MeshMessageType.recipe : MeshMessageType.text,
        recipeJson: recipeJson,
      );
      _messages = await _meshService.getGroupConversation(_activeGroupId!);
    }
    notifyListeners();
  }

  Future<void> refreshMessages() async {
    if (_activePeerId != null) {
      _messages = await _meshService.getConversation(_activePeerId!);
    } else if (_activeGroupId != null) {
      _messages = await _meshService.getGroupConversation(_activeGroupId!);
    }
    notifyListeners();
  }

  void startHeartbeat() => _meshService.startHeartbeat();
  void stopHeartbeat() => _meshService.stopHeartbeat();
}
