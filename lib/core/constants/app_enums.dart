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
}
