import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/reports/inventory_report_models.dart';

/// Nhãn, định dạng và danh sách lựa chọn của màn Báo cáo kho (web `inventory-reports.model.ts`,
/// `inventory-labels.ts`, `stock-document.model.ts`). Bảng trên màn và tệp CSV dùng cùng nhãn.
class ReportLabels {
  ReportLabels._();

  static const qualityStatuses = ['PASSED', 'QUARANTINE', 'DEFECTIVE', 'PENDING_INSPECTION'];
  static const serialStates = ['IN_STOCK', 'ISSUED', 'IN_TRANSIT', 'SCRAPPED'];
  static const docTypes = [
    'RECEIPT_PURCHASE',
    'RECEIPT_SALES_RETURN',
    'RECEIPT_TRANSFER',
    'RECEIPT_OTHER',
    'ISSUE_SALES',
    'ISSUE_PROJECT',
    'ISSUE_WARRANTY',
    'ISSUE_TRANSFER',
    'ISSUE_OTHER',
    'ADJUSTMENT',
    'TRANSFER',
  ];

  /// Loại chứng từ phải qua người duyệt (web `APPROVAL_DOC_TYPES`).
  static const approvalDocTypes = ['ADJUSTMENT', 'RECEIPT_OTHER', 'ISSUE_OTHER', 'RECEIPT_PURCHASE', 'ISSUE_PROJECT'];
  static const docStatuses = ['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'POSTED', 'CANCELLED'];
  static const expiryDays = ['0', '30', '60', '90', '180'];

  static String _enum(String prefix, String? value) {
    if (value == null || value.isEmpty) return '';
    final key = 'inventory.reports.$prefix.$value';
    final text = key.tr();
    return text == key ? value : text;
  }

  static String quality(String? v) => _enum('quality', v);
  static String serialState(String? v) => _enum('serial_state', v);
  static String movementCategory(String? v) => _enum('category', v);
  static String docType(String? v) => _enum('doc_type', v);
  static String docStatus(String? v) => _enum('doc_status', v);

  static String get onHand => 'inventory.reports.qty.on_hand'.tr();
  static String get reserved => 'inventory.reports.qty.reserved'.tr();
  static String get blocked => 'inventory.reports.qty.blocked'.tr();
  static String get available => 'inventory.reports.qty.available'.tr();

  static String groupLabel(StockReportGroupBy g) => switch (g) {
    StockReportGroupBy.warehouse => 'inventory.reports.view.warehouse'.tr(),
    StockReportGroupBy.lot => 'inventory.reports.view.lot'.tr(),
    StockReportGroupBy.serial => 'inventory.reports.view.serial'.tr(),
  };

  /// Màu nhãn trạng thái chứng từ (web `STOCK_DOCUMENT_STATUS_BADGE`): nền, chữ, viền.
  static (Color, Color, Color) statusColors(String status) => switch (status) {
    'DRAFT' => (const Color(0xFFF5F3FF), const Color(0xFF6D28D9), const Color(0xFFDDD6FE)),
    'PENDING' => (const Color(0xFFFFFBEB), const Color(0xFFB45309), const Color(0xFFFDE68A)),
    'APPROVED' => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), const Color(0xFFBFDBFE)),
    'REJECTED' => (const Color(0xFFFEF2F2), const Color(0xFFB91C1C), const Color(0xFFFECACA)),
    'POSTED' => (const Color(0xFFF0FDF4), const Color(0xFF15803D), const Color(0xFFBBF7D0)),
    _ => (const Color(0xFFF8FAFC), const Color(0xFF64748B), const Color(0xFFE2E8F0)),
  };

  /// Màu nhãn chất lượng (web `QUALITY_STATUS_BADGE`).
  static (Color, Color, Color) qualityColors(String status) => switch (status) {
    'PASSED' => (const Color(0xFFF0FDF4), const Color(0xFF15803D), const Color(0xFFBBF7D0)),
    'QUARANTINE' => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), const Color(0xFFBFDBFE)),
    'DEFECTIVE' => (const Color(0xFFFEF2F2), const Color(0xFFB91C1C), const Color(0xFFFECACA)),
    _ => (const Color(0xFFFFFBEB), const Color(0xFFB45309), const Color(0xFFFDE68A)),
  };
}

/// Định dạng số/ngày như web (`formatQuantityVn`, `formatDate`, `formatDateTime`).
class ReportFormat {
  ReportFormat._();

  static final NumberFormat _number = NumberFormat('#,##0.###', 'vi_VN');

  static String number(num value) => _number.format(value);

  /// `YYYY-MM-DD` (hoặc ISO) → `dd/MM/yyyy`.
  static String date(String? value) {
    if (value == null || value.isEmpty) return '—';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (m == null) return value;
    if (value.length > 10) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
    }
    return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
  }

  static String dateTime(String? value) {
    if (value == null || value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  /// Hôm nay theo giờ Việt Nam (YYYY-MM-DD), cùng cách server tính kỳ báo cáo.
  static String todayInVietnam([DateTime? now]) {
    final vn = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    return DateFormat('yyyy-MM-dd').format(vn);
  }
}
