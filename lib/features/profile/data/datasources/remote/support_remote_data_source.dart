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
    final response = await _supabase.rpc('get_public_support_settings');
    if (response is Map<String, dynamic>) {
      return response;
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    } else if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is List && response.isEmpty) return {};
    throw const FormatException('Invalid support settings response');
  }

  @override
  Future<List<Map<String, dynamic>>> getPolicies(String lang) async {
    final response = await _supabase.rpc(
      'get_public_policies',
      params: {'p_lang': lang},
    );
    if (response is List) {
      return List<Map<String, dynamic>>.from(
        response.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    }
    throw const FormatException('Invalid policies response');
  }

  @override
  Future<List<Map<String, dynamic>>> getFaqs(String lang) async {
    final response = await _supabase.rpc(
      'get_public_faqs',
      params: {'p_lang': lang},
    );
    if (response is List) {
      return List<Map<String, dynamic>>.from(
        response.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    }
    throw const FormatException('Invalid FAQs response');
  }

  @override
  Future<void> createSupportTicket({
    required String issueType,
    required String message,
  }) async {
    await _supabase.rpc(
      'create_support_ticket',
      params: {'p_issue_type': issueType, 'p_message': message},
    );
  }
}
