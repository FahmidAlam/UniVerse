import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/auth_responsive_shell.dart';
import 'package:universe/features/auth/widgets/onboard_slide.dart';
import 'package:universe/features/auth/widgets/routine_convergence_showcase.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/core/theme/app_motion.dart';

// PHASE 3: The approved story shares its stage with the illustrative showcase.
class OnboardingScreen extends StatefulWidget {
  final AuthController authController;
  const OnboardingScreen({super.key, required this.authController});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  int _previousPage = 0;

  static const _stageBadges = [
    'STAGE 01 · AUTOMATED ENGINE',
    'STAGE 02 · PERSONALIZED LENS',
    'STAGE 03 · CONNECTED CAMPUS',
  ];

  static const _stageAccents = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
  ];

  static const _stageIcons = [
    Icons.auto_awesome_mosaic_outlined,
    Icons.schedule_outlined,
    Icons.hub_outlined,
  ];

  static const _descriptions = [
    'UniVerse connects departmental course distributions, faculty allocations, room pools and scheduling rules through an automated scheduling engine to assemble an organized university routine.',
    'Published routines adapt to students with upcoming classes, weekly schedules, and room guidance, and to teachers with teaching slots, rooms and daily planning.',
    'Your routine connects faculty-posted class cancellations and announcements, schedule-derived room and teacher lookup, and semester learning resources.',
  ];

  Future<void> _finish() async {
    await widget.authController.markOnboardingSeen();
    if (mounted) context.go(RouteNames.login);
  }

  void _select(int stage) {
    final target = stage.clamp(0, 2);
    if (target == _currentPage) return;
    setState(() {
      _previousPage = _currentPage;
      _currentPage = target;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
          final compact = bounds.maxWidth < 768;
          final forward = _currentPage >= _previousPage;
          final accent = _stageAccents[_currentPage];
          final reduced = AppMotion.reduced(context);

          return AuthResponsiveShell(
              stage: _currentPage,
              onStageChanged: _select,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 100) {
                    _select(
                        (_currentPage + (velocity < 0 ? 1 : -1)).clamp(0, 2));
                  }
                },
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.radiusFull,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _stageIcons[_currentPage],
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '0${_currentPage + 1} / 03',
                                style: AppTextStyles.numeric.copyWith(
                                  color: accent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _stageBadges[_currentPage],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      if (reduced)
                        OnboardSlide(
                          key: ValueKey(_currentPage),
                          stage: _currentPage,
                          showVisual: compact,
                          icon: _stageIcons[_currentPage],
                          iconColor: accent,
                          title:
                              RoutineConvergenceShowcase.titles[_currentPage],
                          description: _descriptions[_currentPage],
                        )
                      else
                        AnimatedSize(
                          duration: AppMotion.medium,
                          curve: AppMotion.magnetic,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: AppMotion.magnetic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                            transitionBuilder: (child, animation) {
                              final isIncoming =
                                  child.key == ValueKey<int>(_currentPage);
                              final slideBegin = isIncoming
                                  ? Offset(forward ? 0.06 : -0.06, 0.015)
                                  : Offset(forward ? -0.04 : 0.04, -0.01);
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.1, 1.0,
                                      curve: Curves.easeOut),
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: slideBegin,
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: AppMotion.magnetic,
                                  )),
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: isIncoming ? 0.985 : 0.99,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: OnboardSlide(
                              key: ValueKey<int>(_currentPage),
                              stage: _currentPage,
                              showVisual: compact,
                              icon: _stageIcons[_currentPage],
                              iconColor: accent,
                              title: RoutineConvergenceShowcase
                                  .titles[_currentPage],
                              description: _descriptions[_currentPage],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              GestureDetector(
                                onTap: () => _select(i),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: AnimatedContainer(
                                    duration: AppMotion.duration(
                                        context, AppMotion.fast),
                                    curve: AppMotion.magnetic,
                                    width: i == _currentPage ? 32 : 10,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _currentPage
                                          ? accent
                                          : AppColors.border,
                                      borderRadius: AppSpacing.radiusFull,
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                      AppSpacing.lgGap,
                      Row(
                        children: [
                          if (_currentPage > 0) ...[
                            IconButton.outlined(
                              onPressed: () => _select(_currentPage - 1),
                              tooltip: 'Previous stage',
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                minimumSize: const Size(
                                  AppSpacing.buttonHeight,
                                  AppSpacing.buttonHeight,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppSpacing.radiusMd,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_back, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Expanded(
                            child: UButton(
                              label:
                                  _currentPage == 2 ? 'Get Started' : 'Next',
                              onPressed: () {
                                if (_currentPage == 2) {
                                  _finish();
                                } else {
                                  _select(_currentPage + 1);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ]),
              ));
        })),
      );
}
