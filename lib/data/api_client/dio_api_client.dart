import 'package:dio/dio.dart';
import '../../core/auth/auth_service.dart';
import '../../domain/models/models.dart';
import '../secure_store/secure_key_store.dart';
import 'api_client.dart';
import 'certificate_pinning_interceptor.dart';
import 'token_refresh_interceptor.dart';

/// Production [ApiClient] implementation powered by [Dio] with certificate pinning
/// and automatic token refresh (Blueprint §3.6 & §5).
class DioApiClient implements ApiClient {
  final Dio dio;
  final String baseUrl;

  DioApiClient({
    required this.baseUrl,
    required SecureKeyStore secureStorage,
    required AuthService authService,
    CertificatePinningConfig? pinningConfig,
    Dio? dioClient,
  }) : dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            ) {
    if (pinningConfig != null) {
      dio.interceptors.add(CertificatePinningInterceptor(config: pinningConfig));
    }
    dio.interceptors.add(
      TokenRefreshInterceptor(
        dio: dio,
        secureStorage: secureStorage,
        authService: authService,
      ),
    );
  }

  @override
  Future<List<Home>> getHomes() async {
    final response = await dio.get<List<dynamic>>('/homes');
    final list = response.data ?? [];
    return list.map((e) => Home.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Device>> getDevicesSnapshot(String homeId) async {
    final response = await dio.get<List<dynamic>>('/homes/$homeId/devices');
    final list = response.data ?? [];
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Schedule>> getSchedules(String deviceId) async {
    final response = await dio.get<List<dynamic>>('/devices/$deviceId/schedules');
    final list = response.data ?? [];
    return list.map((e) => Schedule.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> updateSchedule(String deviceId, Schedule schedule) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/devices/$deviceId/schedules/${schedule.scheduleId}',
      data: schedule.toJson(),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
