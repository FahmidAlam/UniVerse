// ============================================================
// FILE: lib/core/utils/safe_change_notifier.dart
// PURPOSE: ChangeNotifier that ignores notifyListeners() after
// dispose(). Screen-scoped controllers often have async methods
// (await service → notifyListeners) still in flight when navigation
// disposes the screen — e.g. a session expiry redirecting
// /admin/dashboard → /login mid-load. Plain ChangeNotifier throws
// "used after being disposed" in that race; this base class makes
// the late notify a harmless no-op instead.
//
// USAGE: extend this instead of ChangeNotifier for any controller
// that a screen creates AND disposes. Long-lived controllers like
// AuthController don't need it.
// ============================================================

import 'package:flutter/foundation.dart';

class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  /// True once dispose() has run — async methods can check this to
  /// skip late state writes entirely.
  bool get disposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
