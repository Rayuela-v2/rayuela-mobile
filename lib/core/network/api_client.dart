import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../error/app_exception.dart';
import '../error/result.dart';
import '../storage/secure_token_store.dart';
import 'auth_interceptor.dart';
import 'refresh_interceptor.dart';

/// Thin typed wrapper around [Dio]. UI code never touches Dio directly —
/// repositories call [request] with a lambda and a parser, and get a
/// [Result] back.
class ApiClient {
  ApiClient({
    required SecureTokenStore tokens,
    required FutureOr<void> Function() onAuthFailure,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: Env.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                contentType: Headers.jsonContentType,
                headers: {
                  HttpHeaders.acceptHeader: 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(AuthInterceptor(tokens));
    _dio.interceptors.add(
      RefreshInterceptor(
        dio: _dio,
        tokens: tokens,
        onAuthFailure: onAuthFailure,
      ),
    );
    if (Env.logHttp) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestBody: true,
          maxWidth: 120,
          filter: (options, args) {
            // Never log auth bodies.
            if (options.path.contains('/auth/')) return false;
            return true;
          },
        ),
      );
    }
  }

  final Dio _dio;

  Dio get raw => _dio;

  /// Run a Dio call and parse the response. Any thrown [DioException] is
  /// translated into a typed [AppException] via [_mapError].
  Future<Result<T>> request<T>(
    Future<Response<dynamic>> Function(Dio dio) send, {
    required T Function(Object? json) parse,
  }) async {
    try {
      final response = await send(_dio);
      return Success<T>(parse(response.data));
    } on DioException catch (e) {
      return Failure<T>(_mapError(e));
    } catch (e) {
      return Failure<T>(
          UnknownException(message: e.toString(), cause: e),);
    }
  }

  /// Translate a [DioException] into the app's typed exception hierarchy.
  /// Exposed so call-sites that need to read the raw response body (e.g.
  /// `POST /auth/google` to detect `requiresUsername`) can fall back to
  /// the standard mapping for everything else.
  AppException mapDioError(DioException e) => _mapError(e);

  AppException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(cause: e);
      case DioExceptionType.connectionError:
        return NetworkException(cause: e);
      case DioExceptionType.badCertificate:
        return const ServerException(message: 'Secure connection failed');
      case DioExceptionType.cancel:
        return UnknownException(message: 'Request cancelled', cause: e);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return NetworkException(cause: e);
        }
        return UnknownException(
            message: e.message ?? 'Unknown error', cause: e,);
      case DioExceptionType.badResponse:
        return _mapBadResponse(e);
    }
  }

  AppException _mapBadResponse(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    final message = _extractMessage(data) ?? 'Server error ($status)';
    switch (status) {
      case 400:
      case 422:
        return ValidationException(
          message: message,
          fieldErrors: _extractFieldErrors(data),
          cause: e,
        );
      case 401:
        return UnauthorizedException(message: message, cause: e);
      case 403:
        return ForbiddenException(message: message, cause: e);
      case 404:
        return NotFoundException(message: message, cause: e);
      case 409:
        return ConflictException(message: message, cause: e);
      case >= 500:
        return ServerException(message: message, statusCode: status, cause: e);
      default:
        return ServerException(message: message, statusCode: status, cause: e);
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      final err = data['error'];
      if (err is String) return err;
    }
    return null;
  }

  Map<String, String> _extractFieldErrors(Object? data) {
    // NestJS class-validator style:
    // { message: ['email must be an email', 'password should not be empty'] }
    if (data is Map && data['message'] is List) {
      final out = <String, String>{};
      for (final raw in (data['message'] as List)) {
        final s = raw.toString();
        final field = s.split(' ').first;
        out.putIfAbsent(field, () => s);
      }
      return out;
    }
    return const {};
  }
}
