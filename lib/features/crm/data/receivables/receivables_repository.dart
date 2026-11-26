import '../../domain/common/crm_json.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../crm_api_client.dart';

/// Công nợ, thu tiền, điều chỉnh (web `crm-api.ts` mục GĐ5).
class CrmReceivablesRepository {
  CrmReceivablesRepository._();
  static final CrmReceivablesRepository instance = CrmReceivablesRepository._();

  final CrmApiClient _api = CrmApiClient.instance;
  static String _s(String v) => CrmApiClient.seg(v);

  /// `GET /receivables/aging` (web gọi `limit: 500`, phân trang tại chỗ).
  Future<CrmPage<CrmCustomerAgingRow>> loadAging({String? q, String? ownerUserId, bool overdue = false}) async {
    final raw = await _api.get('/receivables/aging', query: {
      'q': q,
      'ownerUserId': ownerUserId,
      'overdue': overdue ? true : null,
      'limit': 500,
    });
    return CrmPage.fromJson(raw, CrmCustomerAgingRow.fromJson);
  }

  Future<CrmCustomerLedger> loadLedger(String customerId) async =>
      CrmCustomerLedger.fromJson(CrmJson.map(await _api.get('/receivables/customers/${_s(customerId)}')));

  Future<CrmPage<CrmReceipt>> listReceipts({String? customerId, String? status, required int page}) async {
    final raw = await _api.get('/receipts', query: {
      'customerId': customerId,
      'status': status,
      'page': page,
      'limit': kCrmListPageSize,
    });
    return CrmPage.fromJson(raw, CrmReceipt.fromJson);
  }

  Future<CrmReceipt> getReceipt(String id) async => CrmReceipt.fromJson(CrmJson.map(await _api.get('/receipts/${_s(id)}')));

  Future<CrmReceipt> createReceipt({
    required String customerId,
    required double amount,
    required String method,
    String? receiptDate,
    String? note,
    required List<Map<String, dynamic>> allocations,
  }) async =>
      CrmReceipt.fromJson(CrmJson.map(await _api.post('/receipts', {
        'customerId': customerId,
        'amount': amount,
        'method': method,
        'receiptDate': receiptDate,
        'note': note,
        'allocations': allocations,
      })));

  Future<CrmReceipt> resendReceipt(String id,
          {required int revision, required double amount, required List<Map<String, dynamic>> allocations}) async =>
      CrmReceipt.fromJson(CrmJson.map(await _api.post('/receipts/${_s(id)}/resend', {
        'revision': revision,
        'amount': amount,
        'allocations': allocations,
      })));

  Future<CrmReceipt> cancelReceipt(String id, {required int revision, required String reason}) async =>
      CrmReceipt.fromJson(
          CrmJson.map(await _api.post('/receipts/${_s(id)}/cancel', {'revision': revision, 'reason': reason})));

  Future<CrmPage<CrmReceivableAdjustment>> listAdjustments({String? customerId, String? status, required int page}) async {
    final raw = await _api.get('/receivable-adjustments', query: {
      'customerId': customerId,
      'status': status,
      'page': page,
      'limit': kCrmListPageSize,
    });
    return CrmPage.fromJson(raw, CrmReceivableAdjustment.fromJson);
  }

  Future<CrmReceivableAdjustment> createAdjustment({
    required String customerId,
    required String direction,
    required double amount,
    required String reason,
    String? entryId,
    String? orderId,
  }) async =>
      CrmReceivableAdjustment.fromJson(CrmJson.map(await _api.post('/receivable-adjustments', {
        'customerId': customerId,
        'direction': direction,
        'amount': amount,
        'reason': reason,
        'entryId': entryId,
        'orderId': orderId,
      })));

  /// [action] `approve` | `cancel`.
  Future<CrmReceivableAdjustment> adjustmentAction(String id, String action,
          {required int revision, String? reason}) async =>
      CrmReceivableAdjustment.fromJson(CrmJson.map(await _api
          .post('/receivable-adjustments/${_s(id)}/$action', {'revision': revision, 'reason': reason})));

  Future<CrmReceivableSettings> loadSettings() async =>
      CrmReceivableSettings.fromJson(CrmJson.map(await _api.get('/receivable-settings')));

  Future<CrmReceivableSettings> saveSettings({required String creditLimitMode, required List<String> alertUserIds}) async =>
      CrmReceivableSettings.fromJson(CrmJson.map(await _api.put('/receivable-settings', {
        'creditLimitMode': creditLimitMode,
        'alertUserIds': alertUserIds,
      })));
}
