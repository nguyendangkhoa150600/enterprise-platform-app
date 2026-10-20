import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';

class ApiClientHelper {
  /// Configure Dio with SSL bypass, cookie injection, continuous cookie updates,
  /// and automatic silent session renewal on 401 Unauthorized.
  static void configureDio(Dio dio) {
    // 1. Ignore SSL certificate errors for dev server
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    // 2. Add Auth and Auto-Refresh Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ensure we don't end up with double /api/api
          if (options.path.startsWith('/api/')) {
            if (options.baseUrl.endsWith('/api') || options.baseUrl.endsWith('/api/')) {
              options.path = options.path.substring(4);
            }
          } else if (options.path.startsWith('/hrm/') && !options.baseUrl.contains('/api')) {
            options.path = '/api${options.path}';
          }

          final cookies = await AuthProvider.getStoredCookies();
          if (cookies != null && cookies.isNotEmpty) {
            options.headers['cookie'] = cookies;
            final csrf = AuthProvider.extractCsrf(cookies);
            if (csrf.isNotEmpty) {
              options.headers['x-csrf-token'] = csrf;
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          final setCookies = response.headers['set-cookie'];
          if (setCookies != null && setCookies.isNotEmpty) {
            await AuthProvider.updateCookiesFromSetCookie(setCookies);
          }

          // If 401 returned (e.g. when validateStatus allows 401) and not retried yet, renew session
          if (response.statusCode == 401 && response.requestOptions.extra['_retry'] != true) {
            debugPrint('[ApiClientHelper] Received 401 in onResponse on ${response.requestOptions.path}. Attempting silent relogin...');
            response.requestOptions.extra['_retry'] = true;
            try {
              final renewed = await AuthProvider.silentRelogin();
              if (renewed) {
                debugPrint('[ApiClientHelper] Silent session renewal succeeded! Retrying request ${response.requestOptions.path}');
                final newCookies = await AuthProvider.getStoredCookies();
                if (newCookies != null && newCookies.isNotEmpty) {
                  response.requestOptions.headers['cookie'] = newCookies;
                  final csrf = AuthProvider.extractCsrf(newCookies);
                  if (csrf.isNotEmpty) {
                    response.requestOptions.headers['x-csrf-token'] = csrf;
                  }
                }
                final retryRes = await dio.fetch(response.requestOptions);
                return handler.resolve(retryRes);
              }
            } catch (retryErr) {
              debugPrint('[ApiClientHelper] Silent relogin failed from onResponse: $retryErr');
            }
          }

          return handler.next(response);
        },
        onError: (DioException err, handler) async {
          // If 401 and we haven't retried yet, attempt silent session renewal
          if (err.response?.statusCode == 401 && err.requestOptions.extra['_retry'] != true) {
            debugPrint('[ApiClientHelper] Received 401 on ${err.requestOptions.path}. Attempting silent relogin...');
            err.requestOptions.extra['_retry'] = true;
            try {
              final renewed = await AuthProvider.silentRelogin();
              if (renewed) {
                debugPrint('[ApiClientHelper] Silent session renewal succeeded! Retrying request ${err.requestOptions.path}');
                final newCookies = await AuthProvider.getStoredCookies();
                if (newCookies != null && newCookies.isNotEmpty) {
                  err.requestOptions.headers['cookie'] = newCookies;
                  final csrf = AuthProvider.extractCsrf(newCookies);
                  if (csrf.isNotEmpty) {
                    err.requestOptions.headers['x-csrf-token'] = csrf;
                  }
                }
                final response = await dio.fetch(err.requestOptions);
                return handler.resolve(response);
              }
            } catch (retryErr) {
              debugPrint('[ApiClientHelper] Silent relogin failed: $retryErr');
            }
          }
          return handler.next(err);
        },
      ),
    );
  }
}
