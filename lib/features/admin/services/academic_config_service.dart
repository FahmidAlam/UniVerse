import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/models/academic_model.dart';

/// One atomic read plus narrow, RLS-authorized catalog writes. No client-side
/// profile department or cached role grants capabilities.
abstract class AcademicStore {
  Future<Map<String, dynamic>> catalog();
  Future<void> save(String table, Map<String, dynamic> row);
  Future<void> reviewAlias(String id);
  Future<void> replaceAliasMembers(String id, List<String> members);
}

class SupabaseAcademicStore implements AcademicStore {
  final SupabaseClient client;
  SupabaseAcademicStore(this.client);

  @override
  Future<Map<String, dynamic>> catalog() async {
    final data = await client.rpc('academic_catalog');
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<void> save(String table, Map<String, dynamic> row) async {
    if (table == 'group_aliases') {
      await client.rpc('save_academic_alias', params: {
        'p_id': row['id'],
        'p_cohort_id': row['cohort_id'],
        'p_label': row['label'],
        'p_group_ids': row['group_ids'],
      });
    } else if (table == 'timetable_faculty' || table == 'timetable_rooms') {
      final changes = Map<String, dynamic>.of(row)..remove('id');
      // A missing or RLS-hidden identity must not look like a successful edit.
      await client
          .from(table)
          .update(changes)
          .eq('id', row['id'] as String)
          .select('id')
          .single();
    } else {
      await client.from(table).upsert(row);
    }
  }

  @override
  Future<void> reviewAlias(String id) async {
    await client.rpc('review_academic_alias', params: {'p_alias_id': id});
  }

  @override
  Future<void> replaceAliasMembers(String id, List<String> members) async {
    await client.rpc('replace_academic_alias_members', params: {
      'p_alias_id': id,
      'p_group_ids': members,
    });
  }
}

class AcademicConfigService {
  final AcademicStore _store;
  AcademicConfigService({AcademicStore? store, SupabaseClient? client})
      : _store =
            store ?? SupabaseAcademicStore(client ?? Supabase.instance.client);

  Future<AcademicCatalog> fetchCatalog() async =>
      AcademicCatalog.fromMap(await _store.catalog());
  Future<void> saveDepartment(Department row) =>
      _store.save('departments', row.toMap());
  Future<void> saveCalendar(AcademicCalendar row) =>
      _store.save('academic_calendars', row.toMap());
  Future<void> saveYear(AcademicYear row) =>
      _store.save('academic_years', row.toMap());
  Future<void> saveProgram(AcademicProgram row) =>
      _store.save('programs', row.toMap());
  Future<void> saveTerm(AcademicTerm row) =>
      _store.save('academic_terms', row.toMap());
  Future<void> saveCohort(Cohort row) => _store.save('cohorts', row.toMap());
  Future<void> saveGroup(StudentGroup row) =>
      _store.save('student_groups', row.toMap());
  Future<void> saveCohortTerm(CohortTerm row) =>
      _store.save('cohort_terms', row.toMap());
  Future<void> saveScope(SchedulingScope row) =>
      _store.save('scheduling_scopes', row.toMap());
  Future<void> saveAlias(GroupAlias row) =>
      _store.save('group_aliases', {...row.toMap(), 'reviewed': false});
  Future<void> reviewAlias(String id) => _store.reviewAlias(id);
  Future<void> replaceAliasMembers(String id, List<String> members) =>
      _store.replaceAliasMembers(id, members);
  Future<void> updateFaculty(Faculty row) => _store.save('timetable_faculty', {
        'id': row.id,
        'full_name': row.displayName,
        'home_department_id': row.homeDepartmentId,
        'is_active': row.isActive,
      });
  Future<void> updateRoom(Room row) =>
      _store.save('timetable_rooms', row.toMap());
}
