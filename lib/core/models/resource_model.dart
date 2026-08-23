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

  String? get url => isPdf ? fileUrl : driveLink;

  String get subjectLabel =>
      (subjectCode?.isNotEmpty ?? false) ? subjectCode! : 'General';
}
