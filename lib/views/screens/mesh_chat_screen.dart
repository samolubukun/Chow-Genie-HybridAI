import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'dart:convert';
import '../../models/recipe.dart';
import '../../services/local_db_service.dart';
import '../../viewmodels/recipe_view_model.dart';
import '../../viewmodels/mesh_view_model.dart';
import '../../models/mesh_message.dart';
import '../../services/recipe_export_service.dart';

class MeshChatScreen extends StatefulWidget {
  const MeshChatScreen({super.key});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) context.read<MeshViewModel>().refreshMessages();
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.scaffold,
      body: Consumer<MeshViewModel>(
        builder: (context, vm, _) {
          final isGroup = vm.activeGroupId != null;
          final peer = vm.activePeerId != null
              ? vm.connectedPeers.where((p) => p.id == vm.activePeerId).firstOrNull
              : null;
          final peerName = isGroup ? 'Local Lounge (Wi-Fi)' : (peer?.displayName ?? vm.activePeerId ?? 'Chat');
          final isOnline = isGroup ? true : (peer?.isOnline ?? false);

          return Column(
            children: [
              _buildAppBar(context, peerName, isOnline, colors),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => vm.refreshMessages(),
                  color: AppColors.brand,
                  child: vm.messages.isEmpty
                      ? _buildEmptyChat(colors)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: vm.messages.length,
                          itemBuilder: (context, index) {
                            final msg = vm.messages[index];
                            return _buildMessageBubble(context, msg, vm, colors);
                          },
                        ),
                ),
              ),
              if (_isTyping) _buildTypingIndicator(colors),
              _buildInputBar(context, vm, colors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String name, bool isOnline, AppColorSet colors) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: isOnline ? AppColors.success : colors.surfaceAlt,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: AppTextStyles.bodySmall.copyWith(color: isOnline ? AppColors.success : colors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, MeshMessage msg, MeshViewModel vm, AppColorSet colors) {
    final isSent = msg.senderId == vm.localPeerId;
    final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg.messageType == MeshMessageType.recipe && msg.recipeJson != null)
            _buildRecipeCard(context, msg, colors, isSent)
          else if (msg.messageType == MeshMessageType.photo && msg.attachmentPath != null)
            _buildPhotoCard(context, msg, colors, isSent)
          else
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSent ? AppColors.brand : colors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isSent ? 20 : 4),
                  bottomRight: Radius.circular(isSent ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSent && msg.groupId != null) ...[
                    Text(
                      msg.senderName,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    msg.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSent ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time, style: AppTextStyles.labelSmall.copyWith(
                        color: isSent ? Colors.white.withValues(alpha: 0.7) : colors.textTertiary,
                        fontSize: 10,
                      )),
                      if (isSent) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.isRead ? AppColors.info : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, MeshMessage msg, AppColorSet colors, bool isSent) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSent ? AppColors.brand.withValues(alpha: 0.9) : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSent ? AppColors.brand : AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text('Recipe', style: AppTextStyles.labelLarge.copyWith(
                color: isSent ? Colors.white : AppColors.accent,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSent ? Colors.white : colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (msg.recipeJson != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tap to import this recipe',
              style: AppTextStyles.bodySmall.copyWith(
                color: isSent ? Colors.white.withValues(alpha: 0.7) : colors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final recipe = RecipeExportService().parseQrData(msg.recipeJson!);
              if (recipe != null) {
                final toSave = recipe.copyWith(isUserGenerated: true);
                await LocalDbService.instance.insertRecipe(toSave);
                if (context.mounted) {
                  context.read<RecipeViewModel>().loadRecipes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Imported recipe: ${recipe.title}'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSent ? Colors.white.withValues(alpha: 0.2) : AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Import Recipe', style: AppTextStyles.labelSmall.copyWith(
                color: isSent ? Colors.white : Colors.white,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, MeshMessage msg, AppColorSet colors, bool isSent) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(Icons.image, color: colors.textTertiary, size: 48),
            ),
          ),
          if (msg.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(msg.content, style: AppTextStyles.bodySmall.copyWith(color: colors.textPrimary)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(AppColorSet colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          Text('No messages yet', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Send a message to start chatting',
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(AppColorSet colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
          ),
          const SizedBox(width: 8),
          Text('typing...', style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, MeshViewModel vm, AppColorSet colors) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _sendRecipeAttachment(context, vm, colors),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.attach_file, color: AppColors.brand, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _msgController,
                style: TextStyle(color: colors.textPrimary),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: colors.textTertiary),
                ),
                onChanged: (_) => setState(() => _isTyping = true),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (_msgController.text.trim().isNotEmpty) {
                vm.sendMessage(_msgController.text.trim());
                _msgController.clear();
                setState(() => _isTyping = false);
                _scrollToBottom();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }



  void _sendRecipeAttachment(BuildContext context, MeshViewModel vm, AppColorSet colors) {
    final searchCtrl = TextEditingController();
    List<Recipe> recipesList = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomSheetState) {
          // Inner helper to load recipes
          Future<void> loadInitial() async {
            final list = await LocalDbService.instance.getAllRecipes(limit: 20);
            if (ctx.mounted) {
              setBottomSheetState(() {
                recipesList = list;
                isLoading = false;
              });
            }
          }

          Future<void> doSearch(String query) async {
            setBottomSheetState(() {
              isLoading = true;
            });
            final list = query.trim().isEmpty
                ? await LocalDbService.instance.getAllRecipes(limit: 20)
                : await LocalDbService.instance.searchRecipes(query);
            if (ctx.mounted) {
              setBottomSheetState(() {
                recipesList = list;
                isLoading = false;
              });
            }
          }

          if (recipesList.isEmpty && isLoading) {
            loadInitial();
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Send a Recipe', style: AppTextStyles.heading2.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    onChanged: doSearch,
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                      filled: true,
                      fillColor: colors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                        : recipesList.isEmpty
                            ? Center(
                                child: Text(
                                  'No recipes found',
                                  style: AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
                                ),
                              )
                            : ListView.builder(
                                itemCount: recipesList.length,
                                itemBuilder: (context, index) {
                                  final recipe = recipesList[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: colors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.restaurant, color: AppColors.brand, size: 20),
                                    ),
                                    title: Text(
                                      recipe.title,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${recipe.ingredients.length} ingredients • ${recipe.cookingTimeMinutes ?? 30} mins',
                                      style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                                    ),
                                    trailing: const Icon(Icons.send, color: AppColors.brand, size: 20),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      
                                      // Build correct QR/P2P compatible JSON format
                                      final recipeMap = recipe.toJson();
                                      recipeMap['ingredients'] = jsonEncode(recipe.ingredients);
                                      recipeMap['directions'] = jsonEncode(recipe.directions);
                                      recipeMap['tags'] = jsonEncode(recipe.tags);
                                      recipeMap['dietaryTags'] = jsonEncode(recipe.dietaryTags ?? []);

                                      final sharedPayload = {
                                        'type': 'chowgenie_recipe',
                                        'version': 2,
                                        'recipe': recipeMap,
                                      };

                                      vm.sendMessage(
                                        recipe.title,
                                        recipeJson: jsonEncode(sharedPayload),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
