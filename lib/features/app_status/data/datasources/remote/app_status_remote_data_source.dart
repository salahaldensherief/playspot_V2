import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_status_model.dart';

abstract class AppStatusRemoteDataSource {
  Future<AppStatusModel> getAppStatus();
  Stream<AppStatusModel> streamAppStatus();
}

class AppStatusRemoteDataSourceImpl implements AppStatusRemoteDataSource {
  final SupabaseClient _client;

  AppStatusRemoteDataSourceImpl(this._client);

  @override
  Future<AppStatusModel> getAppStatus() async {
    try {
      final response = await _client
          .from('app_status')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return const AppStatusModel(
          maintenanceMode: false,
          minSupportedVersion: '1.0.0',
          latestVersion: '1.0.0',
        );
      }

      return AppStatusModel.fromJson(response);
    } catch (e, stack) {
      dev.log("[AppStatusRemoteDataSource] Error fetching app_status: $e", stackTrace: stack);
      return const AppStatusModel(
        maintenanceMode: false,
        minSupportedVersion: '1.0.0',
        latestVersion: '1.0.0',
      );
    }
  }

  @override
  Stream<AppStatusModel> streamAppStatus() {
    return _client
        .from('app_status')
        .stream(primaryKey: ['id'])
        .map((data) {
          if (data.isEmpty) {
            return const AppStatusModel(
              maintenanceMode: false,
              minSupportedVersion: '1.0.0',
              latestVersion: '1.0.0',
            );
          }
          return AppStatusModel.fromJson(data.first);
        });
  }
}
