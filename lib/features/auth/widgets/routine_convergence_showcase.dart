import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 3: Local illustrative instrument, never solver or database output.
class RoutineConvergenceShowcase extends StatefulWidget {
  const RoutineConvergenceShowcase(
      {super.key,
      this.stage,
      this.onStageChanged,
      this.compact = false,
      this.interactive = true,
      this.previewBatch,
      this.previewSection,
      this.previewTeacherCode});
  final int? stage;
  final ValueChanged<int>? onStageChanged;
  final bool compact, interactive;
  final String? previewBatch, previewSection, previewTeacherCode;
  static const titles = [
    'Intelligent Routine Generation',
    'Your University Routine, Made Clear',
    'Your Academic Life, Connected'
  ];
  @override
  State<RoutineConvergenceShowcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<RoutineConvergenceShowcase>
    with TickerProviderStateMixin {
  late final _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final List<CurvedAnimation> _sourceMotions = List.generate(
      3,
      (i) => CurvedAnimation(
          parent: _entrance,
          curve: Interval(i * .16, .65 + i * .16, curve: Curves.easeOutCubic)));
  int _selected = 0;
  int get stage => widget.stage ?? _selected;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // PHASE 3: Runtime ambient motion; accessibility pins a complete rest frame.
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _ambient.stop();
      _ambient.value = .42;
      _entrance.stop();
      _entrance.value = 1;
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    for (final animation in _sourceMotions) {
      animation.dispose();
    }
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Widget card(String title, String detail, Color accent,
          {IconData icon = Icons.school_outlined}) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.instrumentTop,
                    AppColors.instrumentBottom
                  ]),
              border: Border.all(color: accent.withValues(alpha: .4)),
              boxShadow: AppColors.dualElevationShadow),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: AppTextStyles.bodySm
                              .copyWith(fontWeight: FontWeight.w600)))
                ]),
                const SizedBox(height: 10),
                Text(detail, style: AppTextStyles.caption),
              ]));
  Widget matrix() => CustomPaint(
      foregroundPainter: _MatrixPulsePainter(_ambient),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 46),
          for (final day in ['Sun', 'Mon', 'Tue', 'Wed'])
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(day, style: AppTextStyles.caption)))
        ]),
        for (var r = 0; r < 3; r++)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(
                    width: 46,
                    child: Text(['08:50', '10:20', '01:50'][r],
                        style: AppTextStyles.caption)),
                for (var c = 0; c < 4; c++)
                  Expanded(
                      child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: [
                                AppColors.primary,
                                AppColors.success,
                                AppColors.info
                              ][(r + c) % 3]
                                  .withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: [
                                AppColors.primary,
                                AppColors.success,
                                AppColors.info
                              ][(r + c) % 3]
                                      .withValues(alpha: .4))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    [
                                      'CSE-3101 · B+C',
                                      'CSE-3102 Lab',
                                      'CSE-3105 · CSE'
                                    ][(r + c) % 3],
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(
                                    [
                                      'Rm 302 · MSR',
                                      'ACL-1 · Sec B1',
                                      'Rm 401 · JR'
                                    ][(r + c) % 3],
                                    style: AppTextStyles.caption),
                              ]))),
              ])),
      ]));
  Widget generation() => Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: FadeTransition(
                  opacity: _sourceMotions[0],
                  child: card(
                      'Course Distribution · Batch 58 (B+C)',
                      'CSE-3101 · 3.0 Cr\n23 Offerings · A–L Provenance',
                      AppColors.primary))),
          const SizedBox(width: 8),
          Expanded(
              child: FadeTransition(
                  opacity: _sourceMotions[1],
                  child: card('Faculty Windows & Off-Days',
                      'MSR · JR · SJK\nOff-Day Constraints', AppColors.info,
                      icon: Icons.person_outline))),
          const SizedBox(width: 8),
          Expanded(
              child: FadeTransition(
                  opacity: _sourceMotions[2],
                  child: card('Room & Lab Pools · 302 / ACL-1',
                      'Theory 302/401\nLabs ACL-1/ECL', AppColors.success,
                      icon: Icons.meeting_room_outlined))),
        ]),
        SizedBox(
            height: 176,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                  child: CustomPaint(
                      painter: _ConvergenceConduitPainter(_ambient, stage: 0))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.bgSubtle,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: .6))),
                  child: Text('UniVerse Orbit Engine',
                      style: AppTextStyles.bodySm)),
            ])),
        matrix(),
      ]);
  Widget lens() {
    final batch = widget.previewBatch?.trim();
    final section = widget.previewSection?.trim().toUpperCase();
    final code = widget.previewTeacherCode?.trim().toUpperCase();
    final lensBanner = UAnimatedSwap(
      child: code != null && code.isNotEmpty
          ? KeyedSubtree(
              key: ValueKey('faculty:$code'),
              child: card(
                  'LIVE FACULTY LENS: [$code] Teaching Slots & Class Tools Linked',
                  'Illustrative local input match',
                  AppColors.info))
          : (batch?.isNotEmpty ?? false) || (section?.isNotEmpty ?? false)
              ? KeyedSubtree(
                  key: ValueKey('student:$batch:$section'),
                  child: card(
                      'LIVE LENS: Batch ${batch?.isNotEmpty == true ? batch : '?'} \u00b7 Section ${section?.isNotEmpty == true ? section : '?'} Routine Linked',
                      'Personalized daily schedule, room availability & class alerts',
                      AppColors.primary))
              : const SizedBox.shrink(key: ValueKey('empty-lens')),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (AppMotion.reduced(context))
        lensBanner
      else
        AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.snappy,
          alignment: Alignment.topCenter,
          child: lensBanner,
        ),
      const SizedBox(height: 16),
      card(
          'Student · Next Class',
          'LIVE NOW · 10:30 – 11:50\nCSE-3101 · Database Systems',
          AppColors.primary,
          icon: Icons.schedule),
      const SizedBox(height: 12),
      SizedBox(
          height: 4,
          child: CustomPaint(
              painter: _LensTrackPainter(_ambient),
              child: const SizedBox.expand())),
      const SizedBox(height: 12),
      Text('CSE-3101 · Room 302', style: AppTextStyles.bodySm),
      const SizedBox(height: 8),
      Text('Batch ${batch?.isNotEmpty == true ? batch : '58'} · Section ${section?.isNotEmpty == true ? section : 'B'}',
          style: AppTextStyles.caption),
      const SizedBox(height: 20),
      Padding(
          padding: const EdgeInsets.only(left: 32),
          child: card(
              'Teacher · Teaching schedule',
              '${code?.isNotEmpty == true ? code : 'JR'} · Published slots, rooms and daily planning',
              AppColors.info,
              icon: Icons.person_outline)),
      const SizedBox(height: 16),
      matrix(),
    ]);
  }

  Widget campus() => Column(children: [
        card(
            'Date-Scoped Class Update',
            'Mon, Nov 9 · CSE-3102 Lab occurrence notice · Instant cohort alert',
            AppColors.warning,
            icon: Icons.notifications_outlined),
        SizedBox(
            height: 100,
            child: CustomPaint(
                painter: _ConvergenceConduitPainter(_ambient, stage: 2),
                child: const SizedBox.expand())),
        card(
            'Room & Faculty lookup',
            'Schedule-Derived Room & Faculty Lookup\nRm 302 · Free Now   /   ACL-1 · In Lab   /   MSR · In 302',
            AppColors.success,
            icon: Icons.search),
        const SizedBox(height: 16),
        card(
            'Semester course resources',
            'Semester Learning Resources\nSemester 5 Folder · Slides, Lab Sheets & References',
            AppColors.info,
            icon: Icons.folder_outlined),
      ]);
  Widget _stageContent() => switch (stage) {
        0 => generation(),
        1 => lens(),
        _ => campus(),
      };

  @override
  Widget build(BuildContext context) {
    Widget instrument = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UNIVERSE ENGINE · LEADING UNIVERSITY CSE',
              style: AppTextStyles.caption.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 16),
          if (widget.interactive)
            Column(children: [
              USegmentedControl<int>(
                segments: const [
                  USegment(value: 0, label: '01'),
                  USegment(value: 1, label: '02'),
                  USegment(value: 2, label: '03'),
                ],
                selected: stage,
                accentColor: [
                  AppColors.primary,
                  AppColors.info,
                  AppColors.success
                ][stage],
                onChanged: (value) {
                  if (widget.stage == null) setState(() => _selected = value);
                  widget.onStageChanged?.call(value);
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                for (final label in ['Generation', 'Daily Lens', 'Campus Sync'])
                  Expanded(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption)),
              ]),
            ]),
          const SizedBox(height: 20),
          if (!widget.compact) ...[
            UAnimatedSwap(
              duration: AppMotion.fast,
              child: Text(
                RoutineConvergenceShowcase.titles[stage],
                key: ValueKey<String>(RoutineConvergenceShowcase.titles[stage]),
                style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24)
          ],
          if (AppMotion.reduced(context))
            KeyedSubtree(
              key: ValueKey<int>(stage),
              child: _stageContent(),
            )
          else
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.magnetic,
              alignment: Alignment.topCenter,
              child: UAnimatedSwap(
                axis: Axis.horizontal,
                duration: const Duration(milliseconds: 420),
                child: KeyedSubtree(
                  key: ValueKey<int>(stage),
                  child: widget.compact
                      ? _stageContent()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0007)
                            ..rotateX(-0.02 + stage * 0.005)
                            ..rotateY(0.025 - stage * 0.012),
                          child: _stageContent(),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
              'Illustrative preview · Published routines depend on departmental approval',
              style: AppTextStyles.caption),
        ]);
    if (widget.compact) {
      instrument = SizedBox(
          height: 340,
          child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(width: 660, child: instrument)));
    }
    return RepaintBoundary(
        child: CustomPaint(
            painter: _InstrumentCanvas(stage),
            child:
                Padding(padding: const EdgeInsets.all(12), child: instrument)));
  }
}

class _InstrumentCanvas extends CustomPainter {
  _InstrumentCanvas(this.stage);
  final int stage;
  @override
  void paint(Canvas canvas, Size size) {
    final color = [AppColors.primary, AppColors.info, AppColors.success][stage];
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
                  colors: [color.withValues(alpha: .08), Colors.transparent])
              .createShader(Offset.zero & size));
    final p = Paint()..color = AppColors.border.withValues(alpha: .45);
    for (double x = 0; x < size.width; x += 24) {
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), .8, p);
      }
    }
  }

  @override
  bool shouldRepaint(_InstrumentCanvas oldDelegate) =>
      stage != oldDelegate.stage;
}

class _ConvergenceConduitPainter extends CustomPainter {
  _ConvergenceConduitPainter(this.motion, {required this.stage})
      : super(repaint: motion);
  final Animation<double> motion;
  final int stage;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [AppColors.primary, AppColors.info, AppColors.success];
    for (var i = 0; i < 7; i++) {
      final input = i < 3;
      final x = size.width * (input ? (i + .5) / 3 : (i - 3 + .5) / 4);
      final start = input ? Offset(x, 0) : center;
      final end = input ? center : Offset(x, size.height);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, size.height * .42, end.dx, size.height * .58,
            end.dx, end.dy);
      final color = colors[i % 3];
      canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      final metric = path.computeMetrics().first;
      final pos = metric
          .getTangentForOffset(metric.length * ((motion.value + i * .13) % 1))!
          .position;
      canvas.drawCircle(
          pos,
          9,
          Paint()
            ..shader = RadialGradient(
                    colors: [color.withValues(alpha: .4), Colors.transparent])
                .createShader(Rect.fromCircle(center: pos, radius: 9)));
      canvas.drawCircle(pos, 2, Paint()..color = color);
    }
    for (var ring = 0; ring < 2; ring++) {
      final radius = ring == 0 ? 52.0 : 68.0;
      final angle = motion.value * math.pi * 2 * (ring == 0 ? 1 : -1);
      for (var n = 0; n < 12; n++) {
        canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            angle + n * math.pi / 6,
            .17,
            false,
            Paint()
              ..color = colors[ring].withValues(alpha: .6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
      canvas.drawCircle(
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          3,
          Paint()..color = colors[ring]);
    }
  }

  @override
  bool shouldRepaint(_ConvergenceConduitPainter oldDelegate) =>
      oldDelegate.motion != motion || oldDelegate.stage != stage;
}

// PHASE 3: Paint-only telemetry keeps text and form layouts out of frame updates.
class _MatrixPulsePainter extends CustomPainter {
  _MatrixPulsePainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    final slot = (motion.value * 12).floor().clamp(0, 11);
    final width = (size.width - 46) / 4;
    final height = (size.height - 36) / 3;
    final rect = Rect.fromLTWH(49 + (slot % 4) * width,
        36 + (slot ~/ 4) * height, width - 6, height - 6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.primary.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(_MatrixPulsePainter oldDelegate) =>
      oldDelegate.motion != motion;
}

class _LensTrackPainter extends CustomPainter {
  _LensTrackPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.border);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * .62, size.height),
        Paint()..color = AppColors.primary.withValues(alpha: .6));
    final x = motion.value * size.width;
    canvas.drawRect(Rect.fromLTWH(x, 0, 24, size.height),
        Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_LensTrackPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
