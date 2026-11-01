import 'package:universe/core/constants/app_constants.dart';

class Profile {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? avatarUrl;

  final String? batch;
  final String? section;
  final int? semester;
  final String? studentId;

  final String? teacherCode;
  final String? designation;
  final String? department;
  final List<String> courses;

  final DateTime? createdAt;

  /// Additive canonical links; legacy labels and auth IDs stay authoritative until reviewed mapping.
  final String? departmentId;
  final String? programId;
  final String? cohortId;
  final String? studentGroupId;
  final String? facultyId;

  const Profile({
    required this.id,
    this.departmentId,
    this.programId,
    this.cohortId,
    this.studentGroupId,
    this.facultyId,
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
      departmentId: map['department_id'] as String?,
      programId: map['program_id'] as String?,
      cohortId: map['cohort_id'] as String?,
      studentGroupId: map['student_group_id'] as String?,
      facultyId: map['faculty_id'] as String?,
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

  String? get identifier => isTeacher ? teacherCode : studentId;

  String get identifierLabel => isTeacher ? 'Teacher Code' : 'Student ID';
}
