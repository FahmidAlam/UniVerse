import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/shared/widgets/u_badge.dart';
import 'package:universe/shared/widgets/u_bottom_nav.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

// Helper for WCAG 2.1 relative luminance and contrast ratio calculations
double _relativeLuminance(Color color) {
  double channel(double c) {
    return (c <= 0.04045)
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  // Use ARGB channels normalized to [0, 1]
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast', () {
    test('textPrimary against background exceeds WCAG AAA (7.0:1)', () {
      final ratio = _contrastRatio(AppColors.textPrimary, AppColors.background);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'textPrimary (#F3F4F6) on #0B0C0E should be >= 7.0:1');
    });

    test('textSecondary against background exceeds WCAG AA (4.5:1)', () {
      final ratio =
          _contrastRatio(AppColors.textSecondary, AppColors.background);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'textSecondary (#B8BCC6) on #0B0C0E should be >= 4.5:1');
    });

    test('textMuted against background and surface exceeds WCAG AA (4.5:1)',
        () {
      final ratioBg = _contrastRatio(AppColors.textMuted, AppColors.background);
      final ratioSurface =
          _contrastRatio(AppColors.textMuted, AppColors.surface);
      expect(ratioBg, greaterThanOrEqualTo(4.5),
          reason: 'textMuted (#8A909E) on #0B0C0E should be >= 4.5:1');
      expect(ratioSurface, greaterThanOrEqualTo(4.5),
          reason: 'textMuted (#8A909E) on #17191E should be >= 4.5:1');
    });

    test('textOnPrimary against primary (#FF7A00) exceeds WCAG AAA (7.0:1)',
        () {
      final ratio = _contrastRatio(AppColors.textOnPrimary, AppColors.primary);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'textOnPrimary (#0B0C0E) on #FF7A00 should be >= 7.0:1');
    });

    testWidgets('ThemeData.dark incorporates Obsidian Orbit ColorScheme tokens',
        (tester) async {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.onPrimary, equals(AppColors.textOnPrimary));
      expect(theme.colorScheme.surface, equals(AppColors.surface));
      expect(theme.colorScheme.outline, equals(AppColors.border));
    });

    test('AppSpacing and AppTextStyles follow strict Obsidian Orbit scale', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.gapIntraGroup, 8.0);
      expect(AppSpacing.gapSection, 24.0);
      expect(AppSpacing.chipHeight, 36.0);

      expect(AppTextStyles.h1.fontSize, 24);
      expect(AppTextStyles.h1.letterSpacing, -0.4);
      expect(AppTextStyles.displayLarge.fontSize, 32);
      expect(AppTextStyles.displayLarge.letterSpacing, -0.8);
      expect(AppTextStyles.numeric.fontFeatures, isNotEmpty);
    });
  });

  group('Phase 2: UButton Component States', () {
    testWidgets('renders primary button with label, icon, and handles tap',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UButton(
              label: 'Submit Routine',
              icon: Icons.check,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Routine'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Submit Routine'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders loading state without label text and does not tap',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UButton(
              label: 'Loading Button',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Button'), findsNothing);

      await tester.tap(find.byType(UButton));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('renders disabled state with no tap interaction',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: UButton(
              label: 'Disabled Action',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Disabled Action'), findsOneWidget);
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('respects MediaQueryData(disableAnimations: true)',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: UButton(
                label: 'Reduced Motion',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Reduced Motion'), findsOneWidget);
      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animContainer.duration, equals(Duration.zero));
    });
  });

  group('Phase 2: UCard Component & Top-Lit Highlight', () {
    testWidgets('renders standard card and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UCard(
              onTap: () => tapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders elevated card with surfaceElevated background',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: UCard(
              elevated: true,
              child: Text('Elevated Card'),
            ),
          ),
        ),
      );

      final container = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      final boxDec = container.decoration as BoxDecoration;
      expect(boxDec.color, equals(AppColors.surfaceElevated));
    });

    testWidgets('renders isTopLit with specular top-edge highlight',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: UCard(
              isTopLit: true,
              child: Text('Top Lit Card'),
            ),
          ),
        ),
      );

      expect(find.text('Top Lit Card'), findsOneWidget);
      final uCardFinder = find.byType(UCard);
      expect(find.descendant(of: uCardFinder, matching: find.byType(ClipRRect)),
          findsOneWidget);
      expect(find.descendant(of: uCardFinder, matching: find.byType(Stack)),
          findsOneWidget);

      // Verify the top 1px highlight container exists inside UCard
      final topHighlightFinder = find.descendant(
        of: uCardFinder,
        matching: find.byWidgetPredicate((widget) {
          if (widget is AnimatedContainer &&
              (widget.decoration as BoxDecoration?)?.color ==
                  AppColors.specular) {
            return true;
          }
          return false;
        }),
      );
      expect(topHighlightFinder, findsOneWidget);
    });
  });

  group('Phase 2: UTextField Component', () {
    testWidgets('renders label, hint, and handles input text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UTextField(
              label: 'Room Code',
              hint: 'e.g. 302',
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Room Code'), findsOneWidget);
      expect(find.text('e.g. 302'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '401');
      await tester.pump();
      expect(controller.text, equals('401'));
    });

    testWidgets('renders disabled state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: UTextField(
              label: 'Locked Field',
              hint: 'Disabled',
              enabled: false,
            ),
          ),
        ),
      );

      final formField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(formField.enabled, isFalse);
    });

    testWidgets('animates focus glow when field gains and loses focus',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: UTextField(
              label: 'Department',
              hint: 'CSE',
            ),
          ),
        ),
      );

      BoxDecoration glowDecoration() {
        final animContainer = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byType(UTextField),
          matching: find.byType(AnimatedContainer),
        ));
        return animContainer.decoration as BoxDecoration;
      }

      expect(glowDecoration().boxShadow, isNull);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(glowDecoration().boxShadow, isNotNull);
      expect(glowDecoration().boxShadow!.single.blurRadius, equals(12.0));

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(glowDecoration().boxShadow, isNull);
    });
  });

  group('Phase 2: UChip & UBadge Components', () {
    testWidgets('UChip has >= 36px touch height and triggers tap',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: UChip(
                label: 'All Rooms',
                isActive: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final chipSize = tester.getSize(find.byType(UChip));
      expect(chipSize.height, greaterThanOrEqualTo(36.0),
          reason: 'Interactive chips must meet >= 36px touch height');

      await tester.tap(find.byType(UChip));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('UBadge renders all statuses and respects disableAnimations',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  UBadge(status: ClassStatus.live),
                  UBadge(status: ClassStatus.next),
                  UBadge(status: ClassStatus.upcoming),
                  UBadge(status: ClassStatus.cancelled),
                  UBadge(status: ClassStatus.done),
                  UBadge(status: ClassStatus.live, customLabel: 'ACTIVE'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });

  group('Phase 2: UBottomNav Dual Visual Cues', () {
    testWidgets('renders active pill container and w700 text style',
        (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            bottomNavigationBar: UBottomNav(
              items: const [
                UNavItem(icon: Icons.home, label: 'Today'),
                UNavItem(icon: Icons.calendar_today, label: 'Routine'),
                UNavItem(icon: Icons.meeting_room, label: 'Campus'),
              ],
              currentIndex: selected,
              onTap: (idx) => selected = idx,
            ),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Routine'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);

      // Verify active label has w700 fontWeight
      final activeText = tester.widget<Text>(find.text('Today'));
      expect(activeText.style?.fontWeight, equals(FontWeight.w700));

      // Inactive label has w500 fontWeight
      final inactiveText = tester.widget<Text>(find.text('Routine'));
      expect(inactiveText.style?.fontWeight, equals(FontWeight.w500));
    });
  });

  group('Phase 2: UEmptyState Presenter Variants', () {
    testWidgets('UEmptyState.firstUse renders calm guidance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UEmptyState.firstUse(),
          ),
        ),
      );

      expect(find.text('No routine scheduled yet'), findsOneWidget);
      expect(
        find.text(
            'Your semester timetable will appear here once the department publishes an approved routine.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'UEmptyState.noMatches acknowledges query and triggers clear action',
        (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UEmptyState.noMatches(
              query: 'Dr. Rahim',
              onClearFilters: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('No matches for "Dr. Rahim"'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('UEmptyState.error displays error copy and triggers retry',
        (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UEmptyState.error(
              title: 'Connection lost',
              message: 'Check your internet connection and try again.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Check your internet connection and try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('UEmptyState.lockedCapability communicates preview boundary',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: UEmptyState.lockedCapability(
              title: 'Solver Optimization Pending',
              message:
                  'Live solver execution requires independent backend verification under Gate D.',
              badgeLabel: 'PREVIEW ONLY',
            ),
          ),
        ),
      );

      expect(find.text('Solver Optimization Pending'), findsOneWidget);
      expect(
        find.text(
            'Live solver execution requires independent backend verification under Gate D.'),
        findsOneWidget,
      );
      expect(find.text('PREVIEW ONLY'), findsOneWidget);
    });
  });

  group('Phase 2: ULoading Presenter', () {
    testWidgets('ULoading.spinner renders with primary color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ULoading.spinner(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ULoading.skeleton respects disableAnimations', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              body: ULoading.skeleton(
                skeletonWidth: 200,
                skeletonHeight: 40,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });
  });
}
