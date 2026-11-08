import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_spacing.dart';

// Rooms and Faculty retain their separate durable destinations.
class CampusLookupSwitcher extends StatelessWidget {
  final bool faculty;
  const CampusLookupSwitcher({super.key, this.faculty = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: USegmentedControl<bool>(
          segments: const [
            USegment(
                value: false, label: 'Rooms', icon: PhosphorIconsRegular.door),
            USegment(
                value: true,
                label: 'Faculty',
                icon: PhosphorIconsRegular.chalkboardTeacher),
          ],
          selected: faculty,
          onChanged: (value) =>
              context.go(value ? RouteNames.findTeacher : RouteNames.rooms),
        ),
      );
}
