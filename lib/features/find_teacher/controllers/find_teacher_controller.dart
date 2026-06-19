// ============================================================
// FILE: lib/features/find_teacher/controllers/find_teacher_controller.dart
// PURPOSE: State & logic for finding teacher location.
// Manages teacher list, search, and current/next location.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';

class TeacherInfo {
  final String code;
  final String name;
  final String? currentRoom;
  final String? currentSubject;
  final String? currentClass; // batch+section
  final String? remainingTime;
  final String? status; // "In Class", "Free", "No Class Today"
  final String? nextRoom;
  final String? nextSubject;
  final String? nextTime;

  TeacherInfo({
    required this.code,
    required this.name,
    this.currentRoom,
    this.currentSubject,
    this.currentClass,
    this.remainingTime,
    this.status,
    this.nextRoom,
    this.nextSubject,
    this.nextTime,
  });
}

class FindTeacherController extends ChangeNotifier {
  final TeacherLocationService _service;

  FindTeacherController({required TeacherLocationService service})
    : _service = service;

  List<TeacherInfo> _allTeachers = [];
  List<TeacherInfo> _filteredTeachers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  List<RoutineEntry>? _allRoutines;

  List<TeacherInfo> get filteredTeachers => _filteredTeachers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// Initialize: fetch teacher list and routines.
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Fetch all routines
      _allRoutines = await _service.fetchAllRoutines();

      // Build unique teacher list
      final teacherMap = <String, String>{};
      for (final entry in _allRoutines!) {
        final code = entry.teacherCode;
        final name = entry.teacherName;
        if (code != null && code.isNotEmpty) {
          teacherMap[code] = name ?? code;
        }
      }

      // Create TeacherInfo objects with location data
      _allTeachers = teacherMap.entries
          .map((e) => _buildTeacherInfo(e.key, e.value, _allRoutines!))
          .toList();

      _allTeachers.sort((a, b) => a.name.compareTo(b.name));
      _filteredTeachers = _allTeachers;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Build TeacherInfo with current location based on time.
  TeacherInfo _buildTeacherInfo(
    String code,
    String name,
    List<RoutineEntry> allRoutines,
  ) {
    final now = DateTime.now();

    // Filter routines for this teacher
    final teacherRoutines = allRoutines
        .where((e) => e.teacherCode == code && _isDayToday(e.day))
        .toList();

    teacherRoutines.sort((a, b) => a.timeStart.compareTo(b.timeStart));

    RoutineEntry? currentEntry;
    RoutineEntry? nextEntry;
    String status = 'No Class Today';

    // Check if teacher is currently in a class
    for (final entry in teacherRoutines) {
      final start = entry.startOn(now);
      final end = entry.endOn(now);

      if (now.isAfter(start) && now.isBefore(end)) {
        currentEntry = entry;
        status = 'In Class';
        break;
      }
    }

    // If not in class, find next class
    if (currentEntry == null && teacherRoutines.isNotEmpty) {
      for (final entry in teacherRoutines) {
        final start = entry.startOn(now);
        if (now.isBefore(start)) {
          nextEntry = entry;
          status = 'Free';
          break;
        }
      }

      // If no future class, mark as free (last class ended)
      if (nextEntry == null && teacherRoutines.isNotEmpty) {
        status = 'Free';
      }
    }

    return TeacherInfo(
      code: code,
      name: name,
      currentRoom: currentEntry?.room,
      currentSubject: currentEntry?.subject,
      currentClass: currentEntry != null
          ? '${currentEntry.batch} - ${currentEntry.section}'
          : null,
      remainingTime: currentEntry != null
          ? '${currentEntry.endOn(now).difference(now).inMinutes} min'
          : null,
      status: status,
      nextRoom: nextEntry?.room,
      nextSubject: nextEntry?.subject,
      nextTime: nextEntry?.timeStart,
    );
  }

  /// Search teachers by name or code.
  void search(String query) {
    _searchQuery = query.toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredTeachers = _allTeachers;
    } else {
      _filteredTeachers = _allTeachers
          .where(
            (t) =>
                t.name.toLowerCase().contains(_searchQuery) ||
                t.code.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    notifyListeners();
  }

  /// Subscribe to real-time updates.
  void subscribeToRealTimeUpdates() {
    _service.streamAllRoutines().listen((routines) {
      _allRoutines = routines;
      initialize();
    });
  }

  /// Refresh teacher data.
  Future<void> refresh() async {
    await initialize();
  }

  /// Determine if a routine day string matches today.
  bool _isDayToday(String dayName) {
    final now = DateTime.now();
    const dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return dayNames[now.weekday % 7] == dayName;
  }
}
