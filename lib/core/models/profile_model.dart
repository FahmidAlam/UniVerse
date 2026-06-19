// ============================================================
// FILE: lib/core/models/profile_model.dart
// PURPOSE: Typed view of a row in the `profiles` table.
// Pure Dart — no Supabase imports. Parses the exact Map shape
// that auth_service.dart already produces, so it is a drop-in
// over the raw maps auth currently passes around.
// ============================================================

import 'package:universe/core/constants/app_constants.dart';

class Profile {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? avatarUrl;

  // Student fields
  final String? batch;
  final String? section;
  final int? semester;
  final String? studentId;

  // Teacher fields
  final String? teacherCode;
  final String? designation;
  final String? department;
  final List<String> courses;

  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.avatarUrl,
    this.batch,
    this.section,
    this.semester,
    this.studentId,
    this.teacherCode,
    this.designation,
    this.department,
    this.courses = const [],
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      role: (map['role'] as String?) ?? AppConstants.roleStudent,
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      batch: map['batch'] as String?,
      section: map['section'] as String?,
      semester: map['semester'] as int?,
      studentId: map['student_id'] as String?,
      teacherCode: map['teacher_code'] as String?,
      designation: map['designation'] as String?,
      department: map['department'] as String?,
      courses: (map['courses'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  // ─── UI helpers ───────────────────────────────────────────
  bool get isStudent => role == AppConstants.roleStudent;
  bool get isTeacher => role == AppConstants.roleTeacher;
  bool get isAdmin => role == AppConstants.roleAdmin;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    return email.split('@').first;
  }

  String get roleLabel {
    switch (role) {
      case AppConstants.roleTeacher:
        return 'Teacher';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return 'Student';
    }
  }

  /// The role-appropriate ID shown on the profile screen.
  String? get identifier => isTeacher ? teacherCode : studentId;

  String get identifierLabel => isTeacher ? 'Teacher Code' : 'Student ID';
}
