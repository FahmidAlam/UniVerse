import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/admin_service.dart';

class AdminDashboardController extends SafeChangeNotifier {
  final AdminService _service = AdminService();

  AdminCounts _counts = const AdminCounts();
  bool _isLoading = false;
  String? _errorMessage;

  AdminCounts get counts => _counts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _counts = await _service.counts();
    } catch (e) {
      _errorMessage = 'Could not load dashboard stats.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
