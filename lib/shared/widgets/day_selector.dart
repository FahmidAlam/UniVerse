import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/shared/widgets/u_chip.dart';

class DaySelector extends StatefulWidget {
  final String selectedDay;
  final ValueChanged<String> onSelect;
  final List<String> days;

  const DaySelector({
    super.key,
    required this.selectedDay,
    required this.onSelect,
    this.days = AppConstants.weekDaysShort,
  });

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final index = widget.days.indexOf(widget.selectedDay);
    if (!mounted || index < 0 || !_scrollController.hasClients) return;
    const itemWidth =
        AppSpacing.chipHeight + AppSpacing.sm + AppSpacing.chipPaddingH * 2;
    final offset = index * itemWidth;
    final target =
        offset.clamp(0.0, _scrollController.position.maxScrollExtent);
    if (AppMotion.reduced(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(target,
          duration: AppMotion.fast, curve: AppMotion.snappy);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 220) return;
        final currentIndex = widget.days.indexOf(widget.selectedDay);
        if (currentIndex < 0) return;
        // Swipe left -> next day; swipe right -> previous day
        final nextIndex = velocity < 0 ? currentIndex + 1 : currentIndex - 1;
        if (nextIndex >= 0 && nextIndex < widget.days.length) {
          AppMotion.selectionHaptic(context);
          widget.onSelect(widget.days[nextIndex]);
        }
      },
      child: SizedBox(
        height: AppSpacing.chipHeight,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.days.length,
          separatorBuilder: (_, __) => AppSpacing.smHGap,
          itemBuilder: (_, i) {
            final day = widget.days[i];
            return UChip(
              label: day,
              isActive: widget.selectedDay == day,
              onTap: () => widget.onSelect(day),
            );
          },
        ),
      ),
    );
  }
}
