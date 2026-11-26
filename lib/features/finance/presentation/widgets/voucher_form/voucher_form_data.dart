import 'package:file_picker/file_picker.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';

/// Trạng thái form phiếu (web `voucher-form-screen.tsx` FormState), dựng body `SaveFinanceVoucherRequest`.

int _keySeed = 0;
int _nextKey() => _keySeed += 1;

class VoucherLineState {
  final int key;
  String description;
  double quantity;
  double unitAmount;

  VoucherLineState({this.description = '', this.quantity = 1, this.unitAmount = 0}) : key = _nextKey();

  double get total => financeLineTotal(quantity, unitAmount);

  FinanceVoucherLine toLine() =>
      FinanceVoucherLine(description: description, quantity: quantity, unitAmount: unitAmount, total: total);
}

class VoucherInvoiceState {
  final int key;
  String invoiceNo;
  String invoiceDate;
  String taxCode;
  double amount;

  VoucherInvoiceState({this.invoiceNo = '', this.invoiceDate = '', this.taxCode = '', this.amount = 0}) : key = _nextKey();
}

/// Dự án để chọn (Workspace hoặc nhãn đã lưu trên phiếu).
class VoucherProjectOption {
  final String id;
  final String code;
  final String name;

  /// Trạng thái Workspace; dự án đã lưu trên phiếu không có (web `status: ''`).
  final String status;
  const VoucherProjectOption({required this.id, required this.code, required this.name, this.status = ''});

  /// web `projectLabel`: "Mã - Tên".
  String get label => '$code - $name';
}

class VoucherFormData {
  String voucherDate;
  String postingDate;
  String content = '';
  String reasonId = '';
  String accountId = '';
  String destAccountId = '';
  String counterpartyGroupId = '';
  String counterpartyName = '';
  String counterpartyAccountNo = '';
  String counterpartyBank = '';

  /// Hạch toán nội bộ chỉ ở cấp dự án; rỗng: không hạch toán.
  String allocProjectId = '';
  bool taxIncluded = false;
  double taxRate = 0;

  /// Ghi chú HTML (ô soạn thảo như web). [originalNoteHtml]: HTML gốc trên phiếu; [noteHtml] null = chưa sửa,
  /// khi đó gửi lại nguyên HTML gốc (không để bộ soạn thảo chuẩn hoá lại làm đổi nội dung).
  String? noteHtml;
  String? originalNoteHtml;
  double amount = 0;
  List<VoucherLineState> lines = [VoucherLineState()];
  List<VoucherInvoiceState> invoices = [];
  List<String> relatedProjectIds = [];

  VoucherFormData._(this.voucherDate, this.postingDate);

  factory VoucherFormData.empty() {
    final today = financeApiDate(DateTime.now());
    return VoucherFormData._(today, today);
  }

  factory VoucherFormData.fromVoucher(FinanceVoucher v) {
    final f = VoucherFormData._(v.voucherDate, v.postingDate)
      ..content = v.content
      ..reasonId = v.reasonId ?? ''
      ..accountId = v.accountId ?? ''
      ..destAccountId = v.destAccountId ?? ''
      ..counterpartyGroupId = v.counterpartyGroupId ?? ''
      ..counterpartyName = v.counterpartyName ?? ''
      ..counterpartyAccountNo = v.counterpartyAccountNo ?? ''
      ..counterpartyBank = v.counterpartyBank ?? ''
      ..allocProjectId = v.allocation?.projectId ?? ''
      ..taxIncluded = v.taxIncluded
      ..taxRate = v.taxRate
      ..originalNoteHtml = v.note
      ..amount = v.kind == FinanceVoucherKind.transfer ? v.totalAmount : 0
      ..lines = v.lines.isEmpty
          ? [VoucherLineState()]
          : v.lines
              .map((l) => VoucherLineState(description: l.description, quantity: l.quantity, unitAmount: l.unitAmount))
              .toList()
      ..invoices = v.invoices
          .map((i) => VoucherInvoiceState(
                invoiceNo: i.invoiceNo,
                invoiceDate: i.invoiceDate ?? '',
                taxCode: i.taxCode ?? '',
                amount: i.amount,
              ))
          .toList()
      ..relatedProjectIds = v.relatedProjects.map((p) => p.projectId).toList();
    return f;
  }

  /// Nhân bản: dữ liệu phiếu nguồn, đặt lại ngày về hôm nay (tệp đính kèm không copy).
  factory VoucherFormData.copyOf(FinanceVoucher v) {
    final today = financeApiDate(DateTime.now());
    return VoucherFormData.fromVoucher(v)
      ..voucherDate = today
      ..postingDate = today;
  }

  double linesTotal() => financeLinesTotal(lines.map((l) => l.toLine()));

  /// Ghi chú gửi lên: không sửa thì giữ HTML gốc (không làm mất định dạng/ảnh của web).
  String? get _noteHtml {
    final html = noteHtml ?? originalNoteHtml ?? '';
    return html.trim().isEmpty ? null : html;
  }

  /// web `buildRequest`: server tính lại thành tiền và tổng.
  Map<String, dynamic> toRequest(FinanceVoucherKind kind, int? revision) {
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    final base = <String, dynamic>{
      'kind': kind.api,
      'voucherDate': voucherDate,
      'postingDate': postingDate,
      'content': content,
      'accountId': accountId.isEmpty ? null : accountId,
      'note': _noteHtml,
      'relatedProjectIds': relatedProjectIds,
      'revision': ?revision,
    };
    if (kind == FinanceVoucherKind.transfer) {
      return {...base, 'destAccountId': destAccountId.isEmpty ? null : destAccountId, 'amount': amount};
    }
    return {
      ...base,
      'reasonId': reasonId.isEmpty ? null : reasonId,
      'counterpartyGroupId': counterpartyGroupId.isEmpty ? null : counterpartyGroupId,
      'counterpartyName': orNull(counterpartyName),
      'counterpartyAccountNo': orNull(counterpartyAccountNo),
      'counterpartyBank': orNull(counterpartyBank),
      'allocation': allocProjectId.isEmpty ? null : {'type': 'PROJECT', 'projectId': allocProjectId},
      'taxIncluded': taxIncluded,
      'taxRate': taxIncluded ? taxRate : 0,
      'lines': lines.map((l) => l.toLine().toJson()).toList(),
      'invoices': invoices
          .where((i) => i.invoiceNo.trim().isNotEmpty)
          .map((i) => {
                'invoiceNo': i.invoiceNo,
                'invoiceDate': i.invoiceDate.isEmpty ? null : i.invoiceDate,
                'taxCode': i.taxCode.isEmpty ? null : i.taxCode,
                'amount': i.amount,
              })
          .toList(),
    };
  }
}

/* ------------------------------ Đính kèm (web attachment-upload.ts) ------------------------------ */

const int kVoucherMaxAttachmentBytes = 10 * 1024 * 1024;
const int kVoucherMaxAttachments = 20;

/// Đuôi tệp được nhận và loại nội dung; khớp máy chủ (attachments.store.ts).
const Map<String, String> kVoucherAttachmentContentTypes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'jfif': 'image/jpeg',
  'webp': 'image/webp',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String voucherFileExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Tệp đang chờ tải lên khi bấm lưu.
class VoucherPendingFile {
  final PlatformFile file;
  final int size;
  const VoucherPendingFile(this.file, this.size);
  String get name => file.name;
}

/// Lý do tệp không đính kèm được (null nếu hợp lệ).
String? voucherAttachmentProblem(String name, int size) {
  if (!kVoucherAttachmentContentTypes.containsKey(voucherFileExtension(name))) {
    return 'finance.voucher_form.attach_bad_type'.tr(args: {'name': name});
  }
  if (size <= 0) return 'finance.voucher_form.attach_empty'.tr(args: {'name': name});
  if (size > kVoucherMaxAttachmentBytes) return 'finance.voucher_form.attach_too_big'.tr(args: {'name': name});
  return null;
}

/// web `formatBytes`.
String formatVoucherBytes(int bytes) {
  String dec(double v) => v.toString().replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${dec((bytes / 102.4).round() / 10)} KB';
  return '${dec((bytes / 104857.6).round() / 10)} MB';
}
