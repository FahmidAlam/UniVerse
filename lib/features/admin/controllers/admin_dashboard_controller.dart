import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/admin_service.dart';

// PHASE 5: AdminDashboardController with optional DI seams for deterministic offline testing.
class AdminDashboardController extends SafeChangeNotifier {
  AdminService? _service;
  final Future<AdminCounts> Function()? _countsLoader;

  AdminCounts _counts;
  bool _isLoading = false;
  bool _hasLoaded;
  String? _errorMessage;

  AdminDashboardController({
    AdminService? service,
    Future<AdminCounts> Function()? countsLoader,
    AdminCounts? initialCounts,
  })  : _service = service,
        _countsLoader = countsLoader,
        _counts = initialCounts ?? const AdminCounts(),
        _hasLoaded = initialCounts != null;

  AdminCounts get counts => _counts;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_countsLoader != null) {
        _counts = await _countsLoader!();
      } else {
        _service ??= AdminService();
        _counts = await _service!.counts();
      }
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = 'Could not load dashboard stats.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
