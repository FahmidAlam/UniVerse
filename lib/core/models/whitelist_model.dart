// ============================================================
// FILE: lib/core/models/whitelist_model.dart
// PURPOSE: Typed view of a row in the `whitelists` table (the admin
// gate). Mirrors the LIVE columns only: email, role, name,
// teacher_code, batch, section, semester. The table has no id /
// designation / department column. Pure Dart — no Supabase imports.
// ============================================================

import 'package:universe/core/constants/app_constants.dart';

class WhitelistEntry {
  final String email;
  final String role;
  final String? name;
  final String? teacherCode;
  final String? batch;
  final String? section;
  final int? semester;

  const WhitelistEntry({
    required this.email,
    required this.role,
    this.name,
    this.teacherCode,
    this.batch,
    this.section,
    this.semester,
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
