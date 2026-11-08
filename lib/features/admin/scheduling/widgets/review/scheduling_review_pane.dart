import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Review & Publish pane.
/// Provides a filterable timetable grid (Section, Faculty, Room views),
/// conflict inspector, revision comparison diff, and an atomic publication gate.
class SchedulingReviewPane extends StatefulWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingReviewPane({super.key, required this.controller});

  @override
  State<SchedulingReviewPane> createState() => _SchedulingReviewPaneState();
}

class _SchedulingReviewPaneState extends State<SchedulingReviewPane> {
  int _viewModeIndex =
      0; // 0=Section Grid, 1=Faculty Schedule, 2=Room Occupancy
  String _selectedDay = 'Sunday';
  String _selectedBatch = '2024';
  String _selectedTeacher = 'MSA';
  String _selectedRoom = 'RAB-201';

  final List<String> _teachers = [
    'MSA',
    'FK',
    'NJ',
    'MHR',
    'SR',
    'TI',
    'MM',
    'SH',
    'FA',
  ];
  final List<String> _rooms = [
    'RAB-201',
    'RAB-202',
    'RAB-301',
    'SW-LAB-1',
    'PHY-LAB',
  ];

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
  ];
  final List<String> _periods = [
    '09:00-09:50',
    '10:00-10:50',
    '11:00-11:50',
    '12:00-13:00 (Break)',
    '13:00-13:50',
    '14:00-14:50',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final rows = SchedulingPreviewFixtures.candidateRoutineRows;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _buildViewSelector(),
            const SizedBox(height: AppSpacing.lg),
            _buildTimetableGridCard(rows),
            const SizedBox(height: AppSpacing.lg),
            _buildConflictInspectorCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildRevisionComparisonCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildAtomicPublishGateCard(context),
          ],
        );
      },
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Row(
        children: [
          _viewTab('Section Grid', PhosphorIconsRegular.gridFour, 0),
          const SizedBox(width: AppSpacing.xs),
          _viewTab('Faculty Schedule', PhosphorIconsRegular.users, 1),
          const SizedBox(width: AppSpacing.xs),
          _viewTab('Room Occupancy', PhosphorIconsRegular.door, 2),
          const Spacer(),
          // View-specific entity selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _viewModeIndex == 0
                      ? 'Batch: '
                      : _viewModeIndex == 1
                          ? 'Faculty: '
                          : 'Room: ',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                DropdownButtonHideUnderline(
                  child: _viewModeIndex == 0
                      ? DropdownButton<String>(
                          value: _selectedBatch,
                          isDense: true,
                          dropdownColor: AppColors.bgCard,
                          items: ['2021', '2022', '2023', '2024'].map((b) {
                            return DropdownMenuItem(
                              value: b,
                              child: Text(
                                'Batch $b',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBatch = val);
                            }
                          },
                        )
                      : _viewModeIndex == 1
                          ? DropdownButton<String>(
                              value: _selectedTeacher,
                              isDense: true,
                              dropdownColor: AppColors.bgCard,
                              items: _teachers.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedTeacher = val);
                                }
                              },
                            )
                          : DropdownButton<String>(
                              value: _selectedRoom,
                              isDense: true,
                              dropdownColor: AppColors.bgCard,
                              items: _rooms.map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedRoom = val);
                                }
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewTab(String label, IconData icon, int index) {
    final active = _viewModeIndex == index;
    return InkWell(
      onTap: () => setState(() => _viewModeIndex = index),
      borderRadius: AppSpacing.radiusSm,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.snappy,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: AppSpacing.radiusSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableGridCard(List<RoutineEntry> allRows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Day selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.calendarCheck,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _viewModeIndex == 0
                      ? 'CANDIDATE ROUTINE GRID · BATCH $_selectedBatch'
                      : _viewModeIndex == 1
                          ? 'FACULTY SCHEDULE TIMELINE · $_selectedTeacher'
                          : 'ROOM OCCUPANCY SCHEDULE · $_selectedRoom',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Day chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _days.map((day) {
                      final isSelected = _selectedDay == day;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedDay = day),
                          selectedColor: AppColors.primarySoft,
                          backgroundColor: AppColors.bgElevated,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Day's schedule timeline
          UAnimatedSwap(
            child: KeyedSubtree(
              key: ValueKey(
                  '$_viewModeIndex-$_selectedDay-$_selectedBatch-$_selectedTeacher-$_selectedRoom'),
              child: _buildDayScheduleView(allRows),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayScheduleView(List<RoutineEntry> allRows) {
    final dayRows = allRows.where((r) {
      if (r.day != _selectedDay) return false;
      if (_viewModeIndex == 0) return r.batch == _selectedBatch;
      if (_viewModeIndex == 1) {
        return r.teacherCode == _selectedTeacher ||
            r.coTeacherCodes.contains(_selectedTeacher);
      }
      return r.room == _selectedRoom;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: _periods.map((period) {
          final isLunchBreak = period.contains('Break');
          final matchingEntries = dayRows.where((r) {
            final start = r.timeStart.replaceAll(':', '');
            final pStart = period.substring(0, 5).replaceAll(':', '');
            return start == pStart;
          }).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isLunchBreak ? AppColors.bgElevated : AppColors.bgPrimary,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(
                color: isLunchBreak
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                // Period time badge
                SizedBox(
                  width: 160,
                  child: Row(
                    children: [
                      Icon(
                        isLunchBreak
                            ? PhosphorIconsRegular.coffee
                            : PhosphorIconsRegular.clock,
                        size: 13,
                        color: isLunchBreak
                            ? AppColors.warning
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          period,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLunchBreak
                                ? AppColors.warning
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                const SizedBox(width: AppSpacing.md),
                // Period Content
                Expanded(
                  child: isLunchBreak
                      ? const Text(
                          'PRAYER & LUNCH BREAK (R15 · University-wide pause)',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        )
                      : matchingEntries.isEmpty
                          ? const Text(
                              'Free / Unscheduled Slot',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: matchingEntries
                                  .map((e) => _classBadge(e))
                                  .toList(),
                            ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _classBadge(RoutineEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            e.subjectCode,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'Sec ${e.section}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            e.teacherCode ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              e.room,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictInspectorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Icon(
              PhosphorIconsRegular.shieldCheck,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflict Inspector: Zero Hard Collisions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '0 room double-bookings · 0 faculty time overlaps · 0 cohort section collisions · 0 sessional break-crossings.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Text(
              'AUDIT CLEAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.gitDiff,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'REVISION COMPARISON (CANDIDATE VS CURRENT PUBLISHED)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Comparing vs Active Routine #3',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _diffRow(
            '+',
            'Joint Section CSE-2201 (A+B) co-teaching MSA / FK applied per Chair resolution',
            AppColors.success,
          ),
          _diffRow(
            '+',
            'Service course EEE-2205 assigned to 92-seat lecture hall RAB-301',
            AppColors.success,
          ),
          _diffRow(
            '~',
            'Physics Lab (PHY-1104) shifted to Sunday afternoon per shared lab calendar',
            AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _diffRow(String symbol, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtomicPublishGateCard(BuildContext context) {
    final isPublished = widget.controller.publishedConfirmationId != null;
    final isPublishing = widget.controller.isPublishing;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isPublished ? AppColors.successSoft : AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isPublished ? AppColors.success : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPublished
                    ? PhosphorIconsRegular.checkFat
                    : PhosphorIconsRegular.lockKey,
                size: 20,
                color: isPublished ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPublished
                          ? 'ROUTINE PUBLISHED TO CAMPUS'
                          : 'SERVER-AUTHORITATIVE ATOMIC PUBLICATION GATE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: isPublished
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPublished
                          ? 'Confirmation Token: ${widget.controller.publishedConfirmationId} · Routine versions table updated atomically.'
                          : 'Publishing will atomically activate this routine across all student and teacher portals, binding to Revision #${widget.controller.revision.revisionNumber}.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPublished) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: isPublishing
                      ? null
                      : () => _confirmPublishDialog(context),
                  icon: isPublishing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Icon(PhosphorIconsRegular.uploadSimple, size: 16),
                  label: Text(
                    isPublishing ? 'Publishing…' : 'Publish to Campus',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _confirmPublishDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.warning,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Confirm Routine Publication', style: AppTextStyles.h4),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to publish the generated routine for CSE Fall 2026. This will:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '• Atomically activate version #4 for all students & teachers.\n'
              '• Supersede current active routine #3.\n'
              '• Record an authoritative audit log with your digital signature.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.controller.simulatePublishRoutine();
            },
            child: const Text('Confirm & Publish Atomically'),
          ),
        ],
      ),
    );
  }
}
