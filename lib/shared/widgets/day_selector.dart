import 'package:flutter/material.dart';
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
    if (index < 0 || !_scrollController.hasClients) return;
    // Each chip is approximately chipHeight wide + smHGap separator
    const itemWidth = AppSpacing.chipHeight + AppSpacing.sm + AppSpacing.chipPaddingH * 2;
    final offset = index * itemWidth;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}
