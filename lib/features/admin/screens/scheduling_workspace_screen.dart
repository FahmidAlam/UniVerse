import 'package:flutter/material.dart';
// PHASE 0: Availability is owned by the controller; no duplicate screen query.
import 'package:go_router/go_router.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/widgets/configuration/scheduling_configuration_pane.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_filters_bar.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_list_mobile.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_record_inspector.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_table_desktop.dart';
import 'package:universe/features/admin/scheduling/widgets/generate/scheduling_generate_pane.dart';
import 'package:universe/features/admin/scheduling/widgets/readiness/scheduling_readiness_pane.dart';
import 'package:universe/features/admin/scheduling/widgets/review/scheduling_review_pane.dart';
import 'package:universe/features/admin/scheduling/widgets/scheduling_header_bar.dart';
import 'package:universe/features/admin/scheduling/widgets/scheduling_revision_bar.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';

export 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart'
    show DistributionAvailability;

/// Primary Phase 2B Scheduling Workspace Screen.
///
/// Provides a unified, professional university administrative experience across:
/// 1. Course Distribution (Traceable workbook source, formulas, cached values, audited corrections)
/// 2. Configuration (Revision-bound academic policy snapshot for decisions R1–R15)
/// 3. Readiness (Actionable preflight go/no-go checks)
/// 4. Generate (OR-Tools CP-SAT multi-objective solver control & diagnostics)
/// 5. Review & Publish (Interactive candidate routine grid, conflict inspector, publication gate)
///
/// Features a strict boundary between Live Backend mode (truthful checking of Supabase contracts)
/// and Design Preview mode (isolated, realistic academic fixtures for visual review).
class SchedulingWorkspaceScreen extends StatefulWidget {
  final Future<DistributionAvailability> Function()? availabilityLoader;
  final bool initialPreviewMode;
  final int initialTabIndex;
  final int? initialSelectedRow;

  const SchedulingWorkspaceScreen({
    super.key,
    this.availabilityLoader,
    this.initialPreviewMode = false,
    this.initialTabIndex = 0,
    this.initialSelectedRow,
  });

  @override
  State<SchedulingWorkspaceScreen> createState() =>
      _SchedulingWorkspaceScreenState();
}

class _SchedulingWorkspaceScreenState extends State<SchedulingWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final SchedulingWorkspaceController _controller;
  // PHASE 0: Adjacent preview panes must not share a primary scroll position.
  final _paneScrollControllers = List.generate(5, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    // PHASE 0: One controller owns availability and refresh state.
    _controller = SchedulingWorkspaceController(
      availabilityLoader: widget.availabilityLoader,
      initialPreviewMode: widget.initialPreviewMode,
    );
    _controller.setTabIndex(widget.initialTabIndex.clamp(0, 4));
    if (widget.initialSelectedRow != null) {
      final matches =
          _controller.records.where((r) => r.row == widget.initialSelectedRow);
      if (matches.isNotEmpty) {
        _controller.selectRecord(matches.first);
      }
    }
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging &&
          _controller.currentTabIndex != _tabs.index) {
        _controller.setTabIndex(_tabs.index);
      }
    });
    _controller.addListener(() {
      if (_tabs.index != _controller.currentTabIndex) {
        _tabs.animateTo(_controller.currentTabIndex);
      }
    });
  }

  @override
  void dispose() {
    // PHASE 0: Release the independently owned preview scroll controllers.
    for (final controller in _paneScrollControllers) {
      controller.dispose();
    }
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // PHASE 5: Drive workbench layout from LayoutBuilder post-sidebar usable width
        // instead of raw MediaQuery screen width to prevent 1024px sidebar collision.
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final isCompactOuter = outerConstraints.maxWidth < 768;
                return Padding(
                  padding: EdgeInsets.all(
                    isCompactOuter ? AppSpacing.md : AppSpacing.xl,
                  ),
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final usableWidth = innerConstraints.maxWidth;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SchedulingHeaderBar(controller: _controller),
                          const SizedBox(height: AppSpacing.md),
                          SchedulingRevisionBar(controller: _controller),
                          const SizedBox(height: AppSpacing.md),
                          _buildTabBar(),
                          const SizedBox(height: AppSpacing.md),
                          Expanded(
                            child: _buildTabContent(usableWidth),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: AppTextStyles.bodySmMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AppTextStyles.bodySm,
        tabs: const [
          Tab(text: 'Distribution'),
          Tab(text: 'Configuration'),
          Tab(text: 'Readiness'),
          Tab(text: 'Generate'),
          Tab(text: 'Review & publish'),
        ],
      ),
    );
  }

  Widget _buildTabContent(double usableWidth) {
    // PHASE 0: Live mode must never fall through to fixture-backed panes.
    if (!_controller.isPreviewMode) {
      return TabBarView(
        controller: _tabs,
        children: [
          _buildLiveDistributionBoundary(),
          const _CapabilityUnavailable(
            title: 'Revision-bound configuration is not available yet',
            detail:
                'It requires a versioned policy snapshot contract. Existing mutable timetable settings are not used as a substitute.',
          ),
          const _CapabilityUnavailable(
            title: 'Readiness checks are not available yet',
            detail:
                'They require an accepted distribution revision and a revision-bound policy snapshot.',
          ),
          const _CapabilityUnavailable(
            title: 'Generation is not available from this workspace yet',
            detail:
                'It requires an engine boundary that consumes the exact accepted distribution and policy revisions.',
          ),
          const _CapabilityUnavailable(
            title: 'Review and publication are not available yet',
            detail:
                'They require server-authoritative validation and atomic publication bound to the selected revisions.',
          ),
        ],
      );
    }

    // PHASE 0: Isolate scroll positions while preview tabs coexist in transitions.
    return TabBarView(
      controller: _tabs,
      children: [
        _buildDistributionTab(usableWidth),
        SchedulingConfigurationPane(controller: _controller),
        SchedulingReadinessPane(controller: _controller),
        SchedulingGeneratePane(controller: _controller),
        SchedulingReviewPane(controller: _controller),
      ]
          .asMap()
          .entries
          .map((entry) => PrimaryScrollController(
                controller: _paneScrollControllers[entry.key],
                child: entry.value,
              ))
          .toList(),
    );
  }

  // PHASE 5: Three-tier distribution layout based on post-sidebar usableWidth:
  // - Expanded (>= 1020px): Full 12-column table + docked 360px Record Inspector.
  // - Medium (680px <= usableWidth < 1020px): Full-width 12-column table; Record Inspector opens in adaptive modal.
  // - Compact (< 680px): Touch-friendly DistributionListMobile with bottom-sheet inspector.
  Widget _buildDistributionTab(double usableWidth) {
    final isExpanded = usableWidth >= 1020;
    final isMedium = usableWidth >= 680 && usableWidth < 1020;

    // PHASE 5: Short canvases scroll the toolbar with the table workspace rather
    // than forcing the persistent above-field labels into a collapsed Column.
    // The table retains its own scroll controller and a usable minimum canvas.
    return LayoutBuilder(builder: (context, constraints) {
      final workspaceHeight =
          constraints.maxHeight < 560 ? 560.0 : constraints.maxHeight;
      return SingleChildScrollView(
        primary: false,
        child: SizedBox(
          height: workspaceHeight,
          child: Column(
            children: [
              DistributionFiltersBar(
                controller: _controller,
                onToggleInspector: isMedium
                    ? () => _openAdaptiveInspectorModal(context)
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: isExpanded
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: _controller.isInspectorOpen ? 65 : 100,
                            child: DistributionTableDesktop(
                                controller: _controller),
                          ),
                          if (_controller.isInspectorOpen) ...[
                            const SizedBox(width: AppSpacing.md),
                            SizedBox(
                              width: 360,
                              child: ClipRRect(
                                borderRadius: AppSpacing.radiusMd,
                                child: DistributionRecordInspector(
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : isMedium
                        ? DistributionTableDesktop(
                            controller: _controller,
                            onInspectRecord: (record) {
                              _controller.selectRecord(record);
                              _openAdaptiveInspectorModal(context);
                            },
                          )
                        : DistributionListMobile(controller: _controller),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _openAdaptiveInspectorModal(BuildContext context) {
    final record = _controller.selectedRecord ??
        (_controller.filteredRecords.isNotEmpty
            ? _controller.filteredRecords.first
            : null);
    if (record != null && _controller.selectedRecord == null) {
      _controller.selectRecord(record);
    }
    showUAdaptiveModal<void>(
      context: context,
      title: record != null
          ? 'Provenance Inspector · Row ${record.row}'
          : 'Provenance Inspector',
      subtitle: record != null
          ? '${record.courseCode} · Batch ${record.batch} (${record.section})'
          : 'Select a distribution row to inspect cell provenance.',
      badge: 'SIMULATED PREVIEW · NO DATABASE WRITES',
      icon: PhosphorIconsRegular.fileText,
      maxDesktopWidth: 560,
      builder: (modalCtx) => SizedBox(
        height: 520,
        child: DistributionRecordInspector(
          controller: _controller,
          isMobileModal: true,
        ),
      ),
    );
  }

  Widget _buildLiveDistributionBoundary() {
    // PHASE 0: Read the same controller state as the header and refresh action.
    return Builder(builder: (context) {
      switch (_controller.backendAvailability) {
        case DistributionAvailability.checking:
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.lg),
                Text('Checking Course Distribution availability…'),
              ],
            ),
          );
        case DistributionAvailability.available:
          // PHASE 0: Row existence proves neither live parsing nor mutation readiness.
          return _CapabilityUnavailable(
            title: 'Course Distribution reader is pending',
            detail:
                'An accepted revision exists in the database. Live source-reading, correction RPCs, policy binding, and solver/publication wiring are pending Phase 2B/3 integration. Use /admin/routine?tab=generate for operational timetable generation or switch to Design Preview.',
            actionButton: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => context.go('/admin/routine?tab=generate'),
                  child: const Text('Open operational timetable generation'),
                ),
                _buildExplorePreviewButton(),
              ],
            ),
          );
        case DistributionAvailability.noAcceptedRevision:
          return _CapabilityUnavailable(
            title: 'No accepted Course Distribution revision is available',
            detail:
                'A scoped accepted revision is required before source evidence can be read. The workspace will not use a local workbook or legacy timetable settings instead.',
            actionButton: _buildExplorePreviewButton(),
          );
        case DistributionAvailability.unavailable:
          return _CapabilityUnavailable(
            title: 'Course Distribution is not available yet',
            detail:
                'This connected environment requires the Phase 2a backend contract before a source revision can be read. No local workbook copy, sample records, or simulated correction flow is shown here.',
            actionButton: _buildExplorePreviewButton(),
          );
      }
    });
  }

  Widget _buildExplorePreviewButton() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: () => _controller.togglePreviewMode(true),
        icon: const Icon(PhosphorIconsRegular.sparkle, size: 16),
        label: const Text('Explore Proposed UI in Design Preview Mode'),
      ),
    );
  }
}

class _CapabilityUnavailable extends StatelessWidget {
  final String title;
  final String detail;
  final Widget? actionButton;

  const _CapabilityUnavailable({
    required this.title,
    required this.detail,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border.all(color: AppColors.border),
            borderRadius: AppSpacing.radiusMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                PhosphorIconsRegular.lock,
                color: AppColors.warning,
                size: AppSpacing.iconXl,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (actionButton != null) actionButton!,
            ],
          ),
        ),
      ),
    );
  }
}
