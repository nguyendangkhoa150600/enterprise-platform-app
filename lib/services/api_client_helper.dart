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
