import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

class ApiService {
  static const String baseUrl = 'https://backend.dev.savinatestinghub.com/api/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  ApiService() {
    // Ignore SSL certificate errors for dev server
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await AuthProvider.getStoredCookies();
        if (cookies != null && cookies.isNotEmpty) {
          options.headers['cookie'] = cookies;
          final parts = cookies.split('; ');
          for (var part in parts) {
            if (part.startsWith('ep_csrf=')) {
              options.headers['x-csrf-token'] = part.substring('ep_csrf='.length);
            }
          }
        }
        return handler.next(options);
      },
    ));
  }

  // Projects CRUD
  Future<List<Project>> getProjects() async {
    try {
      final response = await _dio.get('/projects', queryParameters: {'limit': 1000});
      if (response.data != null && response.data['data'] != null) {
        final List list = response.data['data'];
        return list.map((item) => Project.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Project> createProject(Project project) async {
    try {
      final response = await _dio.post('/projects', data: project.toJson());
      return Project.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProject(int projectId, Project project) async {
    try {
      await _dio.put('/projects/$projectId', data: project.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProject(int projectId) async {
    try {
      await _dio.delete('/projects/$projectId');
    } catch (e) {
      rethrow;
    }
  }

  // Testings CRUD
  Future<List<Testing>> getTestingsByProject(int projectId) async {
    try {
      final response = await _dio.get('/testings/list/name', queryParameters: {'project_id': projectId});
      if (response.data != null) {
        final List list = response.data;
        return list.map((item) => Testing.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Testing> getTestingDetails(int testingId) async {
    try {
      final response = await _dio.get('/testings/$testingId');
      return Testing.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Testing> createTesting(Testing testing) async {
    try {
      final response = await _dio.post('/testings', data: testing.toJson());
      return Testing.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTesting(int testingId, String testingName) async {
    try {
      await _dio.put('/testings/$testingId', data: {'testing_name': testingName});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTesting(int testingId) async {
    try {
      await _dio.delete('/testings/$testingId');
    } catch (e) {
      rethrow;
    }
  }

  // Power Quality Analysis
  Future<dynamic> startAnalysis({
    required String voltage,
    required List<MultipartFile> dataFiles,
    required int testingId,
    required String pdm,
    required int targetIndex,
    required Map<String, String> thresholdOptions,
    MultipartFile? reportFile,
  }) async {
    try {
      final Map<String, dynamic> thresholdPayload = {
        'pst_threshold': thresholdOptions['pstThreshold'] ?? '',
        'thd_threshold': thresholdOptions['pltThreshold'] ?? '',
        'thd_u_threshold': thresholdOptions['thdUThreshold'] ?? '',
        'tdd_i_threshold': thresholdOptions['tddIThreshold'] ?? '',
        'u_threshold': thresholdOptions['uThreshold'] ?? '',
        'vol_threshold': thresholdOptions['voltageHarmonicThreshold'] ?? '',
        'cur_threshold': thresholdOptions['currentHarmonicThreshold'] ?? '',
      };

      final formData = FormData.fromMap({
        'voltage': voltage,
        'testing_id': testingId.toString(),
        'pdm': pdm,
        'target': targetIndex.toString(),
        'threshold_options': jsonEncode(thresholdPayload),
        'data_files': dataFiles,
        if (reportFile != null) 'report_file': reportFile,
      });

      final response = await _dio.put(
        '/services/advance/power-quality-analysis',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Helper to download binary files (e.g. analysis output Excel sheets)
  Future<List<int>> downloadFile(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {'no-cache': true},
        ),
      );
      return response.data ?? [];
    } catch (e) {
      rethrow;
    }
  }
}
