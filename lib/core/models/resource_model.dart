// ============================================================
// FILE: lib/core/models/resource_model.dart
// PURPOSE: Typed view of a row in the `resources` table.
// A resource is either a PDF (file_url) or a Drive link
// (drive_link); `isPdf`/`url` resolve which. Pure Dart — the
// screen maps isPdf -> the ResourceCard's ResourceType.
// ============================================================

class Resource {
  final String id;
  final String title;
  final String category;
  final int semester;
  final String? subjectCode;
  final String? driveLink;
  final String? fileUrl;
  final DateTime? createdAt;

  const Resource({
    required this.id,
    required this.title,
    required this.category,
    required this.semester,
    this.subjectCode,
    this.driveLink,
    this.fileUrl,
    this.createdAt,
  });

  factory Resource.fromMap(Map<String, dynamic> map) {
    return Resource(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      semester: (map['semester'] as int?) ?? 0,
      subjectCode: map['subject_code'] as String?,
      driveLink: map['drive_link'] as String?,
      fileUrl: map['file_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  bool get isPdf => (fileUrl?.isNotEmpty ?? false);

  /// The link to open — prefers the stored PDF, falls back to Drive.
  String? get url => isPdf ? fileUrl : driveLink;

  String get subjectLabel =>
      (subjectCode?.isNotEmpty ?? false) ? subjectCode! : 'General';
}
