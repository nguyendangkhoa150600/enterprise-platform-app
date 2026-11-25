import '../models/finance_models.dart';

/// Hợp đồng truy cập dữ liệu Tài chính (`/api/finance/v1`).
/// Mọi lỗi ném [FinanceException] (lời nhắn tiếng Việt của server ở `displayMessage`).
/// Thân lưu (`body`) theo đúng contract web (`Save...Request`), do tầng trình bày dựng.
abstract class IFinanceRepository {
  /* Quyền & tổng quan */
  Future<FinanceCapabilities> getCapabilities();
  Future<FinanceDashboard> getDashboard();

  /* Tài khoản */
  Future<List<FinanceAccount>> getAccounts({bool includeInactive = false});
  Future<FinanceAccount> getAccount(String id);

  /// [id] null: tạo mới (POST), có: cập nhật (PUT). Body = `SaveFinanceAccountRequest`.
  Future<FinanceAccount> saveAccount(String? id, Map<String, dynamic> body);
  Future<FinanceAccountLedger> getAccountLedger(String id, {String? from, String? to, int page = 1, int pageSize = 20});

  /* Danh mục, cài đặt, quy trình duyệt */
  Future<FinanceCatalogs> getCatalogs({bool includeInactive = false});

  /// Body = `SaveFinanceReasonRequest` ({kind, code, name, isActive, note, requireProject}).
  Future<FinanceReason> saveReason(String? id, Map<String, dynamic> body);

  /// Body = `SaveFinanceCounterpartyGroupRequest` ({code, name, isActive}).
  Future<FinanceCounterpartyGroup> saveCounterpartyGroup(String? id, Map<String, dynamic> body);
  Future<FinanceSettings> getSettings();
  Future<FinanceSettings> saveSettings(Map<String, dynamic> body);
  Future<List<FinanceApprovalBinding>> getApprovalBindings();

  /// Body = {mode: 'DIRECT'|'PROCEDURE', procedureDefinitionId}.
  Future<FinanceSaveBindingResult> saveApprovalBinding(FinanceVoucherKind kind, Map<String, dynamic> body);
  Future<List<FinanceProcedureDefinitionOption>> getProcedureDefinitions();

  /* Dự án Workspace (để hạch toán / dự án liên quan) */
  Future<FinanceWorkspaceProjectList> getWorkspaceProjectOptions({String? search});

  /* Phiếu */
  Future<FinanceVoucherList> getVouchers(FinanceVoucherQuery query);
  Future<FinanceVoucher> getVoucher(String id);

  /// Phiếu của một lần gửi duyệt từ hồ sơ quy trình (`GET /vouchers/by-link/:linkId`, web open-link-screen).
  Future<({String id, FinanceVoucherKind kind})> getVoucherByLink(String linkId);

  /// Mã nháp dự kiến của phiếu mới (`GET /vouchers/next-code`).
  Future<String?> getNextCode(FinanceVoucherKind kind, {String? date});

  /// Body = `SaveFinanceVoucherRequest`.
  Future<FinanceVoucher> createVoucher(Map<String, dynamic> body);
  Future<FinanceVoucher> updateVoucher(String id, Map<String, dynamic> body);
  Future<void> deleteVoucher(String id);
  Future<FinanceVoucher> submitVoucher(String id);
  Future<FinanceVoucher> approveVoucher(String id, {String? note});
  Future<FinanceVoucher> rejectVoucher(String id, {String? note});
  Future<FinanceVoucher> cancelVoucher(String id, {String? note});

  /// Huỷ phiếu đã ghi sổ (đảo bút toán).
  Future<FinanceVoucher> reverseVoucher(String id, {String? note});
  Future<FinanceBulkApproveResult> bulkApprove(List<String> ids, {String? note});

  /// Thao tác trên hồ sơ quy trình của phiếu: [action] = approve | reject | return.
  Future<FinanceVoucher> procedureAction(String id, {required String action, String? comment, required String idempotencyKey});
  Future<FinanceVoucher> retryProcedure(String id);

  /* Phiếu có nguồn hồ sơ quy trình (INHERITED) */
  Future<FinanceVoucher> postSourced(String id, {String? note, int? revision});
  Future<FinanceVoucher> returnSource(String id, {required String reason, int? revision});
  Future<FinanceVoucher> takeOver(String id);
  Future<FinanceVoucher> retrySourceReversal(String id);

  /* Đính kèm */
  /// Tạo bản ghi → PUT file lên `uploadUrl` → xác nhận hoàn tất. [purpose]: ATTACHMENT | NOTE_IMAGE.
  Future<FinanceVoucherAttachment> uploadAttachment(
    String voucherId, {
    required String fileName,
    required String contentType,
    required List<int> bytes,
    String purpose = 'ATTACHMENT',
  });

  /// Link tải tạm thời (hết hạn sau ~2 phút).
  Future<String?> getAttachmentDownloadUrl(String voucherId, String attachmentId);
  Future<void> deleteAttachment(String voucherId, String attachmentId);

  /* Báo cáo */
  Future<FinanceReport> getReport({required String from, required String to, String? accountId, String? projectId});
  Future<FinanceLedgerReport> getLedgerReport({
    required String from,
    required String to,
    String? accountId,
    int offset = 0,
    int limit = 50,
  });
}
