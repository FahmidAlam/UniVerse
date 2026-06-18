// ============================================================
// FILE: lib/features/admin/controllers/resource_admin_controller.dart
// PURPOSE: State for the admin Manage Resources screen. Picks a
// file (any type) OR takes a Drive link, uploads to the public
// `resources` bucket, inserts the row, and (optionally) posts a
// notification so students are alerted (in-app + push). Also lists
// and deletes existing resources. Screen → controller → services.
// ============================================================

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/models/resource_model.dart';
import 'package:universe_v1/core/utils/safe_change_notifier.dart';
import 'package:universe_v1/features/notifications/services/notification_service.dart';
import 'package:universe_v1/features/resources/services/resource_service.dart';

class ResourceAdminController extends SafeChangeNotifier {
  final ResourceService _service = ResourceService();
  final NotificationService _notifications = NotificationService();

  // Upload categories (the 'All' filter chip is excluded).
  static const List<String> categories = ['PYQ', 'Notes', 'Slides', 'Assignments'];

  List<Resource> _all = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  // Form selections
  String _category = 'Notes';
  int _semester = 1;
  Uint8List? _fileBytes;
  String? _fileName;

  List<Resource> get all => _all;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  String get category => _category;
  int get semester => _semester;
  String? get fileName => _fileName;
  bool get hasFile => _fileBytes != null;

  void setCategory(String c) {
    if (_category == c) return;
    _category = c;
    notifyListeners();
  }

  void setSemester(int s) {
    if (_semester == s) return;
    _semester = s;
    notifyListeners();
  }

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    _fileBytes = file.bytes;
    _fileName = file.name;
    notifyListeners();
  }

  void clearFile() {
    _fileBytes = null;
    _fileName = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchAll();
    } catch (e) {
      _errorMessage = 'Could not load resources.';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Upload (or attach a link) + insert + optionally notify students.
  /// Returns true on success.
  Future<bool> submit({
    required String title,
    String? subjectCode,
    String? driveLink,
    bool notifyStudents = true,
  }) async {
    final cleanTitle = title.trim();
    final cleanLink = driveLink?.trim() ?? '';

    if (cleanTitle.isEmpty) {
      _errorMessage = 'Give the resource a title.';
      notifyListeners();
      return false;
    }
    if (_fileBytes == null && cleanLink.isEmpty) {
      _errorMessage = 'Pick a file or paste a link.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? fileUrl;
      String? link;
      if (_fileBytes != null) {
        fileUrl = await _service.uploadFile(_fileBytes!, _fileName!, _semester);
      } else {
        link = cleanLink;
      }

      final subject =
          (subjectCode == null || subjectCode.trim().isEmpty)
              ? null
              : subjectCode.trim();

      await _service.createResource({
        'title': cleanTitle,
        'category': _category,
        'semester': _semester,
        'subject_code': subject,
        'file_url': fileUrl,
        'drive_link': link,
      });

      if (notifyStudents) {
        // In-app + push (the deployed webhook fans this out to FCM).
        await _notifications.createBroadcast(
          type: _category == 'Assignments'
              ? NotifType.assignment
              : NotifType.university,
          title: 'New resource: $cleanTitle',
          body: '$_category${subject != null ? ' · $subject' : ''} '
              'for Semester $_semester was just added. Open Resources to view.',
          targetRole: AppConstants.roleStudent,
        );
      }

      clearFile();
      await load();
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Upload failed. Check the file/link and try again.';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _service.deleteResource(id);
      _all = _all.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not delete that resource.';
      notifyListeners();
      return false;
    }
  }
}
