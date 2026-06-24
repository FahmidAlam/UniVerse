import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class TimetableRoomsController extends ChangeNotifier {
  final TimetableConfigService _service = TimetableConfigService();

  List<TimetableRoom> _rooms = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TimetableRoom> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<TimetableRoom> get labRooms =>
      _rooms.where((r) => r.isLab).toList();
  List<TimetableRoom> get theoryRooms =>
      _rooms.where((r) => !r.isLab).toList();

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _rooms = await _service.fetchRooms();
    } catch (_) {
      _errorMessage = 'Could not load rooms.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> save({TimetableRoom? existing, required Map<String, dynamic> data}) async {
    try {
      if (existing == null) {
        await _service.createRoom(data);
      } else {
        await _service.updateRoom(existing.id, data);
      }
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the room.';
      notifyListeners();
      return false;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _service.deleteRoom(id);
      _rooms.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not delete the room.';
      notifyListeners();
    }
  }
}
