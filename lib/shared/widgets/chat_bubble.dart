import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isLoading;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isLoading = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;
  late Animation<int> _dotsAnim;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dotsAnim = IntTween(begin: 1, end: 3).animate(_dotsController);
    if (widget.isLoading) _dotsController.repeat();
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading) {
      _dotsController.repeat();
    } else {
      _dotsController.stop();
    }
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isUser ? AppColors.primary : AppColors.bgCard,
            borderRadius: BorderRadius.only(
              topLeft:
                  const Radius.circular(AppSpacing.radiusMdD),
              topRight:
                  const Radius.circular(AppSpacing.radiusMdD),
              bottomLeft: Radius.circular(
                widget.isUser ? AppSpacing.radiusMdD : AppSpacing.xs,
              ),
              bottomRight: Radius.circular(
                widget.isUser ? AppSpacing.xs : AppSpacing.radiusMdD,
              ),
            ),
            border: widget.isUser
                ? null
                : Border.all(
                    color: AppColors.border,
                    width: AppSpacing.borderThin,
                  ),
          ),
          child: widget.isLoading
              ? AnimatedBuilder(
                  animation: _dotsAnim,
                  builder: (_, __) => Text(
                    '•' * _dotsAnim.value,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : Text(
                  widget.text,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                ),
        ),
      ),
    );
  }
}
