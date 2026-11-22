import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/voice_service.dart';
import '../../services/kitchen_agent_service.dart';
import '../../widgets/cooking_timer_widget.dart';

class VoiceCookingScreen extends StatefulWidget {
  final List<String> steps;
  final String recipeTitle;
  final List<String>? ingredients;

  const VoiceCookingScreen({
    super.key,
    this.steps = const [
      'Gather all ingredients and equipment',
      'Wash and chop vegetables',
      'Preheat the pan or oven',
      'Cook according to recipe instructions',
      'Plate and serve',
    ],
    this.recipeTitle = 'Cooking Session',
    this.ingredients,
  });

  @override
  State<VoiceCookingScreen> createState() => _VoiceCookingScreenState();
}

class _VoiceCookingScreenState extends State<VoiceCookingScreen>
    with WidgetsBindingObserver {
  late CookingVoiceController _controller;
  bool _userMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final voice = context.read<VoiceService>();
    _controller = CookingVoiceController(voice, widget.steps);
    _controller.startCookingMode();
    _startListeningForCommands();
  }

  void _startListeningForCommands() {
    final voice = context.read<VoiceService>();
    voice.addListener(_onVoiceChange);
  }

  void _onVoiceChange() {
    final voice = context.read<VoiceService>();

    // Auto-resume listening if idle, active, not muted, and not currently speaking/listening
    if (voice.state == VoiceState.idle &&
        _controller.isActive &&
        !_userMuted &&
        !voice.isSpeaking &&
        !voice.isListening) {
      Future.microtask(() {
        if (mounted && voice.state == VoiceState.idle && !_userMuted) {
          voice.startListening();
        }
      });
      return;
    }

    final text = voice.recognizedText.toLowerCase().trim();
    if (text.isEmpty) return;

    bool matched = false;

    if (_matchesCommand(text, 'next step') || _matchesCommand(text, 'next') || _matchesCommand(text, 'go forward')) {
      matched = true;
      voice.clearRecognizedText();
      _controller.nextStep();
    } else if (_matchesCommand(text, 'repeat') || _matchesCommand(text, 'repeat step') || _matchesCommand(text, 'say that again')) {
      matched = true;
      voice.clearRecognizedText();
      _controller.repeatStep();
    } else if (_matchesCommand(text, 'go back') || _matchesCommand(text, 'previous') || _matchesCommand(text, 'previous step') || _matchesCommand(text, 'back')) {
      matched = true;
      voice.clearRecognizedText();
      _controller.previousStep();
    } else if (text.length > 3 && !_isProcessingAgentCommand) {
      _handleVoiceAgentCommand(text, voice);
    }

    if (matched) {
      setState(() {});
    }
  }

  bool _isProcessingAgentCommand = false;

  Future<void> _handleVoiceAgentCommand(String text, VoiceService voice) async {
    if (_isProcessingAgentCommand) return;
    setState(() => _isProcessingAgentCommand = true);
    voice.clearRecognizedText();

    final response = await KitchenAgentService.instance.processCommand(
      text,
      recipeTitle: widget.recipeTitle,
      ingredients: widget.ingredients,
      directions: widget.steps,
    );

    if (mounted) {
      if (response.actionType == AgentActionType.timerStarted) {
        final mins = (response.actionData['minutes'] as int?) ?? 5;
        final label = response.actionData['label']?.toString() ?? 'Step Timer';
        CookingTimerBottomSheet.show(context, initialMinutes: mins, label: label);
      } else if (response.actionType == AgentActionType.shoppingAdded ||
                 response.actionType == AgentActionType.pantryAdded ||
                 response.actionType == AgentActionType.mealScheduled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(response.displayText)),
              ],
            ),
            backgroundColor: AppColors.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      await voice.speak(response.spokenText);
      setState(() => _isProcessingAgentCommand = false);
    }
  }

  bool _matchesCommand(String text, String command) {
    return text.contains(command);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final voice = context.read<VoiceService>();
    voice.removeListener(_onVoiceChange);
    _controller.stopCookingMode();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stopCookingMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final voice = context.watch<VoiceService>();
    final totalSteps = widget.steps.length;
    final stepNum = _controller.currentStep + 1;
    final progress = (stepNum / totalSteps).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Text(
          widget.recipeTitle,
          style: AppTextStyles.heading3.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _userMuted
                  ? Icons.mic_off
                  : (voice.isListening ? Icons.mic : Icons.mic_none),
              color: _userMuted
                  ? colors.textTertiary
                  : (voice.isListening ? AppColors.brand : colors.textSecondary),
            ),
            onPressed: () {
              setState(() {
                _userMuted = !_userMuted;
                if (_userMuted) {
                  voice.stopListening();
                } else {
                  voice.startListening();
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step $stepNum of $totalSteps',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.brand),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.labelLarge.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colors.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step indicator circles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final current = _controller.currentStep;
                  final isActive = i == current;
                  final isDone = i < current;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: isActive ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.brand
                            : isDone
                                ? AppColors.brand.withValues(alpha: 0.4)
                                : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 32),

            // Current step card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brand.withValues(alpha: 0.08),
                        AppColors.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_outlined, color: AppColors.brand, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'STEP $stepNum',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.brand,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _controller.currentStepText,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displaySmall.copyWith(
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _navButton(
                      colors: colors,
                      icon: Icons.skip_previous_rounded,
                      label: 'Previous',
                      onTap: _controller.currentStep > 0
                          ? () {
                              _controller.previousStep();
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _navButton(
                      colors: colors,
                      icon: Icons.replay_rounded,
                      label: 'Repeat',
                      onTap: () {
                        _controller.repeatStep();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _navButton(
                      colors: colors,
                      icon: Icons.skip_next_rounded,
                      label: 'Next',
                      onTap: !_controller.isLastStep
                          ? () {
                              _controller.nextStep();
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Voice status indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _userMuted
                          ? colors.textTertiary
                          : voice.isListening
                              ? AppColors.success
                              : voice.isSpeaking
                                  ? AppColors.brand
                                  : colors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _userMuted
                        ? 'Muted (Voice control disabled)'
                        : voice.isListening
                            ? 'Listening...'
                            : voice.isSpeaking
                                ? 'Speaking...'
                                : 'Tap mic or use buttons',
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  if (voice.isListening && !_userMuted) ...[
                    const SizedBox(width: 8),
                    Text(
                      '"${voice.recognizedText}"',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.brand,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _navButton({
    required AppColorSet colors,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap != null ? colors.cardElevated : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap != null
                ? AppColors.brand.withValues(alpha: 0.3)
                : colors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: onTap != null ? AppColors.brand : colors.textTertiary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: onTap != null ? colors.textPrimary : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
