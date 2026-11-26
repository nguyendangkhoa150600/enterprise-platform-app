/// Model Tài chính (web `contracts-finance.ts`): loại/trạng thái phiếu, quyền, tài khoản, danh mục, cài đặt.
/// Barrel: import file này là đủ cho mọi model Tài chính.
library;

import 'finance_json.dart';

export 'finance_report_models.dart';
export 'finance_voucher_models.dart';

/* ------------------------------ Loại & trạng thái ------------------------------ */

enum FinanceVoucherKind {
  receipt('RECEIPT', 'PT'),
  payment('PAYMENT', 'PC'),
  transfer('TRANSFER', 'CT');

  final String api;
  final String codePrefix;
  const FinanceVoucherKind(this.api, this.codePrefix);

  static FinanceVoucherKind fromApi(dynamic v) =>
      FinanceVoucherKind.values.firstWhere((k) => k.api == v?.toString(), orElse: () => FinanceVoucherKind.receipt);

  /// Phiếu thu/chi có dòng chi tiết, lý do, đối tượng; chuyển tiền chỉ có hai tài khoản.
  bool get hasLines => this != FinanceVoucherKind.transfer;
}

enum FinanceVoucherStatus {
  draft('DRAFT'),
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  final String api;
  const FinanceVoucherStatus(this.api);

  static FinanceVoucherStatus fromApi(dynamic v) =>
      FinanceVoucherStatus.values.firstWhere((s) => s.api == v?.toString(), orElse: () => FinanceVoucherStatus.draft);
}

enum FinanceAccountType {
  bank('BANK'),
  cash('CASH');

  final String api;
  const FinanceAccountType(this.api);

  static FinanceAccountType fromApi(dynamic v) => v?.toString() == 'CASH' ? FinanceAccountType.cash : FinanceAccountType.bank;
}

/// Cách duyệt: trực tiếp, qua quy trình, hoặc INHERITED (phiếu tạo từ bước Tài chính của hồ sơ quy trình).
enum FinanceApprovalMode {
  direct('DIRECT'),
  procedure('PROCEDURE'),
  inherited('INHERITED');

  final String api;
  const FinanceApprovalMode(this.api);

  static FinanceApprovalMode fromApi(dynamic v) =>
      FinanceApprovalMode.values.firstWhere((m) => m.api == v?.toString(), orElse: () => FinanceApprovalMode.direct);
}

/// Số tiền tối đa một dòng (web `FINANCE_MAX_AMOUNT`).
const double kFinanceMaxAmount = 999999999999999;

/// Số phiếu tối đa mỗi lần duyệt hàng loạt.
const int kFinanceBulkApproveMax = 100;

/// Ngân hàng thường dùng tại Việt Nam (web `FINANCE_BANKS`), cho ô chọn "Ngân hàng".
const List<String> kFinanceBanks = [
  'Vietcombank (VCB)', 'VietinBank (CTG)', 'BIDV', 'Agribank', 'Techcombank (TCB)', 'MB Bank (MBB)', 'ACB',
  'VPBank', 'Sacombank (STB)', 'TPBank', 'HDBank', 'VIB', 'SHB', 'OCB', 'MSB', 'SeABank', 'Eximbank (EIB)',
  'LPBank', 'Nam A Bank', 'Bac A Bank', 'ABBank', 'PVcomBank', 'Kienlongbank', 'Viet Capital Bank', 'NCB',
  'Saigonbank', 'BaoViet Bank', 'VietBank', 'PG Bank', 'Shinhan Bank Việt Nam', 'Woori Bank Việt Nam',
  'HSBC Việt Nam', 'Standard Chartered Việt Nam', 'Ngân hàng khác',
];

/* ------------------------------------ Quyền ------------------------------------ */

class FinanceKindCapability {
  final bool create;
  final bool approve;
  const FinanceKindCapability({this.create = false, this.approve = false});

  factory FinanceKindCapability.fromJson(dynamic json) {
    final m = fMap(json);
    return FinanceKindCapability(create: fBool(m['create']), approve: fBool(m['approve']));
  }
}

/// `GET /capabilities`: quyền Tài chính của người xem.
class FinanceCapabilities {
  final bool canManage;
  final bool canReadAll;
  final FinanceKindCapability receipt;
  final FinanceKindCapability payment;
  final FinanceKindCapability transfer;
  final bool canManageAccounts;
  final bool canReadReports;
  final bool canManageSettings;
  final bool procedureAvailable;

  const FinanceCapabilities({
    this.canManage = false,
    this.canReadAll = false,
    this.receipt = const FinanceKindCapability(),
    this.payment = const FinanceKindCapability(),
    this.transfer = const FinanceKindCapability(),
    this.canManageAccounts = false,
    this.canReadReports = false,
    this.canManageSettings = false,
    this.procedureAvailable = false,
  });

  factory FinanceCapabilities.fromJson(Map<String, dynamic> j) => FinanceCapabilities(
        canManage: fBool(j['canManage']),
        canReadAll: fBool(j['canReadAll']),
        receipt: FinanceKindCapability.fromJson(j['receipt']),
        payment: FinanceKindCapability.fromJson(j['payment']),
        transfer: FinanceKindCapability.fromJson(j['transfer']),
        canManageAccounts: fBool(j['canManageAccounts']),
        canReadReports: fBool(j['canReadReports']),
        canManageSettings: fBool(j['canManageSettings']),
        procedureAvailable: fBool(j['procedureAvailable']),
      );

  FinanceKindCapability of(FinanceVoucherKind kind) => switch (kind) {
        FinanceVoucherKind.receipt => receipt,
        FinanceVoucherKind.payment => payment,
        FinanceVoucherKind.transfer => transfer,
      };

  /// Xem được số dư công ty (cùng điều kiện server `canSeeBalances`).
  bool get canSeeBalances =>
      canReadAll || canManageAccounts || canReadReports || receipt.approve || payment.approve || transfer.approve;

  /// Mở được danh sách phiếu loại này: lập, duyệt hoặc đọc toàn bộ.
  bool canOpenKind(FinanceVoucherKind kind) => of(kind).create || of(kind).approve || canReadAll;
}

/* ---------------------------------- Tài khoản ---------------------------------- */

class FinanceAccount {
  final String id;
  final String code;
  final String name;
  final FinanceAccountType accountType;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String? branch;
  final String currency;
  final double openingBalance;
  final String openingDate;
  final bool allowNegative;
  final bool isActive;
  final String? note;

  /// null khi người xem chỉ có quyền lập phiếu (chọn được tài khoản nhưng không xem số dư).
  final double? balance;
  final double? pendingOut;
  final int? receiptCount;
  final int? paymentCount;
  final int? transferCount;
  final double? totalReceipts;
  final double? totalPayments;
  final String createdAt;
  final String updatedAt;

  const FinanceAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.branch,
    this.currency = 'VND',
    this.openingBalance = 0,
    this.openingDate = '',
    this.allowNegative = false,
    this.isActive = true,
    this.note,
    this.balance,
    this.pendingOut,
    this.receiptCount,
    this.paymentCount,
    this.transferCount,
    this.totalReceipts,
    this.totalPayments,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory FinanceAccount.fromJson(Map<String, dynamic> j) => FinanceAccount(
        id: fStr(j['id']),
        code: fStr(j['code']),
        name: fStr(j['name']),
        accountType: FinanceAccountType.fromApi(j['accountType']),
        bankName: fStrOrNull(j['bankName']),
        accountNumber: fStrOrNull(j['accountNumber']),
        accountHolder: fStrOrNull(j['accountHolder']),
        branch: fStrOrNull(j['branch']),
        currency: fStr(j['currency'], 'VND'),
        openingBalance: fDouble(j['openingBalance']),
        openingDate: fStr(j['openingDate']),
        allowNegative: fBool(j['allowNegative']),
        isActive: fBool(j['isActive'], true),
        note: fStrOrNull(j['note']),
        balance: fDoubleOrNull(j['balance']),
        pendingOut: fDoubleOrNull(j['pendingOut']),
        receiptCount: j['receiptCount'] == null ? null : fInt(j['receiptCount']),
        paymentCount: j['paymentCount'] == null ? null : fInt(j['paymentCount']),
        transferCount: j['transferCount'] == null ? null : fInt(j['transferCount']),
        totalReceipts: fDoubleOrNull(j['totalReceipts']),
        totalPayments: fDoubleOrNull(j['totalPayments']),
        createdAt: fStr(j['createdAt']),
        updatedAt: fStr(j['updatedAt']),
      );

  /// "Mã - Tên" như ô chọn tài khoản của web.
  String get label => code.isEmpty ? name : '$code - $name';
}

/// Một dòng sổ cái của tài khoản (`GET /accounts/:id/ledger`).
class FinanceLedgerEntry {
  final String id;
  final String accountId;
  final String voucherId;
  final String voucherCode;
  final FinanceVoucherKind voucherKind;
  final String postedDate;

  /// Dương: tiền vào; âm: tiền ra.
  final double amount;
  final double balanceAfter;
  final String? description;
  final bool isReversal;
  final String createdAt;

  const FinanceLedgerEntry({
    required this.id,
    required this.accountId,
    required this.voucherId,
    required this.voucherCode,
    required this.voucherKind,
    required this.postedDate,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.isReversal = false,
    this.createdAt = '',
  });

  factory FinanceLedgerEntry.fromJson(Map<String, dynamic> j) => FinanceLedgerEntry(
        id: fStr(j['id']),
        accountId: fStr(j['accountId']),
        voucherId: fStr(j['voucherId']),
        voucherCode: fStr(j['voucherCode']),
        voucherKind: FinanceVoucherKind.fromApi(j['voucherKind']),
        postedDate: fStr(j['postedDate']),
        amount: fDouble(j['amount']),
        balanceAfter: fDouble(j['balanceAfter']),
        description: fStrOrNull(j['description']),
        isReversal: fBool(j['isReversal']),
        createdAt: fStr(j['createdAt']),
      );
}

/* ---------------------------------- Danh mục ---------------------------------- */

class FinanceReason {
  final String id;

  /// Lý do thu (RECEIPT) hoặc lý do chi (PAYMENT).
  final FinanceVoucherKind kind;
  final String code;
  final String name;
  final bool isActive;
  final String? note;

  /// Phiếu dùng lý do này bắt buộc hạch toán cho dự án.
  final bool requireProject;

  const FinanceReason({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    this.isActive = true,
    this.note,
    this.requireProject = false,
  });

  factory FinanceReason.fromJson(Map<String, dynamic> j) => FinanceReason(
        id: fStr(j['id']),
        kind: FinanceVoucherKind.fromApi(j['kind']),
        code: fStr(j['code']),
        name: fStr(j['name']),
        isActive: fBool(j['isActive'], true),
        note: fStrOrNull(j['note']),
        requireProject: fBool(j['requireProject']),
      );
}

/// Nhóm đối tượng thu/chi (khách hàng, nhà cung cấp, nhân viên...).
class FinanceCounterpartyGroup {
  final String id;
  final String code;
  final String name;
  final bool isActive;

  const FinanceCounterpartyGroup({required this.id, required this.code, required this.name, this.isActive = true});

  factory FinanceCounterpartyGroup.fromJson(Map<String, dynamic> j) => FinanceCounterpartyGroup(
        id: fStr(j['id']),
        code: fStr(j['code']),
        name: fStr(j['name']),
        isActive: fBool(j['isActive'], true),
      );
}

class FinanceCatalogs {
  final List<FinanceReason> reasons;
  final List<FinanceCounterpartyGroup> counterpartyGroups;

  const FinanceCatalogs({this.reasons = const [], this.counterpartyGroups = const []});

  factory FinanceCatalogs.fromJson(Map<String, dynamic> j) => FinanceCatalogs(
        reasons: fList(j['reasons']).map(FinanceReason.fromJson).toList(),
        counterpartyGroups: fList(j['counterpartyGroups']).map(FinanceCounterpartyGroup.fromJson).toList(),
      );

  List<FinanceReason> reasonsOf(FinanceVoucherKind kind) => reasons.where((r) => r.kind == kind).toList();
}

/* ------------------------------ Cài đặt & duyệt ------------------------------ */

class FinanceSettings {
  /// Không ghi sổ/đảo phiếu có ngày hạch toán trước hoặc bằng ngày này (`YYYY-MM-DD`).
  final String? booksLockedUntil;
  final bool allowSelfApproval;

  /// Bắt buộc hạch toán dự án cho phiếu thu/chi.
  final bool requireAllocation;

  const FinanceSettings({this.booksLockedUntil, this.allowSelfApproval = false, this.requireAllocation = false});

  factory FinanceSettings.fromJson(Map<String, dynamic> j) => FinanceSettings(
        booksLockedUntil: fStrOrNull(j['booksLockedUntil']),
        allowSelfApproval: fBool(j['allowSelfApproval']),
        requireAllocation: fBool(j['requireAllocation']),
      );
}

class FinanceApprovalBinding {
  final FinanceVoucherKind kind;

  /// DIRECT hoặc PROCEDURE.
  final FinanceApprovalMode mode;
  final String? procedureDefinitionId;
  final String? procedureDefinitionName;
  final bool isActive;

  const FinanceApprovalBinding({
    required this.kind,
    required this.mode,
    this.procedureDefinitionId,
    this.procedureDefinitionName,
    this.isActive = true,
  });

  factory FinanceApprovalBinding.fromJson(Map<String, dynamic> j) => FinanceApprovalBinding(
        kind: FinanceVoucherKind.fromApi(j['kind']),
        mode: FinanceApprovalMode.fromApi(j['mode']),
        procedureDefinitionId: fStrOrNull(j['procedureDefinitionId']),
        procedureDefinitionName: fStrOrNull(j['procedureDefinitionName']),
        isActive: fBool(j['isActive'], true),
      );
}

class FinanceProcedureDefinitionOption {
  final String id;
  final String code;
  final String name;
  const FinanceProcedureDefinitionOption({required this.id, required this.code, required this.name});

  factory FinanceProcedureDefinitionOption.fromJson(Map<String, dynamic> j) =>
      FinanceProcedureDefinitionOption(id: fStr(j['id']), code: fStr(j['code']), name: fStr(j['name']));
}

/// Kết quả lưu cách duyệt: kèm cảnh báo cấu hình (không chặn lưu).
class FinanceSaveBindingResult {
  final FinanceApprovalBinding binding;
  final List<String> warnings;
  const FinanceSaveBindingResult({required this.binding, this.warnings = const []});
}

/// Dự án Workspace để chọn hạch toán/dự án liên quan (`GET /workspace/projects`).
class FinanceWorkspaceProject {
  final String id;
  final String code;
  final String name;

  /// Trạng thái dự án Workspace (planning | active | on_hold | completed | cancelled); rỗng: không rõ.
  final String status;
  const FinanceWorkspaceProject({required this.id, required this.code, required this.name, this.status = ''});

  factory FinanceWorkspaceProject.fromJson(Map<String, dynamic> j) => FinanceWorkspaceProject(
      id: fStr(j['id']), code: fStr(j['code']), name: fStr(j['name']), status: fStr(j['status']));

  String get label => code.isEmpty ? name : '$code - $name';
}

/// Kết quả `GET /workspace/projects` (web `loadWorkspaceProjects`): danh sách + cờ bị cắt bớt.
class FinanceWorkspaceProjectList {
  final List<FinanceWorkspaceProject> items;
  final bool truncated;
  const FinanceWorkspaceProjectList({required this.items, this.truncated = false});
}
