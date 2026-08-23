import 'package:universe/core/models/whitelist_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/admin_service.dart';

class WhitelistController extends SafeChangeNotifier {
  final AdminService _service = AdminService();

  List<WhitelistEntry> _entries = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<WhitelistEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _service.fetchWhitelist();
    } catch (_) {
      _errorMessage = 'Could not load the whitelist.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> invite({required String email, String? name}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    var ok = false;
    try {
      await _service.inviteAdmin(email: email, name: name);
      await load();
      ok = true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isSaving = false;
    notifyListeners();
    return ok;
  }

  Future<void> remove(String email) async {
    try {
      await _service.removeFromWhitelist(email);
      _entries.removeWhere((e) => e.email == email);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not remove the entry.';
      notifyListeners();
    }
  }
}
