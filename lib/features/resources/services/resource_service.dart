import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/resource_model.dart';

class ResourceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Resource>> fetchForSemester(int semester) async {
    final rows = await _supabase
        .from(AppConstants.tableResources)
        .select()
        .eq('semester', semester)
        .order('created_at', ascending: false);
    return _map(rows);
  }

  Future<List<Resource>> fetchAll() async {
    final rows = await _supabase
        .from(AppConstants.tableResources)
        .select()
        .order('created_at', ascending: false);
    return _map(rows);
  }

  Future<String> uploadFile(
    Uint8List bytes,
    String filename,
    int semester,
  ) async {
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$semester/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _supabase.storage.from(AppConstants.bucketResources).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentType(safe)),
        );
    return _supabase.storage
        .from(AppConstants.bucketResources)
        .getPublicUrl(path);
  }

  Future<void> createResource(Map<String, dynamic> data) async {
    await _supabase.from(AppConstants.tableResources).insert({
      ...data,
      'uploaded_by': _supabase.auth.currentUser?.id,
    });
  }

  Future<void> deleteResource(String id) async {
    await _supabase.from(AppConstants.tableResources).delete().eq('id', id);
  }

  List<Resource> _map(List<dynamic> rows) => rows
      .map((r) => Resource.fromMap(r as Map<String, dynamic>))
      .toList();

  String _contentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.doc')) return 'application/msword';
    if (n.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document';
    }
    if (n.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (n.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument'
          '.presentationml.presentation';
    }
    if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (n.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument'
          '.spreadsheetml.sheet';
    }
    if (n.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }
}
