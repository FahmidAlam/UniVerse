import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';

class AppDateUtils {
  static String formatTimeSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= AppConstants.timeSlots.length) return '';
    return AppConstants.timeSlots[slotIndex];
  }

  static DateTime _parseTime(String timeStr) {
    final parts = timeStr.trim().split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    final String period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime parseSlotStart(int slotIndex) {
    final slot = AppConstants.timeSlots[slotIndex];
    return _parseTime(slot.split(' – ')[0]);
  }

  static DateTime parseSlotEnd(int slotIndex) {
    final slot = AppConstants.timeSlots[slotIndex];
    return _parseTime(slot.split(' – ')[1]);
  }

  static String formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '00:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dt.weekday - 1];
  }

  /// Time-of-day greeting for dashboards: "Good morning/afternoon/evening".
  static String greeting([DateTime? at]) {
    final h = (at ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Short, human date for headers — e.g. "Sun, 16 Jun".
  static String shortDate([DateTime? at]) {
    final d = at ?? DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  static bool isLive(DateTime start, DateTime end) {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  static ClassStatus getClassStatus(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isAfter(end)) return ClassStatus.done;
    if (now.isAfter(start)) return ClassStatus.live;
    if (start.difference(now).inMinutes <= 30) return ClassStatus.next;
    return ClassStatus.upcoming;
  }
}
