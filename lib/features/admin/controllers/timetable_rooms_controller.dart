// PHASE A: TimetableRoomsController with Room Classification and Availability Matrix support
import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class TimetableRoomsController extends ChangeNotifier {
  final TimetableConfigService _service;

  TimetableRoomsController({
    TimetableConfigService? service,
    List<TimetableRoom>? initialRooms,
  })  : _service = service ?? TimetableConfigService(),
        _rooms = initialRooms ?? [];

  List<TimetableRoom> _rooms;
  bool _isLoading = false;
  String? _errorMessage;

  List<TimetableRoom> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<TimetableRoom> get labRooms =>
      _rooms.where((r) => r.isLab).toList();
  List<TimetableRoom> get theoryRooms =>
      _rooms.where((r) => !r.isLab).toList();

  Future<void> load({bool force = false}) async {
    if (_rooms.isNotEmpty && !force) {
      notifyListeners();
      return;
    }
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
      _rooms = await _service.fetchRooms();
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the room.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveRoom(TimetableRoom room) async {
    final existing = _rooms.where((r) => r.id == room.id).firstOrNull;
    return save(existing: existing, data: room.toMap());
  }

  Future<bool> toggleActive(TimetableRoom room) async {
    final newActive = !room.isActive;
    return save(existing: room, data: {
      'is_active': newActive,
      'in_active_semester_pool': newActive,
    });
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

