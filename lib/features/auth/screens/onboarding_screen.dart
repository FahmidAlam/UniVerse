import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/onboard_slide.dart';

class OnboardingScreen extends StatefulWidget {
  final AuthController authController;

  const OnboardingScreen({super.key, required this.authController});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    (
      icon: PhosphorIconsRegular.calendarCheck,
      title: 'Your classes,\nalways on time',
      description:
          'See your live class with a real-time countdown.\nNever miss a lecture again.',
      color: AppColors.primary,
    ),
    (
      icon: PhosphorIconsRegular.chatTeardropText,
      title: 'Ask anything,\nget real answers',
      description:
          'Our AI assistant is trained on your university data.\nNo hallucinations, only facts.',
      color: AppColors.info,
    ),
    (
      icon: PhosphorIconsRegular.bellRinging,
      title: 'Never miss\nan update',
      description:
          'Instant push notifications for cancellations,\ntests, exams, and room changes.',
      color: AppColors.success,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await widget.authController.markOnboardingSeen();
    if (mounted) context.go(RouteNames.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: AppSpacing.radiusFull,
                        ),
                      );
                    }),
                  ),

                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: AppTextStyles.link,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return OnboardSlide(
                    icon: slide.icon,
                    title: slide.title,
                    description: slide.description,
                    iconColor: slide.color,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.x3l,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.radiusMd,
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? 'Get Started' : 'Next',
                        style: AppTextStyles.button,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        isLast
                            ? PhosphorIconsRegular.rocketLaunch
                            : PhosphorIconsRegular.arrowRight,
                        size: AppSpacing.iconMd,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
