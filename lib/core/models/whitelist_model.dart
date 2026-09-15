import 'package:universe/core/constants/app_constants.dart';

class WhitelistEntry {
  final String email;
  final String role;
  final String? name;
  final String? teacherCode;
  final String? batch;
  final String? section;
  final int? semester;
  // Added by migration 016; copied into the teacher profile on first sign-in.
  final String? department;
  final String? designation;

  const WhitelistEntry({
    required this.email,
    required this.role,
    this.name,
    this.teacherCode,
    this.batch,
    this.section,
    this.semester,
    this.department,
    this.designation,
  });

  factory WhitelistEntry.fromMap(Map<String, dynamic> map) {
    return WhitelistEntry(
      email: (map['email'] as String?) ?? '',
      role: (map['role'] as String?) ?? AppConstants.roleTeacher,
      name: map['name'] as String?,
      teacherCode: map['teacher_code'] as String?,
      batch: map['batch'] as String?,
      section: map['section'] as String?,
      semester: map['semester'] as int?,
      department: map['department'] as String?,
      designation: map['designation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'teacher_code': teacherCode,
      'batch': batch,
      'section': section,
      'semester': semester,
      'department': department,
      'designation': designation,
    };
  }

  String get roleLabel {
    switch (role) {
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleTeacher:
        return 'Teacher';
      default:
        return 'Student';
    }
  }
}
