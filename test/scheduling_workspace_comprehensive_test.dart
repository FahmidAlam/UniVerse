import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/features/admin/screens/scheduling_workspace_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('SchedulingWorkspaceController unit tests', () {
    // PHASE 0: A database row must never authorize fixture mutations in live mode.
    test('live mode refuses all preview mutations with an accepted row',
        () async {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.available,
      );
      addTearDown(controller.dispose);
      await controller.checkBackendAvailability();
      // PHASE 0: Existence and operational readiness are independent capabilities.
      expect(controller.hasAcceptedRevisionInDb, isTrue);
      expect(controller.isLiveWorkspaceOperational, isFalse);
      final revision = controller.revision;
      final policies = List.of(controller.policyItems);
      expect(
          await controller.saveAuditedCorrection(
            row: 19,
            column: 'I',
            effectiveValue: 'Faculty',
            reason: 'Assigned',
            author: 'Admin',
          ),
          isFalse);
      controller.sealDraftRevision(reason: 'Seal', author: 'Admin');
      controller.updatePolicyOverride(
          ruleId: 'R1 / D1', newOverride: 'Changed', newEffective: 'Changed');
      await controller.runSolverPreview();
      await controller.simulatePublishRoutine();
      expect(controller.revision, same(revision));
      expect(controller.policyItems, orderedEquals(policies));
      expect(controller.solverResult.state, SolverRunState.ready);
      expect(controller.publishedConfirmationId, isNull);
    });

    // PHASE 0: Revision and readiness summaries must count the same fixture list.
    test('preview summaries agree with source record count', () {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );
      addTearDown(controller.dispose);
      expect(controller.revision.totalRows, controller.records.length);
      expect(controller.readinessItems.first.description,
          contains('${controller.records.length} rows'));
    });

    test('initializes with preview fixtures and default CSE scope', () {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      expect(controller.isPreviewMode, isTrue);
      expect(controller.revision.department, contains('CSE'));
      expect(controller.revision.semester, 'Fall 2026');
      // PHASE 0: All preview metadata must count the same 23 source records.
      expect(controller.totalRecordsCount, 23);
      expect(controller.conflictsCount, 2);
      expect(controller.correctionsCount, 2);
      controller.dispose();
    });

    test('filters records by search query, batch, and conflict state', () {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      // Search
      controller.setSearchQuery('CSE-2201');
      expect(controller.filteredRecords.length, 1);
      expect(controller.filteredRecords.single.courseCode, 'CSE-2201');

      // Reset
      controller.resetFilters();
      expect(controller.filteredRecords.length, controller.totalRecordsCount);

      // Batch filter
      controller.setBatchFilter('2024');
      for (final r in controller.filteredRecords) {
        expect(r.batch, '2024');
      }

      // Conflicts only
      controller.resetFilters();
      controller.setOnlyConflicts(true);
      expect(controller.filteredRecords.length, controller.conflictsCount);
      for (final r in controller.filteredRecords) {
        expect(r.hasConflict, isTrue);
      }

      controller.dispose();
    });

    test('saves audited correction with provenance and version bump', () async {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      final initialVersion = controller.revision.revisionVersion;

      // Row 19 has pending teacher
      final row19 = controller.filteredRecords.firstWhere((r) => r.row == 19);
      expect(row19.isTeacherPending, isTrue);
      expect(row19.hasConflict, isTrue);

      final success = await controller.saveAuditedCorrection(
        row: 19,
        column: 'I',
        effectiveValue: 'Dr. FA',
        reason: 'Faculty council assigned Dr. FA to Section A lab',
        author: 'Dept Chair',
      );

      expect(success, isTrue);
      expect(controller.revision.revisionVersion, initialVersion + 1);

      final updatedRow19 =
          controller.filteredRecords.firstWhere((r) => r.row == 19);
      expect(updatedRow19.effectiveValue('I'), 'Dr. FA');
      expect(updatedRow19.originalValue('I'), contains('Pending'));
      expect(updatedRow19.hasCorrection, isTrue);
      expect(updatedRow19.hasConflict, isFalse); // Conflict resolved!

      // Verify readiness blocker was resolved
      final teacherCheck = controller.readinessItems
          .firstWhere((item) => item.id == 'chk-teacher-pending');
      expect(teacherCheck.isResolved, isTrue);

      controller.dispose();
    });

    test('updates policy overrides and selects records by row', () {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      controller.selectRecordByRow(19);
      expect(controller.selectedRecord?.row, 19);
      expect(controller.isInspectorOpen, isTrue);

      controller.updatePolicyOverride(
        ruleId: 'R1 / D1',
        newOverride: 'Thursday, Friday weekend for Batch 2024',
        newEffective: 'Saturday - Wednesday active',
      );
      final r1 =
          controller.policyItems.firstWhere((p) => p.ruleId == 'R1 / D1');
      expect(r1.overrideValue, 'Thursday, Friday weekend for Batch 2024');
      expect(r1.effectiveValue, 'Saturday - Wednesday active');

      controller.dispose();
    });

    test('simulates CP-SAT solver run and produces optimal result', () async {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      expect(controller.solverResult.state, SolverRunState.ready);

      final solveFuture = controller.runSolverPreview();
      expect(controller.isSolving, isTrue);

      await solveFuture;

      expect(controller.isSolving, isFalse);
      expect(controller.solverResult.state, SolverRunState.optimal);
      expect(controller.solverResult.hardViolations, 0);
      expect(controller.solverResult.softScorePercent, greaterThan(90));
      expect(controller.solverResult.variablesExplored, greaterThan(1000));

      controller.dispose();
    });

    test('seals draft revision snapshot and resets to baseline', () async {
      final controller = SchedulingWorkspaceController(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
      );

      final initialRevisionNum = controller.revision.revisionNumber;

      // Add a correction
      await controller.saveAuditedCorrection(
        row: 19,
        column: 'I',
        effectiveValue: 'Dr. FA',
        reason: 'Assigned lab teacher',
        author: 'Dept Chair',
      );

      expect(controller.correctionsCount, greaterThan(2));

      // Seal revision
      controller.sealDraftRevision(
        reason: 'Finalized course distribution snapshot',
        author: 'Academic Council',
      );

      expect(controller.revision.revisionNumber, initialRevisionNum + 1);
      expect(controller.revision.revisionVersion, 1);
      expect(controller.revision.status, 'accepted');
      expect(controller.revision.acceptedBy, 'Academic Council');

      // Reset to baseline
      controller.resetToBaseline();
      expect(controller.revision.revisionNumber, initialRevisionNum);
      expect(controller.conflictsCount, 2);

      controller.dispose();
    });
  });

  group('SchedulingWorkspaceScreen widget tests', () {
    testWidgets('renders desktop preview workspace across all 5 tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SchedulingWorkspaceScreen(
            availabilityLoader: () async =>
                DistributionAvailability.unavailable,
            initialPreviewMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Context
      expect(find.text('Scheduling Workspace'), findsOneWidget);
      expect(find.text('DESIGN PREVIEW'), findsOneWidget);
      expect(find.textContaining('Scope: Computer Science & Engineering'),
          findsOneWidget);
      expect(find.textContaining('Accepted #4'), findsOneWidget);

      // Distribution Tab Table
      expect(find.text('CSE-1101'), findsWidgets);
      expect(find.text('MAT-1105'), findsWidgets);

      // Tap inspect on row 6 to verify inspector
      await tester.tap(find.byTooltip('Inspect record').first);
      await tester.pumpAndSettle();
      expect(find.text('Record Inspector · Row 6'), findsOneWidget);

      // Navigate to Configuration Tab
      await tester.tap(find.text('Configuration'));
      await tester.pumpAndSettle();
      expect(find.text('SECTION CALENDAR'), findsOneWidget);
      expect(find.text('FACULTY WORKLOAD'), findsOneWidget);
      expect(find.text('R1 / D1'), findsOneWidget);
      expect(find.text('R7 / D3'), findsOneWidget);

      // PHASE 0: Persistent warnings describe source records, not solved collisions.
      expect(find.textContaining('2 source warnings'), findsOneWidget);

      // Navigate to Readiness Tab
      await tester.tap(find.text('Readiness'));
      await tester.pumpAndSettle();
      // PHASE 0: Readiness copy agrees with the distribution table count.
      expect(find.textContaining('hash-verified (23 rows'), findsOneWidget);
      expect(find.text('PREFLIGHT BLOCKED (NO-GO)'), findsOneWidget);
      expect(find.text('PREFLIGHT CHECKPOINTS & BLOCKERS'), findsOneWidget);
      expect(find.text('Unassigned Lab Instructor in Row 19'), findsOneWidget);

      // Navigate to Generate Tab
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(
          find.text('MULTI-OBJECTIVE OPTIMIZATION PARAMETERS'), findsOneWidget);
      expect(find.text('Run CP-SAT Solver'), findsOneWidget);

      // Navigate to Review Tab
      await tester.tap(find.text('Review & publish'));
      await tester.pumpAndSettle();
      expect(find.text('Section Grid'), findsOneWidget);
      expect(find.text('Conflict Inspector: Zero Hard Collisions'),
          findsOneWidget);

      // Verify Faculty Schedule view
      await tester.tap(find.text('Faculty Schedule'));
      await tester.pumpAndSettle();
      expect(find.textContaining('FACULTY SCHEDULE TIMELINE'), findsOneWidget);

      // Verify Room Occupancy view
      await tester.tap(find.text('Room Occupancy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROOM OCCUPANCY SCHEDULE'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.textContaining('ATOMIC PUBLICATION GATE'), findsOneWidget);
    });

    testWidgets('adapts to mobile viewport without table overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SchedulingWorkspaceScreen(
            availabilityLoader: () async =>
                DistributionAvailability.unavailable,
            initialPreviewMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile list elements
      expect(find.text('Scheduling Workspace'), findsOneWidget);
      expect(find.text('DESIGN PREVIEW'), findsOneWidget);
      expect(find.text('Row 6 · 2024 A'), findsOneWidget);
      expect(find.text('CSE-1101'), findsWidgets);

      expect(tester.takeException(), isNull);
    });
  });
}
