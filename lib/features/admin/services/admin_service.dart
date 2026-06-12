// ============================================================
// FILE: lib/features/admin/services/admin_service.dart
// PURPOSE: The ONLY Supabase layer for admin-owned tables that
// have no feature service of their own — the `whitelists` table
// and admin-wide `profiles` operations. Routine CRUD lives on
// RoutineService and broadcast-create on NotificationService;
// this service covers what those don't.
// Admin controllers call this; screens never touch Supabase.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/models/whitelist_model.dart';

/// Aggregate row counts shown on the admin dashboard.
class AdminCounts {
  final int students;
  final int teachers;
  final int admins;
  final int routines;
  final int broadcasts;

  const AdminCounts({
    this.students = 0,
    this.teachers = 0,
    this.admins = 0,
    this.routines = 0,
    this.broadcasts = 0,
  });

  int get totalUsers => students + teachers + admins;
}

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Dashboard counts ─────────────────────────────────────
  // Counts are derived from light `select('id')` reads. The demo
  // dataset is small (tens–low hundreds of rows), so this is cheap
  // and avoids depending on a specific postgrest count() signature.
  Future<AdminCounts> counts() async {
    final results = await Future.wait([
      _count(AppConstants.tableProfiles, roleEq: AppConstants.roleStudent),
      _count(AppConstants.tableProfiles, roleEq: AppConstants.roleTeacher),
      _count(AppConstants.tableProfiles, roleEq: AppConstants.roleAdmin),
      _count(AppConstants.tableRoutines),
      _count(AppConstants.tableNotifications),
    ]);
    return AdminCounts(
      students: results[0],
      teachers: results[1],
      admins: results[2],
      routines: results[3],
      broadcasts: results[4],
    );
  }

  Future<int> _count(String table, {String? roleEq}) async {
    final base = _supabase.from(table).select('id');
    final rows = roleEq == null ? await base : await base.eq('role', roleEq);
    return (rows as List).length;
  }

  // ─── Manage Users: read + role change ─────────────────────
  Future<List<Profile>> fetchAllProfiles({String? roleFilter}) async {
    final base = _supabase.from(AppConstants.tableProfiles).select();
    final rows = roleFilter == null
        ? await base.order('role')
        : await base.eq('role', roleFilter).order('role');
    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Updates a user's role. Hard-deleting the auth user requires the
  /// service-role key (Edge Function) and is intentionally out of scope.
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await _supabase
        .from(AppConstants.tableProfiles)
        .update({'role': role}).eq('id', userId);
  }

  // ─── Admin Registration: whitelist gate ───────────────────
  Future<List<WhitelistEntry>> fetchWhitelist() async {
    final rows = await _supabase
        .from(AppConstants.tableWhitelists)
        .select()
        .order('email');
    return (rows as List)
        .map((r) => WhitelistEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Provisions a new admin via the `invite-admin` Edge Function (which
  /// holds the service-role key — account creation can't be done from the
  /// client). The function whitelists the email and emails an invite link
  /// that lands on the set-password screen. Throws a friendly message.
  Future<void> inviteAdmin({required String email, String? name}) async {
    try {
      await _supabase.functions.invoke('invite-admin', body: {
        'email': email,
        'name': name,
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Could not send the invite. Please try again.';
      throw Exception(msg);
    }
  }

  Future<void> removeFromWhitelist(String email) async {
    await _supabase
        .from(AppConstants.tableWhitelists)
        .delete()
        .eq('email', email);
  }
}
