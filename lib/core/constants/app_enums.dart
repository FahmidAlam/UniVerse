import 'package:universe_v1/core/constants/app_constants.dart';

enum ClassStatus { live, next, done, cancelled, upcoming }

enum NotifType {
  university,
  classCancel,
  roomChange,
  testReminder,
  assignment,
  exam;

  static NotifType fromString(String value) {
    switch (value) {
      case AppConstants.notifClassCancel:
        return NotifType.classCancel;
      case AppConstants.notifRoomChange:
        return NotifType.roomChange;
      case AppConstants.notifTestReminder:
        return NotifType.testReminder;
      case AppConstants.notifAssignment:
        return NotifType.assignment;
      case AppConstants.notifExam:
        return NotifType.exam;
      default:
        return NotifType.university;
    }
  }

  /// Reverse of [fromString] — the exact string written to the
  /// `notifications.type` column (must satisfy its CHECK constraint).
  /// Used by the admin Campus Broadcast composer.
  String get dbValue {
    switch (this) {
      case NotifType.university:
        return AppConstants.notifUniversity;
      case NotifType.classCancel:
        return AppConstants.notifClassCancel;
      case NotifType.roomChange:
        return AppConstants.notifRoomChange;
      case NotifType.testReminder:
        return AppConstants.notifTestReminder;
      case NotifType.assignment:
        return AppConstants.notifAssignment;
      case NotifType.exam:
        return AppConstants.notifExam;
    }
  }

  /// Singular human label for a single type (e.g. the broadcast type
  /// dropdown). The Alerts filter chips use their own plural labels.
  String get label {
    switch (this) {
      case NotifType.university:
        return 'Notice';
      case NotifType.classCancel:
        return 'Class Cancellation';
      case NotifType.roomChange:
        return 'Room Change';
      case NotifType.testReminder:
        return 'Test Reminder';
      case NotifType.assignment:
        return 'Assignment';
      case NotifType.exam:
        return 'Exam';
    }
  }
}
