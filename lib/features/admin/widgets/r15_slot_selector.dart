import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

class R15SlotSelector extends StatefulWidget {
  final ValueChanged<int> onChanged;
  final Future<TimetableSettings> Function()? settingsLoader;
  const R15SlotSelector(
      {super.key, required this.onChanged, this.settingsLoader});
  @override
  State<R15SlotSelector> createState() => _R15SlotSelectorState();
}

class _R15SlotSelectorState extends State<R15SlotSelector> {
  int _count = 6;
  bool _edited = false;
  String _source = 'Loading configured grid';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await (widget.settingsLoader ??
          TimetableConfigService().fetchSettings)();
      final count = settings.periods.whereType<Map>().length;
      if (!mounted || _edited) return;
      setState(() {
        _count = count == 7 ? 7 : 6;
        _source =
            count == 6 || count == 7 ? 'Configured grid' : 'Default preview';
      });
      widget.onChanged(_count);
    } catch (_) {
      if (mounted) {
        setState(() => _source = 'Configuration unavailable - default preview');
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('R15 - $_source - $_count teaching slots'),
        const SizedBox(height: 8),
        USegmentedControl<int>(
            selected: _count,
            segments: const [
              USegment(value: 6, label: '6 Slots'),
              USegment(value: 7, label: '7 Slots')
            ],
            onChanged: (count) {
              setState(() {
                _edited = true;
                _count = count;
                _source = 'Preview grid';
              });
              widget.onChanged(count);
            }),
        const SizedBox(height: 8),
        const Text(
            'Matrix edits remain in this session. Switching grids preserves hidden slot selections.'),
      ]);
}
