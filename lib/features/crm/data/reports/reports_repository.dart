import '../../domain/common/crm_json.dart';
import '../../domain/reports/crm_report_models.dart';
import '../crm_api_client.dart';

/// Báo cáo Bán hàng (web `crm-api.ts`: `loadSalesReport`, `loadConversionReport`, `loadSalesAlerts`,
/// `loadReceivableReport`). Cần `crm.report.read` hoặc quản trị tenant. Giá trị rỗng bị bỏ khỏi truy vấn.
class CrmReportsRepository {
  CrmReportsRepository._();
  static final CrmReportsRepository instance = CrmReportsRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// `GET /reports/sales?from&to&ownerUserId&customerGroupId&region&groupBy`.
  Future<CrmSalesReport> sales(Map<String, dynamic> query) async =>
      CrmSalesReport.fromJson(CrmJson.map(await _api.get('/reports/sales', query: query)));

  /// `GET /reports/conversion?from&to&ownerUserId`.
  Future<CrmConversionReport> conversion(Map<String, dynamic> query) async =>
      CrmConversionReport.fromJson(CrmJson.map(await _api.get('/reports/conversion', query: query)));

  /// `GET /reports/alerts?ownerUserId&kind`.
  Future<CrmSalesAlertList> alerts(Map<String, dynamic> query) async =>
      CrmSalesAlertList.fromJson(CrmJson.map(await _api.get('/reports/alerts', query: query)));

  /// `GET /reports/receivables?ownerUserId&customerGroupId&region`.
  Future<CrmReceivableReport> receivables(Map<String, dynamic> query) async =>
      CrmReceivableReport.fromJson(CrmJson.map(await _api.get('/reports/receivables', query: query)));
}
