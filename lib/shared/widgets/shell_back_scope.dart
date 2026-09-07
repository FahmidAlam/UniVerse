import 'package:flutter/widgets.dart';

/// Consumes a back press. Returns true when it handled it.
typedef ShellBackHandler = bool Function();

/// Collects the back handlers of whichever tab screens are currently mounted,
/// so [AppShell] can own the only [PopScope] in the shell route.
///
/// Several [PopScope]s inside one route all fire their callbacks on a single
/// back press, so a screen-level one plus a shell-level one would both run
/// (closing a folder *and* popping the exit toast). Screens register here
/// instead via [ShellBackScope].
class ShellBackRegistry {
  final List<ShellBackHandler> _handlers = <ShellBackHandler>[];

  void register(ShellBackHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  void unregister(ShellBackHandler handler) => _handlers.remove(handler);

  /// Innermost screen gets first refusal.
  bool handleBack() {
    for (final handler in _handlers.reversed.toList(growable: false)) {
      if (handler()) return true;
    }
    return false;
  }
}

class ShellBackRegistryScope extends InheritedWidget {
  final ShellBackRegistry registry;

  const ShellBackRegistryScope({
    super.key,
    required this.registry,
    required super.child,
  });

  static ShellBackRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellBackRegistryScope>()
      ?.registry;

  @override
  bool updateShouldNotify(ShellBackRegistryScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Lets a screen swallow the back press while it has internal state to unwind
/// (an open folder, an active selection mode) before the shell decides whether
/// to change tab or exit.
///
/// Pass `null` for [onBack] when there is nothing to unwind. Outside a shell
/// route it degrades to a plain [PopScope], so pushed screens work too.
class ShellBackScope extends StatefulWidget {
  final VoidCallback? onBack;
  final Widget child;

  const ShellBackScope({super.key, required this.onBack, required this.child});

  @override
  State<ShellBackScope> createState() => _ShellBackScopeState();
}

class _ShellBackScopeState extends State<ShellBackScope> {
  ShellBackRegistry? _registry;

  bool _handleBack() {
    final onBack = widget.onBack;
    if (onBack == null) return false;
    onBack();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ShellBackRegistryScope.maybeOf(context);
    if (identical(registry, _registry)) return;
    _registry?.unregister(_handleBack);
    _registry = registry;
    registry?.register(_handleBack);
  }

  @override
  void dispose() {
    _registry?.unregister(_handleBack);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_registry != null) return widget.child;

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: widget.child,
    );
  }
}
