import 'package:flutter/foundation.dart';

class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

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
