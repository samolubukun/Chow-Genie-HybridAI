import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/mesh_view_model.dart';
import '../../models/mesh_peer.dart';
import 'mesh_chat_screen.dart';
import 'qr_share_screen.dart';

class MeshHomeScreen extends StatefulWidget {
  const MeshHomeScreen({super.key});

  @override
  State<MeshHomeScreen> createState() => _MeshHomeScreenState();
}

class _MeshHomeScreenState extends State<MeshHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<MeshViewModel>();
      vm.startHeartbeat();
      vm.loadHistoricalPeers();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  IconData _connectionIcon(MeshConnectionMethod method) {
    switch (method) {
      case MeshConnectionMethod.ble:
        return Icons.wifi;
      case MeshConnectionMethod.wifiDirect:
        return Icons.wifi;
      case MeshConnectionMethod.lan:
        return Icons.lan;
      case MeshConnectionMethod.qr:
        return Icons.qr_code;
      case MeshConnectionMethod.nfc:
        return Icons.nfc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<MeshViewModel>(
        builder: (context, vm, _) {
          final recentPeers = vm.historicalPeers.where((hp) {
            final inConnected = vm.connectedPeers.any((cp) => cp.id == hp.id);
            final inDiscovered = vm.discoveredPeers.any((dp) => dp.id == hp.id);
            return !inConnected && !inDiscovered;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.scaffold,
                surfaceTintColor: Colors.transparent,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.hub, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('Mesh', style: AppTextStyles.heading2),
                  ],
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QrShareScreen()),
                    ),
                    tooltip: 'Share via QR',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: vm.isScanning ? null : () => vm.startScanning(),
                    tooltip: 'Refresh scan',
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildMyIdentityCard(context, vm, colors)),
              SliverToBoxAdapter(child: _buildScanSection(context, vm, colors)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Groups', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                          child: const Icon(Icons.groups, color: AppColors.brand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Local Lounge', style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Multicast room for anyone on this Wi-Fi network', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chat_bubble_outline, color: AppColors.brand, size: 20),
                          onPressed: () async {
                            await vm.openGroupConversation('local_lounge');
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MeshChatScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (vm.connectedPeers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Connected', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPeerCard(context, vm.connectedPeers[index], vm, colors),
                    childCount: vm.connectedPeers.length,
                  ),
                ),
              ],
              if (recentPeers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Recent Chats', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final peer = recentPeers[index];
                      return _buildPeerCard(context, peer.copyWith(isOnline: false), vm, colors);
                    },
                    childCount: recentPeers.length,
                  ),
                ),
              ],
              if (vm.discoveredPeers.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Text('Nearby Devices', style: AppTextStyles.heading3.copyWith(color: colors.textPrimary)),
                        const Spacer(),
                        if (vm.isScanning)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPeerCard(context, vm.discoveredPeers[index], vm, colors, isDiscovered: true),
                  childCount: vm.discoveredPeers.length,
                ),
              ),
              if (vm.discoveredPeers.isEmpty && !vm.isScanning)
                SliverToBoxAdapter(child: _buildEmptyScanState(context, vm, colors)),
              SliverToBoxAdapter(child: const SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMyIdentityCard(BuildContext context, MeshViewModel vm, AppColorSet colors) {
    final name = vm.localDisplayName ?? 'Chef';
    final peerId = 'user_${DateTime.now().microsecondsSinceEpoch}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brand,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'ID: ${peerId.length > 16 ? '${peerId.substring(0, 16)}...' : peerId}',
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Wi-Fi Local Lounge Active',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: AppColors.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrShareScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection(BuildContext context, MeshViewModel vm, AppColorSet colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: vm.isScanning ? () => vm.stopScanning() : () => vm.startScanning(),
          icon: Icon(
            vm.isScanning ? Icons.stop : Icons.wifi_find,
            size: 20,
          ),
          label: Text(vm.isScanning ? 'Stop Scanning' : 'Start Scanning'),
          style: OutlinedButton.styleFrom(
            foregroundColor: vm.isScanning ? AppColors.error : colors.textPrimary,
            side: BorderSide(color: vm.isScanning ? AppColors.error : colors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildPeerCard(BuildContext context, MeshPeer peer, MeshViewModel vm, AppColorSet colors, {bool isDiscovered = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isDiscovered
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.success.withValues(alpha: 0.2),
              child: Text(
                peer.displayName.isNotEmpty ? peer.displayName[0].toUpperCase() : '?',
                style: AppTextStyles.heading3.copyWith(
                  color: isDiscovered ? AppColors.accent : AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.displayName, style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_connectionIcon(peer.connectionMethod), size: 12, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        peer.connectionMethod.name,
                        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                      ),
                      if (peer.rssi != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.signal_cellular_alt, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          '${peer.rssi} dBm',
                          style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: peer.isOnline ? AppColors.success : colors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            if (isDiscovered) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => vm.connectToPeer(peer.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Connect', style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: AppColors.brand, size: 20),
                onPressed: () async {
                  await vm.openConversation(peer.id);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MeshChatScreen()),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanState(BuildContext context, MeshViewModel vm, AppColorSet colors) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering, size: 48, color: AppColors.brand),
          ),
          const SizedBox(height: 20),
          Text('No devices found', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Tap "Start Scanning" to discover nearby peers',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
