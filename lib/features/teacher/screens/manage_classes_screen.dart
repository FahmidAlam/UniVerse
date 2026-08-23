// ============================================================
// FILE: lib/features/teacher/screens/manage_classes_screen.dart
// PURPOSE: Teacher "Classes" tab. The teacher's weekly schedule
// with a day selector; tapping a class opens an action sheet to
// cancel it (alerts the cohort + records a cancellation), undo a
// cancellation, or post a room-change / notice / test-reminder.
// Tab screen: owns its Scaffold + UAppBar(showBackButton:false);
// AppShell supplies the bottom nav. Screen → controller →
// TeacherService — no Supabase here.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/teacher/controllers/manage_classes_controller.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class ManageClassesScreen extends StatefulWidget {
  final AuthController authController;

  const ManageClassesScreen({super.key, required this.authController});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  late final ManageClassesController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        ManageClassesController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _selectedDayLong {
    final i = AppConstants.weekDaysShort.indexOf(_controller.selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _controller.selectedDay;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodySm),
        backgroundColor: AppColors.bgElevated,
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DaySelector(
                      selectedDay: _controller.selectedDay,
                      onSelect: _controller.setDay,
                    ),
                    AppSpacing.smGap,
                    Text(
                      'Actions apply to $_selectedDayLong · '
                      '${AppDateUtils.shortDate(_controller.selectedOccurrenceDate)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: _controller.load,
                  child: _buildBody(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
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
        child: UEmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Something went wrong',
          message: _controller.errorMessage,
          action: UButton(
            label: 'Retry',
            icon: PhosphorIconsRegular.arrowClockwise,
            variant: UButtonVariant.secondary,
            fullWidth: false,
            onPressed: _controller.load,
          ),
        ),
      );
    }

    final entries = _controller.entriesForSelectedDay;
    if (entries.isEmpty) {
      return const ScrollableEmpty(
        child: UEmptyState(
          icon: PhosphorIconsRegular.calendarBlank,
          title: 'No classes',
          message: 'You have nothing scheduled for this day.',
        ),
      );
    }

    final now = DateTime.now();
    final isToday = _controller.isSelectedDayToday;

    return ListView.separated(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => AppSpacing.cardGap,
      itemBuilder: (context, i) {
        final e = entries[i];
        final cancelled = _controller.isCancelled(e);
        final status = cancelled
            ? ClassStatus.cancelled
            : (isToday ? e.statusOn(now, isToday: true) : ClassStatus.upcoming);

        return ClassCard(
          subject: e.subject,
          teacher: e.teacherDisplay,
          room: e.room,
          timeSlot: e.timeLabel,
          status: status,
          batch: e.batch,
          section: e.section,
          onTap: () => _openActions(e),
        );
      },
    );
  }

  // ─── Action sheet ─────────────────────────────────────────
  void _openActions(RoutineEntry e) {
    final cancelled = _controller.isCancelled(e);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Grabber(),
              AppSpacing.mdGap,
              Text(e.subject, style: AppTextStyles.h3, maxLines: 2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${e.timeLabel} · Batch ${e.batch} · Sec ${e.section}',
                style: AppTextStyles.caption,
              ),
              AppSpacing.sectionGap,
              if (cancelled)
                _ActionRow(
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  color: AppColors.info,
                  title: 'Undo cancellation',
                  subtitle: 'Restore this class occurrence',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _doUndo(e);
                  },
                )
              else
                _ActionRow(
                  icon: PhosphorIconsRegular.prohibit,
                  color: AppColors.error,
                  title: 'Cancel this class',
                  subtitle: 'Alert Batch ${e.batch} · Sec ${e.section}',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmCancel(e);
                  },
                ),
              AppSpacing.smGap,
              _ActionRow(
                icon: PhosphorIconsRegular.megaphone,
                color: AppColors.primary,
                title: 'Post an update',
                subtitle: 'Room change, notice or test reminder',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _composeNotice(e);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doUndo(RoutineEntry e) async {
    final ok = await _controller.undoCancel(e);
    _snack(ok
        ? 'Cancellation removed.'
        : (_controller.errorMessage ?? 'Could not undo.'));
  }

  // ─── Cancel sheet (with reason) ───────────────────────────
  void _confirmCancel(RoutineEntry e) {
    final reasonCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Grabber(),
                AppSpacing.mdGap,
                Text('Cancel ${e.subject}?', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Students in Batch ${e.batch} · Sec ${e.section} will be '
                  'alerted for $_selectedDayLong, '
                  '${AppDateUtils.shortDate(_controller.selectedOccurrenceDate)}.',
                  style: AppTextStyles.caption,
                ),
                AppSpacing.lgGap,
                UTextField(
                  controller: reasonCtrl,
                  label: 'Reason (optional)',
                  hint: 'e.g. Faculty unavailable',
                  maxLines: 3,
                ),
                AppSpacing.lgGap,
                ListenableBuilder(
                  listenable: _controller,
                  builder: (_, __) => UButton(
                    label: 'Cancel class',
                    icon: PhosphorIconsRegular.prohibit,
                    variant: UButtonVariant.danger,
                    isLoading: _controller.isSubmitting,
                    onPressed: () async {
                      final navigator = Navigator.of(ctx);
                      final ok =
                          await _controller.cancelClass(e, reasonCtrl.text);
                      if (!mounted) return;
                      navigator.pop();
                      _snack(ok
                          ? 'Class cancelled — students notified.'
                          : (_controller.errorMessage ??
                              'Could not cancel.'));
                    },
                  ),
                ),
                AppSpacing.smGap,
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(reasonCtrl.dispose);
  }

  // ─── Compose update sheet (room change / notice / test) ───
  void _composeNotice(RoutineEntry e) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var type = NotifType.roomChange;

    const types = [
      NotifType.roomChange,
      NotifType.university,
      NotifType.testReminder,
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Grabber(),
                  AppSpacing.mdGap,
                  Text('Post an update', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'To Batch ${e.batch} · Sec ${e.section} — ${e.subject}',
                    style: AppTextStyles.caption,
                  ),
                  AppSpacing.lgGap,
                  Text('TYPE', style: AppTextStyles.labelCaps),
                  AppSpacing.smGap,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final t in types)
                        UChip(
                          label: t.label,
                          isActive: type == t,
                          onTap: () => setSheet(() => type = t),
                        ),
                    ],
                  ),
                  AppSpacing.lgGap,
                  UTextField(
                    controller: titleCtrl,
                    label: 'Title',
                    hint: 'Short headline',
                  ),
                  AppSpacing.mdGap,
                  UTextField(
                    controller: bodyCtrl,
                    label: 'Message',
                    hint: 'What do students need to know?',
                    maxLines: 4,
                  ),
                  AppSpacing.lgGap,
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (_, __) => UButton(
                      label: 'Send update',
                      icon: PhosphorIconsRegular.paperPlaneTilt,
                      isLoading: _controller.isSubmitting,
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty ||
                            bodyCtrl.text.trim().isEmpty) {
                          _snack('Add a title and a message first.');
                          return;
                        }
                        final navigator = Navigator.of(ctx);
                        final ok = await _controller.postNotice(
                          e,
                          type: type,
                          title: titleCtrl.text,
                          body: bodyCtrl.text,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        _snack(ok
                            ? 'Update sent to students.'
                            : (_controller.errorMessage ??
                                'Could not send.'));
                      },
                    ),
                  ),
                  AppSpacing.smGap,
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      bodyCtrl.dispose();
    });
  }
}

// ─── A tappable action row inside the bottom sheet ──────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppSpacing.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: AppSpacing.x4l,
                height: AppSpacing.x4l,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.radiusMd,
                ),
                child: Icon(icon, size: AppSpacing.iconMd, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: AppSpacing.iconSm,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom-sheet grabber handle ────────────────────────────
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSpacing.x4l,
        height: AppSpacing.xs,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppSpacing.radiusFull,
        ),
      ),
    );
  }
}
