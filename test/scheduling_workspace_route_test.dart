import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/admin/screens/scheduling_workspace_screen.dart';

void main() {
  test('uses the dedicated scheduling workspace route', () {
    expect(RouteNames.schedulingWorkspace, '/admin/scheduling');
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
    await tester.pumpWidget(
      const MaterialApp(home: SchedulingWorkspaceScreen()),
    );

    expect(find.text('Checking Course Distribution availability…'),
        findsOneWidget);
  });
}
