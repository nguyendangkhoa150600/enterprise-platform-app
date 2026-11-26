import '../../domain/common/crm_catalog_models.dart';
import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/warranty/crm_warranty_models.dart';
import '../crm_api_client.dart';

/// Bảo hành, đổi trả (web `crm-api.ts` mục GĐ6).
class CrmWarrantyRepository {
  CrmWarrantyRepository._();
  static final CrmWarrantyRepository instance = CrmWarrantyRepository._();

  final CrmApiClient _api = CrmApiClient.instance;
  static String _s(String v) => CrmApiClient.seg(v);

  Future<List<CrmWarrantyLookupItem>> lookup({required String serial}) async =>
      CrmJson.list(await _api.get('/warranty/lookup', query: {'serial': serial}), CrmWarrantyLookupItem.fromJson);

  Future<CrmWarrantySerialHistory> serialHistory(String serial) async =>
      CrmWarrantySerialHistory.fromJson(CrmJson.map(await _api.get('/warranty/serials/${_s(serial)}/history')));

  Future<CrmPage<CrmWarrantyCaseSummary>> listCases({String? q, String? status, required int page}) async {
    final raw = await _api.get('/warranty/cases', query: {
      'q': q,
      'status': status,
      'page': page,
      'limit': kCrmListPageSize,
    });
    return CrmPage.fromJson(raw, CrmWarrantyCaseSummary.fromJson);
  }

  Future<CrmWarrantyCaseDetail> getCase(String id) async =>
      CrmWarrantyCaseDetail.fromJson(CrmJson.map(await _api.get('/warranty/cases/${_s(id)}')));

  Future<List<CrmWarrantyDeviceDocument>> deviceDocuments(String id) async => CrmJson.list(
      await _api.get('/warranty/cases/${_s(id)}/device-documents'), CrmWarrantyDeviceDocument.fromJson);

  Future<CrmWarrantyCaseDetail> createCase({
    required String cause,
    String? description,
    String? assigneeUserId,
    required List<String> serials,
  }) async =>
      CrmWarrantyCaseDetail.fromJson(CrmJson.map(await _api.post('/warranty/cases', {
        'cause': cause,
        'description': description,
        'assigneeUserId': assigneeUserId,
        'lines': [for (final s in serials) {'serial': s}],
      })));

  /// [action] `receive` | `reject` | `sync-documents` | `close`.
  Future<CrmWarrantyCaseDetail> action(String id, String action, {required int revision, String? reason}) async =>
      CrmWarrantyCaseDetail.fromJson(CrmJson.map(await _api.post('/warranty/cases/${_s(id)}/$action', {
        'revision': revision,
        'reason': ?reason,
      })));

  Future<CrmWarrantyCaseDetail> inspectLine(String id, String lineId,
          {required int revision, required String result, String? note}) async =>
      CrmWarrantyCaseDetail.fromJson(CrmJson.map(await _api.post(
          '/warranty/cases/${_s(id)}/lines/${_s(lineId)}/inspect', {'revision': revision, 'result': result, 'note': note})));

  Future<CrmWarrantyCaseDetail> resolveLine(
    String id,
    String lineId, {
    required int revision,
    required String disposition,
    required String remedy,
    String? replacementWarehouseCode,
    String? note,
  }) async =>
      CrmWarrantyCaseDetail.fromJson(CrmJson.map(await _api.post('/warranty/cases/${_s(id)}/lines/${_s(lineId)}/resolve', {
        'revision': revision,
        'disposition': disposition,
        'remedy': remedy,
        'replacementWarehouseCode': replacementWarehouseCode,
        'note': note,
      })));

  Future<CrmWarrantySettings> loadSettings() async =>
      CrmWarrantySettings.fromJson(CrmJson.map(await _api.get('/warranty/settings')));

  Future<CrmWarrantySettings> saveSettings(
          {required String quarantine, required String defect, String? restock}) async =>
      CrmWarrantySettings.fromJson(CrmJson.map(await _api.put('/warranty/settings', {
        'quarantineWarehouseCode': quarantine,
        'defectWarehouseCode': defect,
        'restockWarehouseCode': restock,
      })));

  /// Kho của Kho kèm kho đang chọn (web `loadWarehouses(codes)`: `codes` lấy thêm kho đã ngừng đang được chọn).
  Future<List<CrmWarehouseOption>> loadWarehouses(List<String> codes) async => CrmJson.list(
      await _api.get('/catalog/warehouses', query: {'codes': codes.join(',')}), CrmWarehouseOption.fromJson);
}
