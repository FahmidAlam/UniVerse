// ============================================================
// FILE: lib/features/profile/services/profile_service.dart
// PURPOSE: The ONLY layer that touches Supabase for profile reads
// and updates. Returns the typed Profile model.
// ProfileController calls this; screens never touch it.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/profile_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _supabase
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  Future<Profile?> updateProfile({
    required String userId,
    required Map<String, dynamic> changes,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableProfiles)
        .update(changes)
        .eq('id', userId)
        .select()
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }
}
