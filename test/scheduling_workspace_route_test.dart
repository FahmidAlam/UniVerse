// PHASE 0: Control pending availability without initializing hosted services.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/admin/screens/scheduling_workspace_screen.dart';

void main() {
  test('uses the dedicated scheduling workspace route', () {
    expect(RouteNames.schedulingWorkspace, '/admin/scheduling');
  });

  // PHASE 0: Accepted-row detection must remain a single check and lock every live pane.
  testWidgets('accepted revision keeps fixtures out of all live panes',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: SchedulingWorkspaceScreen(
      availabilityLoader: () async {
        calls++;
        return DistributionAvailability.available;
      },
    )));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Course Distribution reader is pending'), findsOneWidget);
    for (final tab in [
      'Distribution',
      'Configuration',
      'Readiness',
      'Generate',
      'Review & publish'
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('CSE-1101'), findsNothing);
      expect(find.text('SECTION CALENDAR'), findsNothing);
      expect(find.text('Run CP-SAT Solver'), findsNothing);
      expect(find.text('Section Grid'), findsNothing);
    }
    // PHASE 0: The explicit toggle still unlocks fixtures, and returning live hides them.
    await tester.tap(find.text('Design Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distribution'));
    await tester.pumpAndSettle();
    expect(find.text('CSE-1101'), findsWidgets);
    await tester.tap(find.text('Live Backend'));
    await tester.pumpAndSettle();
    expect(find.text('CSE-1101'), findsNothing);
    expect(find.textContaining('Accepted #4'), findsNothing);
    expect(find.text('Course Distribution reader is pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an explicit distribution capability boundary',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulingWorkspaceScreen(
          availabilityLoader: () async => DistributionAvailability.unavailable,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Scheduling Workspace'), findsOneWidget);
    expect(
        find.text('Course Distribution is not available yet'), findsOneWidget);
    expect(find.textContaining('requires the Phase 2a backend contract'),
        findsOneWidget);
    expect(find.text('No accepted distribution revision selected'),
        findsOneWidget);
  });

  testWidgets(
      'checks distribution availability before declaring it unavailable',
      (tester) async {
    // PHASE 0: Test a genuinely pending request rather than missing-client timing.
    final availability = Completer<DistributionAvailability>();
    await tester.pumpWidget(
      MaterialApp(
          home: SchedulingWorkspaceScreen(
        availabilityLoader: () => availability.future,
      )),
    );

    expect(find.text('Checking Course Distribution availability…'),
        findsOneWidget);
    availability.complete(DistributionAvailability.unavailable);
    await tester.pump();
  });
}
