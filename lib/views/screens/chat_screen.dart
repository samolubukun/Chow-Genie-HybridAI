import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../../viewmodels/chat_view_model.dart';
import '../../services/model_manager.dart';
import '../../widgets/cooking_timer_widget.dart';
import '../../widgets/hybrid_ai_badge.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollBtn = false;
  int _lastMessageCount = 0;
  String? _lastSessionId;
  final List<String> _pendingImagePaths = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final show = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 200;
      if (show != _showScrollBtn) setState(() => _showScrollBtn = show);
    });
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isReady = context.watch<ModelManager>().isReady;
    final vm = context.watch<ChatViewModel>();
    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isReady ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('AI Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            if (vm.currentSession != null)
              Text(
                vm.currentSession!.title,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          Consumer<ChatViewModel>(builder: (context, vm, _) {
            if (!vm.hasMessages) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear Conversation',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: colors.surface,
                    content: const Text('Clear entire conversation?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () { Navigator.pop(ctx); vm.clearConversation(); },
                        child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.brand, size: 24),
                    const SizedBox(width: 12),
                    Text('ChowGenie Chat', style: AppTextStyles.heading2),
                  ],
                ),
              ),
              Divider(color: colors.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    vm.createNewSession();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: colors.textOnBrand, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: AppTextStyles.labelLarge.copyWith(color: colors.textOnBrand),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CONVERSATIONS',
                    style: AppTextStyles.labelSmall.copyWith(color: colors.textTertiary),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: vm.sessions.length,
                  itemBuilder: (ctx, idx) {
                    final session = vm.sessions[idx];
                    final isSelected = vm.currentSession?.id == session.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.brand.withValues(alpha: 0.2) : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          dense: true,
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color: isSelected ? AppColors.brand : colors.textSecondary,
                            size: 18,
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isSelected
                                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.brand)
                                : AppTextStyles.bodyMedium,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            vm.selectSession(session.id);
                          },
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, size: 16, color: colors.textTertiary),
                            onPressed: () {
                              _confirmDeleteSession(context, vm, session);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<ChatViewModel>(builder: (context, vm, _) {
        final currentSessionId = vm.currentSession?.id ?? 'no_session';
        final sessionChanged = currentSessionId != _lastSessionId;
        final countChanged = vm.messages.length != _lastMessageCount;

        if (sessionChanged) {
          _pendingImagePaths.clear();
          _lastSessionId = currentSessionId;
          _lastMessageCount = vm.messages.length;
          if (vm.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
          }
        } else if (countChanged) {
          final wasNearBottom = !_showScrollBtn;
          final countIncreased = vm.messages.length > _lastMessageCount;
          _lastMessageCount = vm.messages.length;
          if (countIncreased && wasNearBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
          }
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: vm.messages.isEmpty
                      ? _emptyState(vm, colors)
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          itemCount: vm.messages.length,
                          itemBuilder: (context, i) => _messageBubble(vm.messages[i], i, vm.messages, colors),
                        ),
                ),
                _buildInputBar(vm, colors),
              ],
            ),
            if (_showScrollBtn)
              Positioned(
                right: 20,
                bottom: 80,
                child: GestureDetector(
                  onTap: () => _scrollToBottom(animate: true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.keyboard_arrow_down, color: colors.textPrimary, size: 20),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _emptyState(ChatViewModel vm, AppColorSet colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.25),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.chat_bubble_rounded, color: colors.textOnBrand, size: 32),
            ),
            const SizedBox(height: 24),
            Text('Ask AI About Food', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text(
              'Chat with AI about nutrition, recipes, diet advice, or analyze food photos. Add photos using the + button.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg, int index, List<ChatMessage> all, AppColorSet colors) {
    final isUser = msg.type == MessageType.user;
    final isFirst = index == 0 || all[index - 1].type != msg.type;
    final showTime = isFirst || index == all.length - 1;

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 4 : 2),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && isFirst)
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_awesome, size: 16, color: colors.textOnBrand),
            ),
          if (!isUser && isFirst) const SizedBox(width: 8),
          if (!isUser && !isFirst) const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.brand.withValues(alpha: 0.15) : colors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : (isFirst ? 4 : 18)),
                      bottomRight: Radius.circular(isUser ? (isFirst ? 4 : 18) : 18),
                    ),
                    border: Border.all(
                      color: isUser ? AppColors.brand.withValues(alpha: 0.2) : colors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.hasImage) ...[
                        _buildMessageMediaGallery(msg, colors),
                        const SizedBox(height: 10),
                      ],
                      if (msg.content.isNotEmpty)
                        isUser
                            ? Text(msg.content, style: AppTextStyles.bodyLarge)
                            : MarkdownBody(
                                data: msg.content,
                                styleSheet: MarkdownStyleSheet(
                                  p: AppTextStyles.bodyLarge,
                                  a: const TextStyle(color: AppColors.brand),
                                  code: const TextStyle(color: AppColors.accent, fontSize: 13),
                                  codeblockDecoration: BoxDecoration(
                                    color: colors.surfaceAlt, borderRadius: BorderRadius.circular(8),
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  h1: AppTextStyles.heading1,
                                  h2: AppTextStyles.heading2,
                                  h3: AppTextStyles.heading3,
                                  listBullet: AppTextStyles.bodyLarge,
                                  strong: AppTextStyles.labelLarge,
                                ),
                              ),
                      if (!isUser && msg.content.contains('⏱️ Started a')) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            final match = RegExp(r'(\d+)\s*minute').firstMatch(msg.content);
                            final mins = int.tryParse(match?.group(1) ?? '5') ?? 5;
                            CookingTimerBottomSheet.show(context, initialMinutes: mins, label: 'Kitchen Agent Timer');
                          },
                          icon: const Icon(Icons.timer_outlined, size: 16, color: AppColors.brand),
                          label: const Text('Open Active Timer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.brand),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showTime)
                  Padding(
                    padding: EdgeInsets.only(top: 4, left: isUser ? 0 : 0, right: isUser ? 4 : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(msg.timestamp),
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                        if (!isUser) ...[
                          const SizedBox(width: 8),
                          HybridAiBadge(
                            isOnDevice: msg.isOnDevice ?? false,
                            modelName: msg.modelName ?? 'Gemini Flash',
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser && isFirst) const SizedBox(width: 8),
          if (isUser && isFirst)
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person, size: 18, color: colors.textSecondary),
            ),
          if (isUser && !isFirst) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMessageMediaGallery(ChatMessage msg, AppColorSet colors) {
    final paths = msg.allImagePaths;
    if (paths.isEmpty) return const SizedBox.shrink();
    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(paths.first),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 100,
            color: colors.surfaceAlt,
            child: Center(child: Icon(Icons.broken_image, color: colors.textTertiary)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(paths[idx]),
            height: 110,
            width: 110,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 110,
              width: 110,
              color: colors.surfaceAlt,
              child: Center(child: Icon(Icons.broken_image, color: colors.textTertiary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ChatViewModel vm, AppColorSet colors) {
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImages = _pendingImagePaths.isNotEmpty;
    final canSend = (hasText || hasImages) && !vm.isGenerating;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ATTACHMENT TRAY / STAGING CAROUSEL
            if (_pendingImagePaths.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.collections_rounded, size: 14, color: AppColors.brand),
                        const SizedBox(width: 6),
                        Text(
                          '${_pendingImagePaths.length} ${_pendingImagePaths.length == 1 ? "Photo" : "Photos"} attached',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _pendingImagePaths.clear()),
                          child: Text(
                            'Clear all',
                            style: TextStyle(fontSize: 11, color: colors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingImagePaths.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == _pendingImagePaths.length) {
                            return GestureDetector(
                              onTap: vm.isGenerating ? null : _showImageSourceSheet,
                              child: Container(
                                width: 68,
                                height: 74,
                                decoration: BoxDecoration(
                                  color: colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.border,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 20, color: colors.textSecondary),
                                    const SizedBox(height: 4),
                                    Text('Add', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          }

                          final path = _pendingImagePaths[index];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 68,
                                height: 74,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.35), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () => setState(() => _pendingImagePaths.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: colors.cardElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colors.border),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.close_rounded, size: 12, color: colors.textPrimary),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                GestureDetector(
                  onTap: vm.isGenerating ? null : _showImageSourceSheet,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasImages
                          ? AppColors.brand.withValues(alpha: 0.15)
                          : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: hasImages ? AppColors.brand : colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: vm.isGenerating
                          ? 'AI is thinking...'
                          : (hasImages
                              ? 'Ask about ${_pendingImagePaths.length == 1 ? "this photo" : "these ${_pendingImagePaths.length} photos"}...'
                              : 'Ask about food...'),
                      filled: true,
                      fillColor: colors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(vm),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: canSend ? () => _sendMessage(vm) : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: canSend ? const LinearGradient(colors: AppColors.brandGradient) : null,
                      color: !canSend ? colors.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: vm.isGenerating
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textOnBrand,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend ? colors.textOnBrand : colors.textTertiary,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatViewModel vm) {
    final text = _controller.text.trim();
    final images = List<String>.from(_pendingImagePaths);
    if (text.isEmpty && images.isEmpty) return;

    _controller.clear();
    setState(() => _pendingImagePaths.clear());
    _scrollToBottom(animate: true);

    if (images.isNotEmpty) {
      vm.sendMultimodalMessage(
        text.isEmpty
            ? 'Analyze ${images.length == 1 ? "this food photo" : "these food photos"} and provide recipe and nutrition insights.'
            : text,
        images.first,
        imagePaths: images,
      );
    } else {
      vm.sendMessage(text);
    }
  }

  void _showImageSourceSheet() {
    final vm = context.read<ChatViewModel>();
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Attach Photos', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _sourceBtn(
                      colors: colors,
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final path = await vm.takePhoto();
                        if (path != null) {
                          setState(() {
                            _pendingImagePaths.add(path);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceBtn(
                      colors: colors,
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final paths = await vm.pickMultipleImages();
                        if (paths.isNotEmpty) {
                          setState(() {
                            _pendingImagePaths.addAll(paths);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceBtn({required AppColorSet colors, required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.textPrimary, size: 28),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSession(BuildContext context, ChatViewModel vm, ChatSession session) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        content: Text('Delete conversation "${session.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.deleteSession(session.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
