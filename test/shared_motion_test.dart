import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:universe/shared/widgets/u_responsive_workspace.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

Widget harness(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(body: Center(child: child))),
    );

void main() {
  testWidgets('motion policy and swap immediately replace outgoing content',
      (tester) async {
    late StateSetter update;
    var value = 0;
    await tester
        .pumpWidget(harness(StatefulBuilder(builder: (context, setState) {
      update = setState;
      expect(AppMotion.reduced(context), isTrue);
      expect(AppMotion.duration(context, AppMotion.medium), Duration.zero);
      return UAnimatedSwap(child: Text('$value', key: ValueKey(value)));
    }), reduced: true));
    update(() => value = 1);
    await tester.pump();
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('swap keys animate replacement and settle to current child',
      (tester) async {
    await tester.pumpWidget(
        harness(const UAnimatedSwap(child: Text('A', key: ValueKey('A')))));
    await tester.pumpWidget(
        harness(const UAnimatedSwap(child: Text('B', key: ValueKey('B')))));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
  });

  testWidgets(
      'generic selector supports semantics keyboard and disabled segments',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 'rooms';
    await tester.pumpWidget(harness(
        StatefulBuilder(
            builder: (context, setState) => SizedBox(
                  width: 340,
                  child: USegmentedControl<String>(
                      segments: const [
                        USegment(value: 'rooms', label: 'Rooms'),
                        USegment(value: 'faculty', label: 'Faculty'),
                        USegment(
                            value: 'locked', label: 'Locked', enabled: false),
                      ],
                      selected: selected,
                      onChanged: (value) => setState(() => selected = value)),
                )),
        reduced: true));
    await tester.tap(find.text('Faculty'));
    await tester.pump();
    expect(selected, 'faculty');
    expect(
        tester.getSemantics(find.widgetWithText(TextButton, 'Faculty')),
        matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasSelectedState: true,
            isSelected: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
            label: 'Faculty',
            textDirection: TextDirection.ltr));
    await tester.tap(find.text('Locked'));
    expect(selected, 'faculty');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'rooms');
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  testWidgets(
      'press tracking restores on up cancel and exit without swallowing tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(UPressableScale(
        child:
            TextButton(onPressed: () => taps++, child: const Text('Action')))));
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Action')));
    await tester.pump();
    expect(scale(), 0.97);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
    final cancelled =
        await tester.startGesture(tester.getCenter(find.text('Action')));
    await tester.pump();
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Action')));
    await tester.pumpAndSettle();
    expect(scale(), 1.012);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(scale(), 1);
    await mouse.removePointer();
  });

  testWidgets(
      'showUAdaptiveModal renders desktop dialog at 1280x800 and mobile sheet at 390x844',
      (tester) async {
    // 1. Desktop (1280x800): centered modal dialog with [Esc] badge & Escape key dismissal
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 800),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showUAdaptiveModal<void>(
                  context: context,
                  title: 'Adaptive Governance',
                  badge: 'DESKTOP MODAL',
                  builder: (_) => const Text('Modal payload'),
                ),
                child: const Text('Open Overlay'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Overlay'));
    await tester.pumpAndSettle();
    expect(find.text('Adaptive Governance'), findsOneWidget);
    expect(find.text('Modal payload'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Adaptive Governance'), findsNothing);

    // 2. Mobile (390x844): floating bottom sheet without [Esc] badge, closes via Close button
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showUAdaptiveModal<void>(
                  context: context,
                  title: 'Adaptive Sheet',
                  badge: 'MOBILE SHEET',
                  builder: (_) => const Text('Sheet payload'),
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Adaptive Sheet'), findsOneWidget);
    expect(find.text('Sheet payload'), findsOneWidget);
    expect(find.text('Esc'), findsNothing);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Adaptive Sheet'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'UResponsiveWorkspace and UAdaptiveCardGrid switch from 1 column at 390px to multi-column at 1280px',
      (tester) async {
    Widget buildScene(Size size) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: UResponsiveWorkspace(
                  primary: UAdaptiveCardGrid(
                    itemCount: 6,
                    itemBuilder: (_, index) => Card(child: Text('Item $index')),
                  ),
                  secondary: const Text('Secondary Inspector'),
                ),
              ),
            ),
          ),
        );

    // Mobile 390px: 1-column ListView
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildScene(const Size(390, 844)));
    await tester.pumpAndSettle();
    expect(UAdaptiveCardGrid.columnsForWidth(390), 1);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    // Desktop 1280px: 2-column asymmetric workspace + multi-column GridView
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(buildScene(const Size(1280, 800)));
    await tester.pumpAndSettle();
    expect(UAdaptiveCardGrid.columnsForWidth(1280), 3);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Secondary Inspector'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
