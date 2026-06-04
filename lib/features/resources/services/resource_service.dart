// ============================================================
// FILE: lib/features/resources/services/resource_service.dart
// PURPOSE: The ONLY layer that touches Supabase for resources.
// Resources ARE per-semester, so we filter by semester here
// (unlike routines, which key on batch+section). Category is
// filtered client-side in the controller for instant chips.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/resource_model.dart';

class ResourceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Resource>> fetchForSemester(int semester) async {
    final rows = await _supabase
        .from(AppConstants.tableResources)
        .select()
        .eq('semester', semester)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Resource.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
