import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

enum WorkspaceLayoutTier { compact, medium, expanded }

/// Measures post-sidebar usable width via [LayoutBuilder] and adapts between:
/// - Compact (`< 700px`): Single-axis vertical mobile layout
/// - Medium (`700..959px`): Centered bounded column (`maxWidth: 820`)
/// - Expanded (`>= 960px`): Asymmetric 2-column desktop workbench (`62 / 38`)
class UResponsiveWorkspace extends StatelessWidget {
  final Widget primary;
  final Widget? secondary;
  final Widget? header;
  final int primaryFlex;
  final int secondaryFlex;
  final double mediumMaxWidth;
  final EdgeInsetsGeometry? compactPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const UResponsiveWorkspace({
    super.key,
    required this.primary,
    this.secondary,
    this.header,
    this.primaryFlex = 62,
    this.secondaryFlex = 38,
    this.mediumMaxWidth = 820,
    this.compactPadding,
    this.desktopPadding,
  });

  static WorkspaceLayoutTier tierForWidth(double usableWidth) {
    if (usableWidth < 700) return WorkspaceLayoutTier.compact;
    if (usableWidth < 960) return WorkspaceLayoutTier.medium;
    return WorkspaceLayoutTier.expanded;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final tier = tierForWidth(usableWidth);

        if (tier == WorkspaceLayoutTier.compact) {
          return Padding(
            padding: compactPadding ?? AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  header!,
                  const SizedBox(height: AppSpacing.md),
                ],
                Expanded(child: primary),
                if (secondary != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  secondary!,
                ],
              ],
            ),
          );
        }

        if (tier == WorkspaceLayoutTier.medium || secondary == null) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: tier == WorkspaceLayoutTier.medium
                    ? mediumMaxWidth
                    : double.infinity,
              ),
              child: Padding(
                padding: desktopPadding ?? const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null) ...[
                      header!,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Expanded(child: primary),
                    if (secondary != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      secondary!,
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: desktopPadding ?? const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header!,
                const SizedBox(height: AppSpacing.lg),
              ],
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: primaryFlex, child: primary),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(flex: secondaryFlex, child: secondary!),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Master-detail desktop workbench primitive that docks a detail inspector on
/// wide viewports (`>= 960px`) and collapses to the master pane on compact/medium.
class UMasterDetailWorkspace extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final double detailWidth;

  const UMasterDetailWorkspace({
    super.key,
    required this.master,
    this.detail,
    this.detailWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        if (usableWidth >= 960 && detail != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: master),
              const SizedBox(width: AppSpacing.xxl),
              SizedBox(width: detailWidth, child: detail!),
            ],
          );
        }
        return master;
      },
    );
  }
}

/// Responsive card collection that renders a single-column vertical `ListView`
/// on compact widths (`< 640px` usable width) and a 2-column (`640..1040px`)
/// or 3-column (`> 1040px`) `GridView.builder` on tablet/desktop viewports.
class UAdaptiveCardGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double mainAxisExtent;
  final double spacing;
  final double singleColumnBreakpoint;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const UAdaptiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisExtent = 324,
    this.spacing = AppSpacing.lg,
    this.singleColumnBreakpoint = 640,
    this.padding,
    this.physics,
  });

  static int columnsForWidth(
    double usableWidth, {
    double singleColumnBreakpoint = 640,
  }) {
    if (usableWidth < singleColumnBreakpoint) return 1;
    if (usableWidth <= 1040) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = columnsForWidth(
          usableWidth,
          singleColumnBreakpoint: singleColumnBreakpoint,
        );

        if (columns == 1) {
          return ListView.builder(
            physics: physics,
            padding:
                padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }

        return GridView.builder(
          physics: physics,
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: mainAxisExtent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// Unified desktop/mobile search and filter bar with animated focus glow,
/// live result count pill (`Showing X of Y`), and a `/` shortcut hint on desktop (`>= 768px`).
class USearchFilterBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? statusPillLabel;
  final List<Widget>? filters;
  final FocusNode? focusNode;

  const USearchFilterBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.statusPillLabel,
    this.filters,
    this.focusNode,
  });

  @override
  State<USearchFilterBar> createState() => _USearchFilterBarState();
}

class _USearchFilterBarState extends State<USearchFilterBar> {
  FocusNode? _internalFocusNode;
  bool _focused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_handleGlobalSlashKey);
  }

  void _onFocusChange() {
    if (!mounted) return;
    final next = _focusNode.hasFocus;
    if (_focused != next) {
      setState(() => _focused = next);
    }
  }

  bool _handleGlobalSlashKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.slash) return false;
    if (_focusNode.hasFocus) return false;
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context?.widget is EditableText) return false;
    _focusNode.requestFocus();
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalSlashKey);
    _focusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.micro),
                curve: AppMotion.snappy,
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.radiusMd,
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  style: AppTextStyles.input.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: AppColors.textSecondary,
                      size: AppSpacing.iconMd,
                    ),
                    suffixIcon: isDesktop && !_focused
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: UnconstrainedBox(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: AppSpacing.radiusSm,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '/',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : widget.controller.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  widget.controller.clear();
                                  widget.onChanged?.call('');
                                },
                              )
                            : null,
                  ),
                ),
              ),
            ),
            if (widget.statusPillLabel != null) ...[
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSubtle,
                  borderRadius: AppSpacing.radiusFull,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  widget.statusPillLabel!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.filters != null && widget.filters!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < widget.filters!.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  widget.filters![i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
