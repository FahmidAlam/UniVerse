import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  late final Future<DistributionAvailability> _distributionAvailability;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _distributionAvailability =
        widget.availabilityLoader?.call() ?? _inspectDistributionAvailability();
    _controller = SchedulingWorkspaceController(
      availabilityLoader: widget.availabilityLoader,
      initialPreviewMode: widget.initialPreviewMode,
    );
    _controller.setTabIndex(widget.initialTabIndex.clamp(0, 4));
    if (widget.initialSelectedRow != null) {
      final matches = _controller.records
          .where((r) => r.row == widget.initialSelectedRow);
      if (matches.isNotEmpty) {
        _controller.selectRecord(matches.first);
      }
    }
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _controller.currentTabIndex != _tabs.index) {
        _controller.setTabIndex(_tabs.index);
      }
    });
    _controller.addListener(() {
      if (_tabs.index != _controller.currentTabIndex) {
        _tabs.animateTo(_controller.currentTabIndex);
      }
    });
  }

  Future<DistributionAvailability> _inspectDistributionAvailability() async {
    try {
      final rows = await Supabase.instance.client
          .from('course_distribution_revisions')
          .select('id')
          .eq('status', 'accepted')
          .limit(1);
      return (rows as List).isEmpty
          ? DistributionAvailability.noAcceptedRevision
          : DistributionAvailability.available;
    } on Object {
      return DistributionAvailability.unavailable;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 1024;
        final isMobile = screenWidth < 768;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                isMobile ? AppSpacing.md : AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SchedulingHeaderBar(controller: _controller),
                  const SizedBox(height: AppSpacing.md),
                  SchedulingRevisionBar(controller: _controller),
                  const SizedBox(height: AppSpacing.md),
                  _buildTabBar(),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: _buildTabContent(isDesktop, isMobile),
                  ),
                ],
              ),
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

  Widget _buildTabContent(bool isDesktop, bool isMobile) {
    // If not in preview mode and backend contract is unavailable or checking,
    // preserve the truthful live capability boundary
    if (!_controller.isPreviewMode && !_controller.isLiveBackendReady) {
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

    // Fully populated interactive Phase 2B Experience
    return TabBarView(
      controller: _tabs,
      children: [
        _buildDistributionTab(isDesktop),
        SchedulingConfigurationPane(controller: _controller),
        SchedulingReadinessPane(controller: _controller),
        SchedulingGeneratePane(controller: _controller),
        SchedulingReviewPane(controller: _controller),
      ],
    );
  }

  Widget _buildDistributionTab(bool isDesktop) {
    return Column(
      children: [
        DistributionFiltersBar(controller: _controller),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: _controller.isInspectorOpen ? 65 : 100,
                      child: DistributionTableDesktop(controller: _controller),
                    ),
                    if (_controller.isInspectorOpen) ...[
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 380,
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
              : DistributionListMobile(controller: _controller),
        ),
      ],
    );
  }

  Widget _buildLiveDistributionBoundary() {
    return FutureBuilder<DistributionAvailability>(
      future: _distributionAvailability,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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
        }

        switch (snapshot.data) {
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
            return const _CapabilityUnavailable(
              title: 'Course Distribution reader is pending',
              detail:
                  'An accepted revision is available, but the source-record reader requires the reviewed client parsing boundary before its A–L evidence can be displayed.',
            );
          case DistributionAvailability.noAcceptedRevision:
            return _CapabilityUnavailable(
              title: 'No accepted Course Distribution revision is available',
              detail:
                  'A scoped accepted revision is required before source evidence can be read. The workspace will not use a local workbook or legacy timetable settings instead.',
              actionButton: _buildExplorePreviewButton(),
            );
          case DistributionAvailability.unavailable:
          case null:
            return _CapabilityUnavailable(
              title: 'Course Distribution is not available yet',
              detail:
                  'This connected environment requires the Phase 2a backend contract before a source revision can be read. No local workbook copy, sample records, or simulated correction flow is shown here.',
              actionButton: _buildExplorePreviewButton(),
            );
        }
      },
    );
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
