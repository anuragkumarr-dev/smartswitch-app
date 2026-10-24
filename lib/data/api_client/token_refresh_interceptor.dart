import 'package:dio/dio.dart';
import '../../core/auth/auth_service.dart';
import '../secure_store/secure_key_store.dart';

/// Dio Interceptor handling bearer token injection and automatic 401 refresh-token rotation (Blueprint §5).
class TokenRefreshInterceptor extends Interceptor {
  final Dio dio;
  final SecureKeyStore secureStorage;
  final AuthService authService;

  bool _isRefreshing = false;
  final List<void Function(String newAccessToken)> _pendingRequestsQueue = [];

  TokenRefreshInterceptor({
    required this.dio,
    required this.secureStorage,
    required this.authService,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Inject Authorization header if not already provided
    if (!options.headers.containsKey('Authorization')) {
      final token = await secureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check for 401 Unauthorized
    if (err.response?.statusCode == 401 && !err.requestOptions.extra.containsKey('is_retry')) {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null) {
        return handler.next(err);
      }

      if (_isRefreshing) {
        // Queue subsequent requests while refresh is in flight
        _pendingRequestsQueue.add((newToken) {
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          err.requestOptions.extra['is_retry'] = true;
          dio.fetch(err.requestOptions).then(
                (res) => handler.resolve(res),
                onError: (e) => handler.reject(e as DioException),
              );
        });
        return;
      }

      _isRefreshing = true;

      try {
        // Rotate refresh token
        final newSession = await authService.refreshToken(refreshToken);
        final newAccessToken = newSession.accessToken;

        // Drain pending queue
        for (final callback in _pendingRequestsQueue) {
          callback(newAccessToken);
        }
        _pendingRequestsQueue.clear();

        // Retry the original failed request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        err.requestOptions.extra['is_retry'] = true;
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (refreshErr) {
        _pendingRequestsQueue.clear();
        await secureStorage.clearTokens();
        return handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }
}
