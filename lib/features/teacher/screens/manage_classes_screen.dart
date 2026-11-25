import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/teacher/controllers/manage_classes_controller.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

// PHASE 4: Surgical Teacher Class Management with unmistakable Occurrence Date Banner,
// Expanded Desktop Master-Detail Split Workspace (>=900px, 55% list / 45% docked inspector),
// Mobile/Medium top-lit floating sheet (<900px), and truthful two-step recovery feedback.
class ManageClassesScreen extends StatefulWidget {
  final AuthController authController;
  final ManageClassesController? controller;
  final DateTime Function()? clock;

  const ManageClassesScreen({
    super.key,
    required this.authController,
    this.controller,
    this.clock,
  });

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  late final ManageClassesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ManageClassesController(
          authController: widget.authController,
          clock: widget.clock,
        );
    if (_ownsController || !_controller.hasLoaded) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  String get _selectedDayLong {
    final i = AppConstants.weekDaysShort.indexOf(_controller.selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _controller.selectedDay;
  }

  String get _formattedOccurrenceDate {
    final d = _controller.selectedOccurrenceDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  void _snack(String msg, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodySm),
        backgroundColor:
            isWarning ? AppColors.warningSoft : AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Manage Classes', showBackButton: false),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCompactDateStepperHeader(),
                    AppSpacing.smGap,
                    DaySelector(
                      selectedDay: _controller.selectedDay,
                      onSelect: _controller.setDay,
                    ),
                    AppSpacing.smGap,
                    _buildFilterRow(),
                    if (_controller.feedbackBannerMessage != null) ...[
                      AppSpacing.smGap,
                      _buildStatusFeedbackBanner(),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: _controller.load,
                  child: _buildResponsiveBody(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // PHASE 4 / C: Interactive Date Stepper (< [Day, Date] > + Today pill) replacing verbose yellow banner.
  Widget _buildCompactDateStepperHeader() {
    final isToday = _controller.isSelectedDayToday;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.caretLeft, size: 16),
            tooltip: 'Previous day',
            onPressed: () => _controller.stepDay(-1),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            color: AppColors.textSecondary,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsRegular.calendar,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$_selectedDayLong, $_formattedOccurrenceDate',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Text(
                      'TODAY',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.textOnPrimary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.caretRight, size: 16),
            tooltip: 'Next day',
            onPressed: () => _controller.stepDay(1),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            color: AppColors.textSecondary,
          ),
          if (!isToday) ...[
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Jump to today',
              child: InkWell(
                onTap: _controller.goToToday,
                borderRadius: AppSpacing.radiusSm,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Today',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final total = _controller.entriesForSelectedDay.length;
    final scheduled = _controller.scheduledCountForSelectedDay;
    final cancelled = _controller.cancelledCountForSelectedDay;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          UChip(
            label: 'All ($total)',
            isActive: _controller.activeFilter == ManageClassFilter.all,
            onTap: () => _controller.setFilter(ManageClassFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          UChip(
            label: 'Scheduled ($scheduled)',
            isActive: _controller.activeFilter == ManageClassFilter.scheduled,
            onTap: () => _controller.setFilter(ManageClassFilter.scheduled),
          ),
          const SizedBox(width: AppSpacing.sm),
          UChip(
            label: 'Cancelled ($cancelled)',
            isActive: _controller.activeFilter == ManageClassFilter.cancelled,
            onTap: () => _controller.setFilter(ManageClassFilter.cancelled),
          ),
        ],
      ),
    );
  }

  // PHASE 4: Truthful two-step status/recovery banner (full success, partial-failure warning, or undo follow-up).
  Widget _buildStatusFeedbackBanner() {
    final msg = _controller.feedbackBannerMessage!;
    final isWarning = _controller.isFeedbackWarning;
    final accent = isWarning ? AppColors.warning : AppColors.success;
    final bg = isWarning ? AppColors.warningSoft : AppColors.successSoft;
    final selected = _controller.selectedEntry;
    final showRestoredQuickAction = selected != null &&
        _controller.isRestoredNoticeEligible(selected) &&
        !_controller.isCancelled(selected);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning
                    ? PhosphorIconsRegular.warningCircle
                    : PhosphorIconsRegular.checkCircle,
                size: AppSpacing.iconMd,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  msg,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _controller.dismissFeedbackBanner,
                tooltip: 'Dismiss message',
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (showRestoredQuickAction) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _controller.isSubmitting
                    ? null
                    : () => _controller.sendClassRestoredNotice(selected),
                icon: const Icon(
                  PhosphorIconsRegular.paperPlaneTilt,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: Text(
                  "Send 'Class Restored' Notice to Cohort",
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveBody() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return ListView.separated(
        padding: AppSpacing.screenPaddingScrollable,
        itemCount: 4,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 110),
      );
    }

    if (_controller.errorMessage != null && !_controller.hasLoaded) {
      return ScrollableEmpty(
        child: UEmptyState.error(
          title: 'Could not load your classes',
          message: _controller.errorMessage!,
          onRetry: _controller.load,
        ),
      );
    }

    final allDayEntries = _controller.entriesForSelectedDay;
    if (allDayEntries.isEmpty) {
      return const ScrollableEmpty(
        child: UEmptyState(
          icon: PhosphorIconsRegular.calendarBlank,
          title: 'No classes',
          message: 'You have nothing scheduled for this day.',
        ),
      );
    }

    // PHASE 4: Measure usable width via LayoutBuilder -> >=900px renders 55%/45% Master-Detail Split Workspace.
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isExpandedDesktop = usableWidth >= 900;

        if (isExpandedDesktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 55,
                  child: _buildClassList(isDesktopSplit: true),
                ),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(
                  flex: 45,
                  child: _buildDockedInspectorPane(),
                ),
              ],
            ),
          );
        }

        return _buildClassList(isDesktopSplit: false);
      },
    );
  }

  Widget _buildClassList({required bool isDesktopSplit}) {
    final entries = _controller.filteredEntriesForSelectedDay;
    if (entries.isEmpty) {
      return ScrollableEmpty(
        child: UEmptyState.noMatches(
          query: _controller.activeFilter == ManageClassFilter.cancelled
              ? 'Cancelled classes'
              : 'Scheduled classes',
          onClearFilters: _controller.clearFilter,
        ),
      );
    }

    final now = _controller.now;
    final isToday = _controller.isSelectedDayToday;
    final selected = _controller.selectedEntry;

    return ListView.separated(
      padding: isDesktopSplit
          ? const EdgeInsets.only(bottom: AppSpacing.xxl)
          : AppSpacing.screenPaddingScrollable,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => AppSpacing.cardGap,
      itemBuilder: (context, i) {
        final e = entries[i];
        final cancelled = _controller.isCancelled(e);
        final status = cancelled
            ? ClassStatus.cancelled
            : (isToday ? e.statusOn(now, isToday: true) : ClassStatus.upcoming);
        final statusLabel = cancelled
            ? 'Cancelled for $_formattedOccurrenceDate'
            : 'Scheduled';

        return ClassCard(
          subject: e.subject,
          subjectCode: e.subjectCode,
          teacher: e.teacherDisplay,
          room: e.room,
          timeSlot: e.timeLabel,
          status: status,
          statusLabelOverride: statusLabel,
          batch: e.batch,
          section: e.section,
          isSelected: isDesktopSplit && selected?.id == e.id,
          onTap: () {
            _controller.selectEntry(e);
            if (!isDesktopSplit) {
              _openMobileInspectorSheet(e);
            }
          },
        );
      },
    );
  }

  Widget _buildDockedInspectorPane() {
    final selected = _controller.selectedEntry;
    if (selected == null) {
      return UCard(
        isTopLit: true,
        child: const UEmptyState(
          icon: PhosphorIconsRegular.slidersHorizontal,
          title: 'Select a class occurrence',
          message:
              'Choose a class on the left to manage its occurrence or compose a cohort notice.',
        ),
      );
    }

    return SingleChildScrollView(
      child: UAnimatedSwap(
        child: KeyedSubtree(
          key: ValueKey<String>(
            'inspector:${selected.id}:${_controller.isCancelled(selected)}',
          ),
          child: _ClassActionInspectorPanel(
            entry: selected,
            controller: _controller,
            selectedDayLong: _selectedDayLong,
            formattedOccurrenceDate: _formattedOccurrenceDate,
            isDockedDesktop: true,
            onFeedback: _snack,
          ),
        ),
      ),
    );
  }

  // PHASE 4: Mobile & Medium (<900px) top-lit adaptive sheet for class occurrence management.
  void _openMobileInspectorSheet(RoutineEntry entry) {
    showUAdaptiveModal<void>(
      context: context,
      title: entry.subject,
      subtitle:
          '${entry.timeLabel} · Batch ${entry.batch} · Sec ${entry.section}',
      badge: _controller.isCancelled(entry)
          ? 'CANCELLED FOR ${_formattedOccurrenceDate.toUpperCase()}'
          : 'OCCURRENCE · ${_formattedOccurrenceDate.toUpperCase()}',
      icon: PhosphorIconsRegular.slidersHorizontal,
      accentColor:
          _controller.isCancelled(entry) ? AppColors.error : AppColors.primary,
      maxDesktopWidth: 540,
      builder: (sheetCtx) => SingleChildScrollView(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (_, __) => _ClassActionInspectorPanel(
            entry: entry,
            controller: _controller,
            selectedDayLong: _selectedDayLong,
            formattedOccurrenceDate: _formattedOccurrenceDate,
            isDockedDesktop: false,
            onFeedback: (msg, {bool isWarning = false}) {
              if (Navigator.of(sheetCtx).canPop()) {
                Navigator.of(sheetCtx).pop();
              }
              _snack(msg, isWarning: isWarning);
            },
          ),
        ),
      ),
    );
  }
}

// PHASE 4: Shared Class Action & Cohort Notice Inspector used both in the desktop docked right pane
// and inside the mobile/medium floating sheet.
class _ClassActionInspectorPanel extends StatefulWidget {
  final RoutineEntry entry;
  final ManageClassesController controller;
  final String selectedDayLong;
  final String formattedOccurrenceDate;
  final bool isDockedDesktop;
  final void Function(String message, {bool isWarning}) onFeedback;

  const _ClassActionInspectorPanel({
    required this.entry,
    required this.controller,
    required this.selectedDayLong,
    required this.formattedOccurrenceDate,
    required this.isDockedDesktop,
    required this.onFeedback,
  });

  @override
  State<_ClassActionInspectorPanel> createState() =>
      _ClassActionInspectorPanelState();
}

class _ClassActionInspectorPanelState
    extends State<_ClassActionInspectorPanel> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  NotifType _noticeType = NotifType.roomChange;

  static const List<NotifType> _noticeTypes = [
    NotifType.roomChange,
    NotifType.university,
    NotifType.testReminder,
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final cancelled = widget.controller.isCancelled(e);
    final restoredEligible = widget.controller.isRestoredNoticeEligible(e);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isDockedDesktop) ...[
          UCard(
            isTopLit: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cancelled
                            ? AppColors.errorSoft
                            : AppColors.infoSoft,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                          color: (cancelled ? AppColors.error : AppColors.info)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        cancelled
                            ? 'Cancelled for ${widget.formattedOccurrenceDate}'
                            : 'Scheduled · ${widget.formattedOccurrenceDate}',
                        style: AppTextStyles.badge.copyWith(
                          color: cancelled ? AppColors.error : AppColors.info,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Room ${e.room}',
                      style: AppTextStyles.roomCode.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                AppSpacing.smGap,
                if (e.subjectCode.isNotEmpty)
                  Text(
                    e.subjectCode,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(e.subject, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  '${e.timeLabel} · Batch ${e.batch} · Sec ${e.section}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          AppSpacing.mdGap,
        ],

        // Section 1: Occurrence Status & Cancellation / Undo
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                cancelled ? 'RESTORE CLASS OCCURRENCE' : 'CANCEL THIS OCCURRENCE',
                style: AppTextStyles.labelCaps,
              ),
              AppSpacing.smGap,
              if (cancelled) ...[
                Text(
                  'Restoring this class removes the cancellation badge for ${widget.selectedDayLong}, ${widget.formattedOccurrenceDate}. Note: undoing a cancellation record does not retract previously delivered push notifications.',
                  style: AppTextStyles.bodySm,
                ),
                AppSpacing.mdGap,
                UButton(
                  label: 'Undo cancellation',
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  variant: UButtonVariant.secondary,
                  isLoading: widget.controller.isSubmitting,
                  onPressed: () async {
                    final ok = await widget.controller.undoCancel(e);
                    if (!mounted) return;
                    widget.onFeedback(
                      ok
                          ? (widget.controller.feedbackBannerMessage ??
                              'Cancellation removed.')
                          : (widget.controller.errorMessage ??
                              'Could not undo.'),
                    );
                  },
                ),
                AppSpacing.smGap,
                UButton(
                  label: "Send 'Class Restored' Notice to Cohort",
                  icon: PhosphorIconsRegular.paperPlaneTilt,
                  variant: UButtonVariant.secondary,
                  isLoading: widget.controller.isSubmitting,
                  onPressed: () async {
                    final restored = await widget.controller.undoCancel(e);
                    if (!restored || !mounted) return;
                    final sent =
                        await widget.controller.sendClassRestoredNotice(e);
                    if (!mounted) return;
                    widget.onFeedback(
                      sent
                          ? "Class restored and 'Class Restored' notice sent to cohort."
                          : 'Class restored, but the cohort notice could not be sent.',
                      isWarning: !sent,
                    );
                  },
                ),
              ] else ...[
                Text(
                  'Cancels only ${widget.selectedDayLong}, ${widget.formattedOccurrenceDate} and alerts Batch ${e.batch} · Sec ${e.section}.',
                  style: AppTextStyles.caption,
                ),
                if (restoredEligible) ...[
                  AppSpacing.smGap,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'This occurrence was recently restored. Let students know the class is back on schedule:',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        UButton(
                          label: "Send 'Class Restored' Notice to Cohort",
                          icon: PhosphorIconsRegular.paperPlaneTilt,
                          variant: UButtonVariant.secondary,
                          isLoading: widget.controller.isSubmitting,
                          onPressed: () async {
                            final ok = await widget.controller
                                .sendClassRestoredNotice(e);
                            if (!mounted) return;
                            widget.onFeedback(
                              ok
                                  ? "Sent 'Class Restored' notice to Batch ${e.batch} · Sec ${e.section}."
                                  : (widget.controller.errorMessage ??
                                      'Could not send notice.'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                AppSpacing.mdGap,
                UTextField(
                  controller: _reasonCtrl,
                  label: 'Reason (optional)',
                  hint: 'e.g. Faculty unavailable / rescheduled lab',
                  maxLines: 2,
                ),
                AppSpacing.mdGap,
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.info,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Affects ${widget.formattedOccurrenceDate} only · Recurring weekly routine remains unchanged',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                UButton(
                  label: 'Cancel class',
                  icon: PhosphorIconsRegular.prohibit,
                  variant: UButtonVariant.danger,
                  isLoading: widget.controller.isSubmitting,
                  onPressed: () async {
                    final outcome = await widget.controller
                        .cancelClassWithOutcome(e, _reasonCtrl.text);
                    if (!mounted) return;
                    if (outcome == CancellationOutcome.fullSuccess) {
                      _reasonCtrl.clear();
                      widget.onFeedback(
                        widget.controller.feedbackBannerMessage ??
                            'Class occurrence cancelled and cohort notified.',
                      );
                    } else if (outcome ==
                        CancellationOutcome.partialSuccessNotificationFailed) {
                      _reasonCtrl.clear();
                      widget.onFeedback(
                        widget.controller.feedbackBannerMessage ??
                            'Class cancelled, but cohort alert could not be sent.',
                        isWarning: true,
                      );
                    } else {
                      widget.onFeedback(
                        widget.controller.errorMessage ?? 'Could not cancel.',
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        AppSpacing.mdGap,

        // Section 2: Targeted Cohort Update Composer
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('POST A COHORT UPDATE', style: AppTextStyles.labelCaps),
              const SizedBox(height: 4),
              Text(
                'Target: Batch ${e.batch} · Sec ${e.section} (${e.subject})',
                style: AppTextStyles.caption,
              ),
              AppSpacing.mdGap,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in _noticeTypes)
                    UChip(
                      label: t.label,
                      isActive: _noticeType == t,
                      onTap: () => setState(() => _noticeType = t),
                    ),
                ],
              ),
              AppSpacing.mdGap,
              UTextField(
                controller: _titleCtrl,
                label: 'Title',
                hint: 'Short headline (e.g. Room shifted to 402)',
              ),
              AppSpacing.smGap,
              UTextField(
                controller: _bodyCtrl,
                label: 'Message',
                hint: 'What do students in this cohort need to know?',
                maxLines: 3,
              ),
              AppSpacing.mdGap,
              UButton(
                label: 'Send update',
                icon: PhosphorIconsRegular.paperPlaneTilt,
                isLoading: widget.controller.isSubmitting,
                onPressed: () async {
                  if (_titleCtrl.text.trim().isEmpty ||
                      _bodyCtrl.text.trim().isEmpty) {
                    widget.onFeedback('Add a title and a message first.');
                    return;
                  }
                  final ok = await widget.controller.postNotice(
                    e,
                    type: _noticeType,
                    title: _titleCtrl.text,
                    body: _bodyCtrl.text,
                  );
                  if (!mounted) return;
                  if (ok) {
                    _titleCtrl.clear();
                    _bodyCtrl.clear();
                  }
                  widget.onFeedback(
                    ok
                        ? 'Update sent to students.'
                        : (widget.controller.errorMessage ??
                            'Could not send.'),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
