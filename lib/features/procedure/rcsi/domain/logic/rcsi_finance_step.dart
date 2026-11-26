/// Bước Tài chính — hằng số contract (`procedure-finance-step.ts`) và logic
/// màn thiết kế (`components/rcsi/finance-step.ts`), port 1:1.
library;

import '../rcsi_definition_models.dart';
import '../rcsi_flow_models.dart';
import '../rcsi_json.dart';
import 'procedure_flow.dart';
import 'rcsi_labels.dart';
import 'vietnamese_text.dart';

/// `PROCEDURE_FINANCE_VOUCHER_KINDS`.
const List<String> procedureFinanceVoucherKinds = ['PAYMENT', 'RECEIPT'];

/// Khoá i18n `PROCEDURE_FINANCE_VOUCHER_KIND_LABELS` (Phiếu chi / Phiếu thu).
String financeVoucherKindLabelKey(String kind) => 'procedure.rcsi.voucher_kind.$kind';

/// `FINANCE_VOUCHER_SOURCE_FIELDS`.
const List<String> financeVoucherSourceFields = [
  'amount',
  'content',
  'counterpartyName',
  'counterpartyAccountNo',
  'counterpartyBank',
  'voucherDate',
];

/// Khoá i18n `FINANCE_VOUCHER_SOURCE_FIELD_LABELS`.
String financeVoucherSourceFieldLabelKey(String field) => 'procedure.rcsi.voucher_field.$field';

/// `FINANCE_VOUCHER_SOURCE_ATTRIBUTE_CODES` — mã tự khớp theo thứ tự ưu tiên.
const Map<String, List<String>> financeVoucherSourceAttributeCodes = {
  'amount': ['so_tien', 'amount', 'tong_tien'],
  'content': ['noi_dung', 'content'],
  'counterpartyName': ['nguoi_nop_nhan', 'counterparty'],
  'counterpartyAccountNo': ['so_tai_khoan', 'account_no'],
  'counterpartyBank': ['ngan_hang', 'bank'],
  'voucherDate': ['ngay_lap', 'voucher_date'],
};

/// `FINANCE_VOUCHER_SOURCE_FIELD_TYPES` — kiểu thuộc tính chấp nhận cho từng trường.
const Map<String, List<String>> financeVoucherSourceFieldTypes = {
  'amount': ['money', 'number'],
  'content': ['text', 'select'],
  'counterpartyName': ['text', 'user', 'select'],
  'counterpartyAccountNo': ['text'],
  'counterpartyBank': ['text', 'select'],
  'voucherDate': ['date'],
};

/// Thuộc tính mà bước Tài chính đọc được.
class FinanceAttributeCandidate {
  /// `process:<code>` hoặc `step:<stepId>:<code>`.
  final String key;
  final ProcedureAttributeDefinition attribute;

  /// "Cấp quy trình" hoặc "Bước “tên”".
  final String scopeLabel;

  const FinanceAttributeCandidate({required this.key, required this.attribute, required this.scopeLabel});
}

Set<String> _stepsBefore(ProcedureDefinition definition, String stepId) {
  final before = dominatorStepIds(flowIndexOf(definition), stepId);
  before.remove(stepId);
  return before;
}

/// Thuộc tính của quy trình, hoặc của bước CHẮC CHẮN đã đi qua trước bước Tài chính.
List<FinanceAttributeCandidate> financeAttributeCandidates(
  ProcedureDefinition definition,
  String stepId, [
  RcsiLabels labels = defaultRcsiLabels,
]) {
  final before = _stepsBefore(definition, stepId);
  final candidates = [
    for (final attribute in definition.attributes ?? const <ProcedureAttributeDefinition>[])
      FinanceAttributeCandidate(key: 'process:${attribute.code}', attribute: attribute, scopeLabel: labels.processScope),
  ];
  for (final step in definition.orderedSteps) {
    if (!before.contains(step.id)) continue;
    for (final attribute in step.attributes ?? const <ProcedureAttributeDefinition>[]) {
      candidates.add(FinanceAttributeCandidate(
        key: 'step:${step.id}:${attribute.code}',
        attribute: attribute,
        scopeLabel: RcsiLabels.fill(labels.stepScope, {'name': step.name}),
      ));
    }
  }
  return candidates;
}

/// Thuộc tính tự khớp khi trường không khai ánh xạ, theo thứ tự ưu tiên của server.
FinanceAttributeCandidate? autoMatchedCandidate(String field, List<FinanceAttributeCandidate> candidates) {
  final types = financeVoucherSourceFieldTypes[field] ?? const <String>[];
  for (final code in financeVoucherSourceAttributeCodes[field] ?? const <String>[]) {
    for (final candidate in candidates) {
      if (candidate.attribute.code.toLowerCase() == code && types.contains(candidate.attribute.type)) {
        return candidate;
      }
    }
  }
  return null;
}

/// Thuộc tính đúng kiểu cho một trường phiếu.
List<FinanceAttributeCandidate> candidatesForField(String field, List<FinanceAttributeCandidate> candidates) {
  final types = financeVoucherSourceFieldTypes[field] ?? const <String>[];
  return candidates.where((candidate) => types.contains(candidate.attribute.type)).toList();
}

/// Bước có thể nhận hồ sơ khi kế toán trả về: các bước chắc chắn đã qua trước bước Tài chính.
List<ProcedureStepDefinition> financeReturnTargets(ProcedureDefinition definition, String stepId) {
  final before = _stepsBefore(definition, stepId);
  return definition.orderedSteps.where((step) => before.contains(step.id)).toList();
}

/// Bỏ ánh xạ trống để không gửi `mapping: {}` hay khoá rỗng.
ProcedureStepIntegration cleanIntegration(ProcedureStepIntegration integration) {
  final mapping = <String, String>{
    for (final entry in (integration.mapping ?? const <String, String>{}).entries)
      if (entry.value.trim().isNotEmpty) entry.key: entry.value,
  };
  return ProcedureStepIntegration(
    voucherKind: integration.voucherKind,
    mapping: mapping.isEmpty ? null : mapping,
    returnToStepId: (integration.returnToStepId?.isNotEmpty ?? false) ? integration.returnToStepId : null,
  );
}

// ------------------------------------------------------------------ Thẻ phiếu trên hồ sơ

/// Tiến trình phiếu ở một bước Tài chính đang chạy (`ProcedureStepFinanceVoucher`).
class ProcedureStepFinanceVoucher {
  final int activation;

  /// `requested` | `linked` | `posted` | `returned`.
  final String state;
  final String requestedAt;
  final String? voucherId;
  final String? code;
  final num? amount;
  final String? postedAt;
  final String? postedBy;
  final String? postedByName;
  final String? returnedReason;
  final String? updatedAt;

  const ProcedureStepFinanceVoucher({
    required this.activation,
    required this.state,
    required this.requestedAt,
    this.voucherId,
    this.code,
    this.amount,
    this.postedAt,
    this.postedBy,
    this.postedByName,
    this.returnedReason,
    this.updatedAt,
  });

  factory ProcedureStepFinanceVoucher.fromJson(Map<String, dynamic> json) => ProcedureStepFinanceVoucher(
        activation: jsonInt(json['activation'], 1),
        state: jsonStr(json['state'], 'requested'),
        requestedAt: jsonStr(json['requestedAt']),
        voucherId: jsonStrOrNull(json['voucherId']),
        code: jsonStrOrNull(json['code']),
        amount: jsonNumOrNull(json['amount']),
        postedAt: jsonStrOrNull(json['postedAt']),
        postedBy: jsonStrOrNull(json['postedBy']),
        postedByName: jsonStrOrNull(json['postedByName']),
        returnedReason: jsonStrOrNull(json['returnedReason']),
        updatedAt: jsonStrOrNull(json['updatedAt']),
      );
}

/// `waiting` | `info` | `success` | `warning`.
typedef FinanceVoucherCard = ({String title, String? detail, String tone});

String? _money(num? value) => value == null ? null : '${formatViNumber(value)} đ';

String _joinPresent(List<String?> parts) =>
    parts.where((part) => part != null && part.isNotEmpty).join(' · ');

/// Nội dung thẻ phiếu theo tiến trình phiếu.
FinanceVoucherCard financeVoucherCard(ProcedureStepFinanceVoucher voucher, [RcsiLabels labels = defaultRcsiLabels]) {
  switch (voucher.state) {
    case 'linked':
      return (
        title: _joinPresent([voucher.code, labels.voucherWaitingPost, _money(voucher.amount)]),
        detail: null,
        tone: 'info',
      );
    case 'posted':
      return (
        title: _joinPresent([
          voucher.code,
          (voucher.postedByName?.isNotEmpty ?? false)
              ? RcsiLabels.fill(labels.voucherPostedBy, {'name': voucher.postedByName})
              : labels.voucherPosted,
          _money(voucher.amount),
        ]),
        detail: null,
        tone: 'success',
      );
    case 'returned':
      return (
        title: labels.voucherReturned,
        detail: (voucher.returnedReason?.isNotEmpty ?? false)
            ? RcsiLabels.fill(labels.voucherReturnedReason, {'reason': voucher.returnedReason})
            : null,
        tone: 'warning',
      );
    default:
      // Hồ sơ quay lại bước sau khi bị trả: phiếu nháp cũ được cập nhật, không tạo phiếu mới.
      return (voucher.code?.isNotEmpty ?? false)
          ? (title: RcsiLabels.fill(labels.voucherWaitingUpdate, {'code': voucher.code}), detail: null, tone: 'waiting')
          : (title: labels.voucherWaitingCreate, detail: null, tone: 'waiting');
  }
}

/// Đường dẫn mở phiếu ở app Tài chính (web).
String financeVoucherHref(String kind, String voucherId) =>
    '/modules/finance/${kind == 'RECEIPT' ? 'receipts' : 'payments'}/${Uri.encodeComponent(voucherId)}';
