import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/shared/widgets/live_class_card.dart';

void main() {
  testWidgets(
      'live progress advances from real bounds and clamps at completion',
      (tester) async {
    var now = DateTime(2026, 11, 8, 10, 30);
    final start = DateTime(2026, 11, 8, 10);
    final end = DateTime(2026, 11, 8, 11);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
          body: LiveClassCard(
              subject: 'Algorithms',
              teacher: 'Faculty',
              room: 'R-201',
              startTime: start,
              endTime: end,
              clock: () => now)),
    )));
    LinearProgressIndicator progress() =>
        tester.widget(find.byType(LinearProgressIndicator));
    expect(progress().value, .5);
    expect(tester.binding.transientCallbackCount, 0);
    now = DateTime(2026, 11, 8, 10, 45);
    await tester.pump(const Duration(seconds: 1));
    expect(progress().value, .75);
    now = end.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(progress().value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or invalid start never implies fabricated progress',
      (tester) async {
    final now = DateTime(2026, 11, 8, 10);
    for (final start in [null, now, now.add(const Duration(hours: 1))]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
            body: LiveClassCard(
                subject: 'Algorithms',
                teacher: 'Faculty',
                room: 'R-201',
                startTime: start,
                endTime: now,
                clock: () => now)),
      )));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pulse stops when motion is disabled or class completes',
      (tester) async {
    var now = DateTime(2026, 11, 8, 10);
    final start = now;
    final end = now.add(const Duration(hours: 1));
    Widget view(bool reduced) => MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
              body: LiveClassCard(
                  subject: 'Algorithms',
                  teacher: 'Faculty',
                  room: 'R-201',
                  startTime: start,
                  endTime: end,
                  clock: () => now)),
        ));
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(view(true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(view(false));
    now = end;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
