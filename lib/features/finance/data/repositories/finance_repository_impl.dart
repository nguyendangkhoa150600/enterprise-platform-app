import '../../domain/errors/finance_exception.dart';
import '../../domain/models/finance_json.dart';
import '../../domain/models/finance_models.dart';
import '../../domain/repositories/i_finance_repository.dart';
import '../datasources/finance_remote_datasource.dart';

class FinanceRepositoryImpl implements IFinanceRepository {
  final FinanceRemoteDataSource _ds;

  FinanceRepositoryImpl({FinanceRemoteDataSource? remoteDataSource})
      : _ds = remoteDataSource ?? FinanceRemoteDataSource();

  static Map<String, dynamic> _map(dynamic data) => fMap(data);

  static List<Map<String, dynamic>> _items(dynamic data) => data is List ? fList(data) : fList(fMap(data)['items']);

  static Map<String, dynamic> _note(String? note) =>
      (note != null && note.trim().isNotEmpty) ? {'note': note.trim()} : <String, dynamic>{};

  Future<FinanceVoucher> _voucher(Future<dynamic> call) async => FinanceVoucher.fromJson(_map(await call));

  /* Quyền & tổng quan */
  @override
  Future<FinanceCapabilities> getCapabilities() async => FinanceCapabilities.fromJson(_map(await _ds.get('/capabilities')));

  @override
  Future<FinanceDashboard> getDashboard() async => FinanceDashboard.fromJson(_map(await _ds.get('/dashboard')));

  /* Tài khoản */
  @override
  Future<List<FinanceAccount>> getAccounts({bool includeInactive = false}) async {
    final data = await _ds.get('/accounts', query: includeInactive ? {'includeInactive': 'true'} : null);
    return _items(data).map(FinanceAccount.fromJson).toList();
  }

  @override
  Future<FinanceAccount> getAccount(String id) async => FinanceAccount.fromJson(_map(await _ds.get('/accounts/$id')));

  @override
  Future<FinanceAccount> saveAccount(String? id, Map<String, dynamic> body) async {
    final data = id == null ? await _ds.post('/accounts', body) : await _ds.put('/accounts/$id', body);
    return FinanceAccount.fromJson(_map(data));
  }

  @override
  Future<FinanceAccountLedger> getAccountLedger(String id,
      {String? from, String? to, int page = 1, int pageSize = 20}) async {
    final q = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    return FinanceAccountLedger.fromJson(_map(await _ds.get('/accounts/$id/ledger', query: q)));
  }

  /* Danh mục, cài đặt, quy trình duyệt */
  @override
  Future<FinanceCatalogs> getCatalogs({bool includeInactive = false}) async => FinanceCatalogs.fromJson(
      _map(await _ds.get('/catalogs', query: includeInactive ? {'includeInactive': 'true'} : null)));

  @override
  Future<FinanceReason> saveReason(String? id, Map<String, dynamic> body) async {
    final data = id == null ? await _ds.post('/catalogs/reasons', body) : await _ds.put('/catalogs/reasons/$id', body);
    return FinanceReason.fromJson(_map(data));
  }

  @override
  Future<FinanceCounterpartyGroup> saveCounterpartyGroup(String? id, Map<String, dynamic> body) async {
    final data = id == null
        ? await _ds.post('/catalogs/counterparty-groups', body)
        : await _ds.put('/catalogs/counterparty-groups/$id', body);
    return FinanceCounterpartyGroup.fromJson(_map(data));
  }

  @override
  Future<FinanceSettings> getSettings() async => FinanceSettings.fromJson(_map(await _ds.get('/settings')));

  @override
  Future<FinanceSettings> saveSettings(Map<String, dynamic> body) async =>
      FinanceSettings.fromJson(_map(await _ds.put('/settings', body)));

  @override
  Future<List<FinanceApprovalBinding>> getApprovalBindings() async =>
      _items(await _ds.get('/approval-bindings')).map(FinanceApprovalBinding.fromJson).toList();

  @override
  Future<FinanceSaveBindingResult> saveApprovalBinding(FinanceVoucherKind kind, Map<String, dynamic> body) async {
    final j = _map(await _ds.put('/approval-bindings/${kind.api}', body));
    return FinanceSaveBindingResult(
      binding: FinanceApprovalBinding.fromJson(fMap(j['binding'])),
      warnings: fStrings(j['warnings']),
    );
  }

  @override
  Future<List<FinanceProcedureDefinitionOption>> getProcedureDefinitions() async =>
      _items(await _ds.get('/approval-bindings/procedure-definitions'))
          .map(FinanceProcedureDefinitionOption.fromJson)
          .toList();

  @override
  Future<FinanceWorkspaceProjectList> getWorkspaceProjectOptions({String? search}) async {
    final q = (search != null && search.trim().isNotEmpty) ? {'search': search.trim()} : null;
    final data = await _ds.get('/workspace/projects', query: q);
    // Như web: phản hồi sai hình dạng coi như không có dự án.
    final items = data is Map ? fList(data['items']) : fList(data);
    return FinanceWorkspaceProjectList(
      items: items.map(FinanceWorkspaceProject.fromJson).toList(),
      truncated: data is Map && data['truncated'] == true,
    );
  }

  /* Phiếu */
  @override
  Future<FinanceVoucherList> getVouchers(FinanceVoucherQuery query) async =>
      FinanceVoucherList.fromJson(_map(await _ds.get('/vouchers', query: query.toQuery())));

  @override
  Future<FinanceVoucher> getVoucher(String id) => _voucher(_ds.get('/vouchers/$id'));

  @override
  Future<({String id, FinanceVoucherKind kind})> getVoucherByLink(String linkId) async {
    final j = _map(await _ds.get('/vouchers/by-link/${Uri.encodeComponent(linkId)}'));
    final id = fStr(j['id']);
    if (id.isEmpty) throw const FinanceException();
    return (id: id, kind: FinanceVoucherKind.fromApi(j['kind']));
  }

  @override
  Future<String?> getNextCode(FinanceVoucherKind kind, {String? date}) async {
    final q = <String, dynamic>{'kind': kind.api};
    if (date != null && date.isNotEmpty) q['date'] = date;
    return fStrOrNull(_map(await _ds.get('/vouchers/next-code', query: q))['code']);
  }

  @override
  Future<FinanceVoucher> createVoucher(Map<String, dynamic> body) => _voucher(_ds.post('/vouchers', body));

  @override
  Future<FinanceVoucher> updateVoucher(String id, Map<String, dynamic> body) => _voucher(_ds.put('/vouchers/$id', body));

  @override
  Future<void> deleteVoucher(String id) async => _ds.delete('/vouchers/$id');

  @override
  Future<FinanceVoucher> submitVoucher(String id) => _voucher(_ds.post('/vouchers/$id/submit'));

  @override
  Future<FinanceVoucher> approveVoucher(String id, {String? note}) => _voucher(_ds.post('/vouchers/$id/approve', _note(note)));

  @override
  Future<FinanceVoucher> rejectVoucher(String id, {String? note}) => _voucher(_ds.post('/vouchers/$id/reject', _note(note)));

  @override
  Future<FinanceVoucher> cancelVoucher(String id, {String? note}) => _voucher(_ds.post('/vouchers/$id/cancel', _note(note)));

  @override
  Future<FinanceVoucher> reverseVoucher(String id, {String? note}) =>
      _voucher(_ds.post('/vouchers/$id/reverse', _note(note)));

  @override
  Future<FinanceBulkApproveResult> bulkApprove(List<String> ids, {String? note}) async =>
      FinanceBulkApproveResult.fromJson(_map(await _ds.post('/vouchers/bulk-approve', {'ids': ids, ..._note(note)})));

  @override
  Future<FinanceVoucher> procedureAction(String id,
          {required String action, String? comment, required String idempotencyKey}) =>
      _voucher(_ds.post('/vouchers/$id/procedure-action', {
        'action': action,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        'idempotencyKey': idempotencyKey,
      }));

  @override
  Future<FinanceVoucher> retryProcedure(String id) => _voucher(_ds.post('/vouchers/$id/procedure-retry'));

  @override
  Future<FinanceVoucher> postSourced(String id, {String? note, int? revision}) =>
      _voucher(_ds.post('/vouchers/$id/post-sourced', {..._note(note), 'revision': ?revision}));

  @override
  Future<FinanceVoucher> returnSource(String id, {required String reason, int? revision}) =>
      _voucher(_ds.post('/vouchers/$id/return-source', {'reason': reason.trim(), 'revision': ?revision}));

  @override
  Future<FinanceVoucher> takeOver(String id) => _voucher(_ds.post('/vouchers/$id/take-over'));

  @override
  Future<FinanceVoucher> retrySourceReversal(String id) => _voucher(_ds.post('/vouchers/$id/retry-source-reversal'));

  /* Đính kèm */
  @override
  Future<FinanceVoucherAttachment> uploadAttachment(
    String voucherId, {
    required String fileName,
    required String contentType,
    required List<int> bytes,
    String purpose = 'ATTACHMENT',
  }) async {
    final created = _map(await _ds.post('/vouchers/$voucherId/attachments', {
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': bytes.length,
      'purpose': purpose,
    }));
    final attachmentId = fStr(created['id']);
    final uploadUrl = fStr(created['uploadUrl']);
    if (attachmentId.isEmpty || uploadUrl.isEmpty) throw const FinanceException();
    await _ds.putToStorage(uploadUrl, bytes, fStr(created['contentType'], contentType));
    return FinanceVoucherAttachment.fromJson(
        _map(await _ds.post('/vouchers/$voucherId/attachments/$attachmentId/complete')));
  }

  @override
  Future<String?> getAttachmentDownloadUrl(String voucherId, String attachmentId) async =>
      fStrOrNull(_map(await _ds.get('/vouchers/$voucherId/attachments/$attachmentId/download'))['url']);

  @override
  Future<void> deleteAttachment(String voucherId, String attachmentId) async =>
      _ds.delete('/vouchers/$voucherId/attachments/$attachmentId');

  /* Báo cáo */
  @override
  Future<FinanceReport> getReport({required String from, required String to, String? accountId, String? projectId}) async {
    final q = <String, dynamic>{'from': from, 'to': to};
    if (accountId != null && accountId.isNotEmpty) q['accountId'] = accountId;
    if (projectId != null && projectId.isNotEmpty) q['projectId'] = projectId;
    return FinanceReport.fromJson(_map(await _ds.get('/reports/summary', query: q)));
  }

  @override
  Future<FinanceLedgerReport> getLedgerReport({
    required String from,
    required String to,
    String? accountId,
    int offset = 0,
    int limit = 50,
  }) async {
    final q = <String, dynamic>{'from': from, 'to': to, 'offset': offset, 'limit': limit};
    if (accountId != null && accountId.isNotEmpty) q['accountId'] = accountId;
    return FinanceLedgerReport.fromJson(_map(await _ds.get('/reports/ledger', query: q)));
  }
}
