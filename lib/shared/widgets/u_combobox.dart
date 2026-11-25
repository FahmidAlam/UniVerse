import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

/// Item definition for [UCombobox].
class UComboboxItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;

  const UComboboxItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.trailing,
  });
}

/// PHASE B / C: Design Term #17 Searchable Combobox.
/// Features concentric radii (outer container 12px, item 8px),
/// 180ms entrance / 140ms (20% shorter) exit animation,
/// type-ahead real-time search, keyboard navigation (Arrow Up/Down, Enter, Esc),
/// and zero-match fallback.
class UCombobox<T> extends StatefulWidget {
  final String? label;
  final String hint;
  final T? value;
  final List<UComboboxItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool allowClear;
  final String? errorText;
  final IconData? prefixIcon;

  const UCombobox({
    super.key,
    this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.allowClear = true,
    this.errorText,
    this.prefixIcon,
  });

  @override
  State<UCombobox<T>> createState() => _UComboboxState<T>();
}

const Object _kComboboxClearSentinel = Object();

class _UComboboxState<T> extends State<UCombobox<T>> {
  bool _isFocused = false;

  UComboboxItem<T>? get _selectedItem {
    if (widget.value == null) return null;
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  Future<void> _openSearchDialog() async {
    if (!widget.enabled) return;
    final reduced = AppMotion.reduced(context);
    final selected =
        await Navigator.of(context, rootNavigator: true).push<Object?>(
      PageRouteBuilder<Object?>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: widget.label ?? widget.hint,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration:
            reduced ? Duration.zero : const Duration(milliseconds: 180),
        reverseTransitionDuration:
            reduced ? Duration.zero : const Duration(milliseconds: 140),
        pageBuilder: (dialogCtx, anim, secAnim) {
          return _UComboboxSearchDialog<T>(
            title: widget.label ?? widget.hint,
            hint: 'Search ${widget.label ?? widget.hint}…',
            items: widget.items,
            currentValue: widget.value,
            allowClear: widget.allowClear,
          );
        },
        transitionsBuilder: (dialogCtx, anim, secAnim, child) {
          if (reduced) return child;
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (identical(selected, _kComboboxClearSentinel)) {
      widget.onChanged(null);
    } else if (selected is T) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final reduced = AppMotion.reduced(context);
    final semanticLabel = widget.label ?? widget.hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.smGap,
        ],
        Semantics(
          button: true,
          enabled: widget.enabled,
          label: '$semanticLabel: ${selected?.label ?? widget.hint}',
          child: InkWell(
            onTap: widget.enabled ? _openSearchDialog : null,
            onFocusChange: (f) => setState(() => _isFocused = f),
            borderRadius: AppSpacing.radiusMd,
            child: AnimatedContainer(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 140),
              curve: AppMotion.snappy,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: widget.enabled ? AppColors.bgCard : AppColors.bgSubtle,
                borderRadius: AppSpacing.radiusMd,
                border: Border.all(
                  color: widget.errorText != null
                      ? AppColors.error
                      : (_isFocused ? AppColors.primary : AppColors.border),
                  width: _isFocused ? 1.5 : 1.0,
                ),
                boxShadow: _isFocused && widget.enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  if (widget.prefixIcon != null) ...[
                    Icon(
                      widget.prefixIcon,
                      size: AppSpacing.iconSm,
                      color: selected != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (selected?.icon != null) ...[
                    Icon(
                      selected!.icon,
                      size: AppSpacing.iconSm,
                      color: selected.color ?? AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      selected?.label ?? widget.hint,
                      style: selected != null
                          ? AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            )
                          : AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (widget.allowClear && selected != null && widget.enabled)
                    IconButton(
                      onPressed: () => widget.onChanged(null),
                      tooltip: 'Clear $semanticLabel',
                      icon: const Icon(
                        PhosphorIconsRegular.x,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsRegular.caretDown,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _UComboboxSearchDialog<T> extends StatefulWidget {
  final String title;
  final String hint;
  final List<UComboboxItem<T>> items;
  final T? currentValue;
  final bool allowClear;

  const _UComboboxSearchDialog({
    required this.title,
    required this.hint,
    required this.items,
    required this.currentValue,
    required this.allowClear,
  });

  @override
  State<_UComboboxSearchDialog<T>> createState() =>
      _UComboboxSearchDialogState<T>();
}

class _UComboboxSearchDialogState<T> extends State<_UComboboxSearchDialog<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  String _query = '';
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.currentValue != null) {
      final initialIdx = widget.items
          .indexWhere((item) => item.value == widget.currentValue);
      if (initialIdx >= 0) {
        _highlightedIndex = initialIdx;
      }
    }
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHighlightedIntoView(animate: false);
    });
  }

  void _onSearchChanged() {
    final nextQuery = _searchCtrl.text.trim().toLowerCase();
    if (nextQuery == _query) return;
    setState(() {
      _query = nextQuery;
      _highlightedIndex = 0;
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<UComboboxItem<T>> get _filteredItems {
    if (_query.isEmpty) return widget.items;
    return widget.items.where((item) {
      final matchLabel = item.label.toLowerCase().contains(_query);
      final matchSub = item.subtitle?.toLowerCase().contains(_query) ?? false;
      return matchLabel || matchSub;
    }).toList();
  }

  void _scrollHighlightedIntoView({bool animate = true}) {
    final keyCtx = _itemKeys[_highlightedIndex]?.currentContext;
    if (keyCtx != null) {
      Scrollable.ensureVisible(
        keyCtx,
        duration: animate ? const Duration(milliseconds: 110) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      return;
    }
    if (_scrollCtrl.hasClients) {
      final approxOffset = (_highlightedIndex * 52.0).clamp(
        0.0,
        _scrollCtrl.position.maxScrollExtent,
      );
      _scrollCtrl.jumpTo(approxOffset);
    }
  }

  void _selectHighlighted() {
    final items = _filteredItems;
    if (items.isNotEmpty &&
        _highlightedIndex >= 0 &&
        _highlightedIndex < items.length) {
      Navigator.pop(context, items[_highlightedIndex].value);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    final items = _filteredItems;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % items.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollHighlightedIntoView();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex =
            (_highlightedIndex - 1 + items.length) % items.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollHighlightedIntoView();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectHighlighted();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final canClear = widget.allowClear && widget.currentValue != null;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: AppSpacing.radiusMd, // Concentric outer: 12px
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with search
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: AppTextStyles.h3.copyWith(fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (canClear)
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    _kComboboxClearSentinel,
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(
                                  PhosphorIconsRegular.x,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgSubtle,
                              borderRadius: AppSpacing.radiusSm,
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.magnifyingGlass,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    autofocus: true,
                                    onSubmitted: (_) => _selectHighlighted(),
                                    style: AppTextStyles.bodyMedium,
                                    decoration: InputDecoration(
                                      hintText: widget.hint,
                                      hintStyle:
                                          AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                if (_query.isNotEmpty)
                                  IconButton(
                                    onPressed: _searchCtrl.clear,
                                    tooltip: 'Clear search',
                                    icon: const Icon(
                                      PhosphorIconsRegular.xCircle,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: AppSpacing.sm,
                            runSpacing: 2,
                            children: [
                              Text(
                                '${items.length} of ${widget.items.length} option${widget.items.length == 1 ? '' : 's'}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '↑↓ Navigate · Enter Select · Esc Close',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textDisabled,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    // Items List
                    Flexible(
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.magnifyingGlass,
                                      size: 24,
                                      color: AppColors.textDisabled,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No matching results',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                final item = items[i];
                                final isSelected =
                                    item.value == widget.currentValue;
                                final isHighlighted = i == _highlightedIndex;
                                final itemKey = _itemKeys.putIfAbsent(
                                  i,
                                  () => GlobalKey(),
                                );

                                return KeyedSubtree(
                                  key: itemKey,
                                  child: InkWell(
                                    onTap: () =>
                                        Navigator.pop(context, item.value),
                                    borderRadius: AppSpacing
                                        .radiusSm, // Concentric inner: 8px
                                    child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primarySoft
                                          : (isHighlighted
                                              ? AppColors.surfaceInteractive
                                              : Colors.transparent),
                                      borderRadius: AppSpacing.radiusSm,
                                      border: isSelected
                                          ? Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.35))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        if (item.icon != null) ...[
                                          Icon(
                                            item.icon,
                                            size: 15,
                                            color: item.color ??
                                                (isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.label,
                                                style: AppTextStyles.bodyMedium
                                                    .copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (item.subtitle != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.subtitle!,
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (item.trailing != null)
                                          item.trailing!
                                        else if (isSelected)
                                          const Icon(
                                            PhosphorIconsRegular.check,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
