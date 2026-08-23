class TimetableRoom {
  final String id;
  final String name;
  final String? building;
  final bool isLab;
  final bool isGallery;
  final bool isActive;

  const TimetableRoom({
    required this.id,
    required this.name,
    this.building,
    this.isLab = false,
    this.isGallery = false,
    this.isActive = true,
  });

  factory TimetableRoom.fromMap(Map<String, dynamic> m) => TimetableRoom(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        building: m['building'] as String?,
        isLab: (m['is_lab'] as bool?) ?? false,
        isGallery: (m['is_gallery'] as bool?) ?? false,
        isActive: (m['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'building': building,
        'is_lab': isLab,
        'is_gallery': isGallery,
        'is_active': isActive,
      };

  String get kind => isLab ? 'Lab' : (isGallery ? 'Gallery' : 'Theory');
}

class TimetableFaculty {
  final String id;
  final String acronym;
  final String? fullName;
  final String? dept;
  final String? designation;
  final List<String> offDays;
  final bool isActive;

  const TimetableFaculty({
    required this.id,
    required this.acronym,
    this.fullName,
    this.dept,
    this.designation,
    this.offDays = const [],
    this.isActive = true,
  });

  factory TimetableFaculty.fromMap(Map<String, dynamic> m) => TimetableFaculty(
        id: m['id'] as String,
        acronym: (m['acronym'] as String?) ?? '',
        fullName: m['full_name'] as String?,
        dept: m['dept'] as String?,
        designation: m['designation'] as String?,
        offDays: ((m['off_days'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        isActive: (m['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'acronym': acronym,
        'full_name': fullName,
        'dept': dept,
        'designation': designation,
        'off_days': offDays,
        'is_active': isActive,
      };

  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : acronym;

  TimetableFaculty copyWith({String? fullName, List<String>? offDays}) =>
      TimetableFaculty(
        id: id,
        acronym: acronym,
        fullName: fullName ?? this.fullName,
        dept: dept,
        designation: designation,
        offDays: offDays ?? this.offDays,
        isActive: isActive,
      );
}

class TimetableSettings {
  final String? semesterLabel;
  final List<dynamic> periods;
  final bool fridayNoP4;
  final String serviceScope;
  final Map<String, dynamic> weights;

  const TimetableSettings({
    this.semesterLabel,
    this.periods = const [],
    this.fridayNoP4 = true,
    this.serviceScope = 'resource_only',
    this.weights = const {},
  });

  factory TimetableSettings.fromMap(Map<String, dynamic> m) => TimetableSettings(
        semesterLabel: m['semester_label'] as String?,
        periods: (m['periods'] as List?) ?? const [],
        fridayNoP4: (m['friday_no_p4'] as bool?) ?? true,
        serviceScope: (m['service_scope'] as String?) ?? 'resource_only',
        weights: (m['weights'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        'semester_label': semesterLabel,
        'periods': periods,
        'friday_no_p4': fridayNoP4,
        'service_scope': serviceScope,
        'weights': weights,
      };

  int weight(String key, int fallback) {
    final v = weights[key];
    return v is num ? v.toInt() : fallback;
  }

  TimetableSettings copyWith({
    String? semesterLabel,
    bool? fridayNoP4,
    String? serviceScope,
    Map<String, dynamic>? weights,
  }) =>
      TimetableSettings(
        semesterLabel: semesterLabel ?? this.semesterLabel,
        periods: periods,
        fridayNoP4: fridayNoP4 ?? this.fridayNoP4,
        serviceScope: serviceScope ?? this.serviceScope,
        weights: weights ?? this.weights,
      );
}
