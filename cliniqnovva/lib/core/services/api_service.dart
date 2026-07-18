import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'firebase_service.dart';

/// Normalized error surfaced to callers instead of a raw DioException —
/// [message] is safe to show directly in the UI.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Dio-based HTTP client for the Node.js backend. Every request is a candidate
/// for carrying the caller's Firebase ID token — clinical/financial writes
/// always go through the backend, never direct Firestore client writes
/// (spec section 10, chat is the one deliberate exception).
class ApiService {
  ApiService._internal() {
    _dio = Dio(BaseOptions(baseUrl: AppConstants.backendBaseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseService.auth.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiService instance = ApiService._internal();
  late final Dio _dio;

  Dio get client => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _wrap(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _wrap(() => _dio.post<T>(path, data: data));
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return _wrap(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) {
    return _wrap(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path) {
    return _wrap(() => _dio.delete<T>(path));
  }

  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException(_messageFor(e), statusCode: e.response?.statusCode);
    }
  }

  String _messageFor(DioException e) {
    final serverError = e.response?.data is Map ? (e.response!.data as Map)['error'] : null;
    if (serverError is String && serverError.isNotEmpty) return serverError;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "The server took too long to respond. Please try again.";
      case DioExceptionType.connectionError:
        return "We couldn't reach the server. Check your connection and try again.";
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
