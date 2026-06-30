import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';

class RoomStatus {
  final String room;
  final bool isOccupied;
  final String? currentTeacher;
  final String? currentSubject;
  final String? currentClass;
  final String? remainingTime;
  final String? timeStart;
  final String? timeEnd;
  final String? nextTeacher;
  final String? nextSubject;
  final String? nextTime;

  RoomStatus({
    required this.room,
    required this.isOccupied,
    this.currentTeacher,
    this.currentSubject,
    this.currentClass,
    this.remainingTime,
    this.timeStart,
    this.timeEnd,
    this.nextTeacher,
    this.nextSubject,
    this.nextTime,
  });
}

class RoomsController extends ChangeNotifier {
  final RoomStatusService _service;

  RoomsController({required RoomStatusService service}) : _service = service;

  List<RoomStatus> _roomStatuses = [];
  bool _isLoading = true;
  String? _error;
  List<RoutineEntry>? _allRoutines;

  List<RoomStatus> get roomStatuses => _roomStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRoomStatuses() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _allRoutines = await _service.fetchAllRoutines();

      final now = DateTime.now();
      final roomMap = <String, RoomStatus>{};

      final routinesByRoom = <String, List<RoutineEntry>>{};
      for (final entry in _allRoutines!) {
        if (!routinesByRoom.containsKey(entry.room)) {
          routinesByRoom[entry.room] = [];
        }
        routinesByRoom[entry.room]!.add(entry);
      }

      for (final room in routinesByRoom.keys) {
        final entries = routinesByRoom[room]!;
        entries.sort((a, b) => a.timeStart.compareTo(b.timeStart));

        final todayEntries = entries.where((e) {
          return _isDayToday(e.day);
        }).toList();

        RoomStatus? currentClass;
        RoutineEntry? current;
        RoutineEntry? next;

        for (final entry in todayEntries) {
          final start = entry.startOn(now);
          final end = entry.endOn(now);

          if (now.isAfter(start) && now.isBefore(end)) {
            current = entry;
            final remaining = end.difference(now).inMinutes;
            currentClass = RoomStatus(
              room: room,
              isOccupied: true,
              currentTeacher: entry.teacherName ?? entry.teacherCode ?? 'N/A',
              currentSubject: entry.subject,
              currentClass: '${entry.batch} - ${entry.section}',
              remainingTime: remaining > 0
                  ? '$remaining min'
                  : 'Less than 1 min',
              timeStart: entry.timeStart,
              timeEnd: entry.timeEnd,
            );
            break;
          }
        }

        if (current == null) {
          for (final entry in todayEntries) {
            final start = entry.startOn(now);
            if (now.isBefore(start)) {
              next = entry;
              break;
            }
          }

          currentClass = RoomStatus(
            room: room,
            isOccupied: false,
            nextTeacher: next?.teacherName ?? next?.teacherCode ?? 'TBD',
            nextSubject: next?.subject ?? 'No more classes',
            nextTime: next != null ? next.timeStart : 'N/A',
          );
        }

        roomMap[room] = currentClass!;
      }

      _roomStatuses = roomMap.values.toList()
        ..sort((a, b) => a.room.compareTo(b.room));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void subscribeToRealTimeUpdates() {
    _service.streamAllRoutines().listen((routines) {
      _allRoutines = routines;
      fetchRoomStatuses();
    });
  }

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

  Future<void> refresh() async {
    await fetchRoomStatuses();
  }
}
