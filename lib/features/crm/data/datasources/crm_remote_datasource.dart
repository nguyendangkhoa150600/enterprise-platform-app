import 'package:dio/dio.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';

/// Remote DataSource giao tiếp trực tiếp với CRM REST API
/// Tiền tố chung: /api/crm/v1
class CrmRemoteDataSource {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 25),
  ));

  CrmRemoteDataSource() {
    ApiClientHelper.configureDio(_dio);
  }

  // 1. Trạng thái & quyền hạn CRM: GET /api/crm/v1/status
  Future<dynamic> getStatusRaw() async {
    final res = await _dio.get(
      '/api/crm/v1/status',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 2. Dashboard KPIs: GET /api/crm/v1/dashboard?period=month|quarter|year
  Future<dynamic> getDashboardRaw({String period = 'month'}) async {
    final res = await _dio.get(
      '/api/crm/v1/dashboard',
      queryParameters: {'period': period},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 3. Khách hàng: GET /api/crm/v1/customers
  Future<dynamic> getCustomersRaw({String? search}) async {
    final q = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();

    final res = await _dio.get(
      '/api/crm/v1/customers',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 4. Cơ hội bán hàng: GET /api/crm/v1/opportunities
  Future<dynamic> getOpportunitiesRaw({String? stage, String? search}) async {
    final q = <String, dynamic>{};
    if (stage != null && stage != 'ALL') q['stage'] = stage;
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();

    final res = await _dio.get(
      '/api/crm/v1/opportunities',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 5. Báo giá: GET /api/crm/v1/quotes
  Future<dynamic> getQuotesRaw({String? status, String? search}) async {
    final q = <String, dynamic>{};
    if (status != null && status != 'ALL') q['status'] = status;
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();

    final res = await _dio.get(
      '/api/crm/v1/quotes',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  // 6. Đầu mối tiềm năng (Leads): GET /api/crm/v1/leads
  Future<dynamic> getLeadsRaw({String? status, String? search}) async {
    final q = <String, dynamic>{};
    if (status != null && status != 'ALL') q['status'] = status;
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();

    final res = await _dio.get(
      '/api/crm/v1/leads',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }
}
