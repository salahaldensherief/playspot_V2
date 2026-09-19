import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupportRemoteDataSource {
  Future<Map<String, dynamic>> getSupportSettings();
  Future<List<Map<String, dynamic>>> getPolicies(String lang);
  Future<List<Map<String, dynamic>>> getFaqs(String lang);
  Future<void> createSupportTicket({
    required String issueType,
    required String message,
  });
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  final SupabaseClient _supabase;

  SupportRemoteDataSourceImpl(this._supabase);

  @override
  Future<Map<String, dynamic>> getSupportSettings() async {
    try {
      final response = await _supabase.rpc('get_public_support_settings');
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map) {
        return Map<String, dynamic>.from(response);
      } else if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getPolicies(String lang) async {
    try {
      final response = await _supabase.rpc('get_public_policies', params: {'p_lang': lang});
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
    } catch (_) {
      try {
        final response = await _supabase.rpc('get_public_policies', params: {'lang': lang});
        if (response is List) {
          return List<Map<String, dynamic>>.from(
            response.map((item) => Map<String, dynamic>.from(item as Map)),
          );
        }
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getFaqs(String lang) async {
    try {
      final response = await _supabase.rpc('get_public_faqs', params: {'p_lang': lang});
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
    } catch (_) {
      try {
        final response = await _supabase.rpc('get_public_faqs', params: {'lang': lang});
        if (response is List) {
          return List<Map<String, dynamic>>.from(
            response.map((item) => Map<String, dynamic>.from(item as Map)),
          );
        }
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<void> createSupportTicket({
    required String issueType,
    required String message,
  }) async {
    try {
      await _supabase.rpc('create_support_ticket', params: {
        'issue_type': issueType,
        'message': message,
      });
    } catch (_) {
      await _supabase.rpc('create_support_ticket', params: {
        'p_issue_type': issueType,
        'p_message': message,
      });
    }
  }
}
