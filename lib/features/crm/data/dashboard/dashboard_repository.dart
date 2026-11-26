import '../../domain/common/crm_json.dart';
import '../../domain/dashboard/crm_dashboard_models.dart';
import '../crm_api_client.dart';

/// Dashboard Tổng quan (web `crm-api.ts loadDashboard`): chỉ cần `crm.read`.
class CrmDashboardRepository {
  CrmDashboardRepository._();
  static final CrmDashboardRepository instance = CrmDashboardRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// `GET /dashboard?period=…[&from&to]`.
  Future<CrmSalesDashboard> load({required String period, String? from, String? to}) async =>
      CrmSalesDashboard.fromJson(
          CrmJson.map(await _api.get('/dashboard', query: {'period': period, 'from': from, 'to': to})));
}
