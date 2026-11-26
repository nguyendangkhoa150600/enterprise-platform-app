import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/finance_models.dart';
import 'finance_format.dart';
import 'finance_labels.dart';

/// Xuất CSV như web `finance-csv.ts` (nút "Xuất Excel"): UTF-8 có BOM để Excel đọc đúng tiếng Việt,
/// escape dấu nháy/dấu phẩy, vô hiệu hoá công thức khi ô bắt đầu bằng = + - @.
/// Mobile: lưu vào thư mục máy rồi mở hộp chia sẻ/lưu tệp của hệ thống (cùng cách sổ đăng ký công văn).
class FinanceCsvExporter {
  FinanceCsvExporter._();

  static String csvCell(Object? value) {
    // Như JS `String(n)`: số nguyên không kèm ".0" (1500000, không phải 1500000.0).
    if (value is double && value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21) {
      return value.toStringAsFixed(0);
    }
    if (value is num || value is bool) return value.toString();
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  static String buildCsv(List<List<Object?>> rows) =>
      '﻿${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}';

  static String safeFileName(String name, [String fallback = 'xuat-du-lieu']) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// Ghi tệp `<fileName>.csv` và mở hộp chia sẻ. Lỗi ghi/chia sẻ ném ra để màn hình báo.
  static Future<void> share(String fileName, List<List<Object?>> rows) async {
    final name = '${safeFileName(fileName)}.csv';
    final bytes = Uint8List.fromList(utf8.encode(buildCsv(rows)));
    const mime = 'text/csv';
    XFile file;
    try {
      final dir = await _saveDirectory();
      final saved = await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
      file = XFile(saved.path, mimeType: mime, name: name);
    } catch (e) {
      debugPrint('[FinanceCsvExporter] write error: $e');
      file = XFile.fromData(bytes, mimeType: mime, name: name);
    }
    await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name]));
  }

  static Future<Directory> _saveDirectory() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) return publicDownload;
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Web `dateVn`: phần `YYYY-MM-DD` đầu chuỗi → `dd/MM/yyyy`, rỗng thì để trống.
  static String _date(String? v) => financeDateVn(v);

  /* ------------------------------ Các bảng web xuất ------------------------------ */

  /// Danh sách phiếu (web `voucherCsvRows`). Tên tệp: `<singular>-dd-MM-yyyy`.
  static Future<void> exportVouchers(FinanceVoucherKind kind, List<FinanceVoucherSummary> items) {
    // Web: `dateVn(new Date().toISOString().slice(0, 10))` — ngày theo UTC, dạng dd-MM-yyyy.
    final stamp = financeDateVn(financeApiDate(DateTime.now().toUtc())).replaceAll('/', '-');
    return share('${kind.label('singular').replaceAll(RegExp(r'\s+'), '-')}-$stamp', [
      [
        for (final k in const [
          'code', 'kind', 'date', 'posting_date', 'content', 'reason', 'account', 'dest_account',
          'counterparty', 'person', 'amount', 'status', 'creator',
        ])
          'finance.export.voucher_$k'.tr(),
      ],
      for (final v in items)
        [
          v.code,
          v.kind.name,
          _date(v.voucherDate),
          _date(v.postingDate),
          v.content,
          v.reasonName ?? '',
          v.accountName ?? '',
          v.destAccountName ?? '',
          v.counterpartyGroupName ?? '',
          v.counterpartyName ?? '',
          v.totalAmount,
          v.status.label,
          v.createdByName ?? '',
        ],
    ]);
  }

  /// Danh sách tài khoản (web `accounts-screen` exportCsv). Tên tệp: `tai-khoan-YYYY-MM-DD`.
  static Future<void> exportAccounts(List<FinanceAccount> accounts) {
    return share('tai-khoan-${financeTodayVn()}', [
      [
        for (final k in const [
          'name', 'type', 'number', 'bank', 'status', 'receipts', 'payments', 'transfers', 'opening',
          'total_receipts', 'total_payments', 'balance',
        ])
          'finance.export.account_$k'.tr(),
      ],
      for (final a in accounts)
        [
          a.name,
          a.accountType.label,
          a.accountNumber ?? '',
          a.bankName ?? '',
          (a.isActive ? 'finance.export.active' : 'finance.export.inactive').tr(),
          a.receiptCount ?? '',
          a.paymentCount ?? '',
          a.transferCount ?? '',
          a.openingBalance,
          a.totalReceipts ?? '',
          a.totalPayments ?? '',
          a.balance ?? '',
        ],
    ]);
  }

  /// Báo cáo phân tích (web `reports-screen` exportCsv). Tên tệp: `bao-cao-thu-chi-<from>-<to>`.
  static Future<void> exportReport(FinanceReport r) {
    List<List<Object?>> section(String titleKey, List<FinanceBreakdownRow> rows) => [
          [titleKey.tr()],
          ['finance.export.col_item'.tr(), 'finance.export.col_count'.tr(), 'finance.export.col_amount'.tr()],
          for (final x in rows) [x.name, x.count, x.amount],
          [],
        ];
    return share('bao-cao-thu-chi-${r.from}-${r.to}', [
      ['finance.export.report_title'.tr(), '${_date(r.from)} - ${_date(r.to)}'],
      ['finance.export.total_receipts'.tr(), r.totals.receipts],
      ['finance.export.total_payments'.tr(), r.totals.payments],
      ['finance.export.net'.tr(), r.totals.net],
      [],
      ['finance.export.cashflow'.tr()],
      [
        'finance.export.col_period'.tr(),
        'finance.export.col_receipt'.tr(),
        'finance.export.col_payment'.tr(),
        'finance.export.net'.tr(),
      ],
      for (final p in r.cashflow) [p.period, p.receipts, p.payments, p.net],
      [],
      ...section('finance.export.receipts_by_reason', r.receiptsByReason),
      ...section('finance.export.payments_by_reason', r.paymentsByReason),
      ...section('finance.export.receipts_by_project', r.receiptsByProject),
      ...section('finance.export.payments_by_project', r.paymentsByProject),
      ['finance.export.account_movement'.tr()],
      [
        for (final k in const ['account', 'opening', 'receipts', 'payments', 'transfers_in', 'transfers_out', 'closing'])
          'finance.export.move_$k'.tr(),
      ],
      for (final a in r.accounts)
        [a.accountName, a.openingBalance, a.receipts, a.payments, a.transfersIn, a.transfersOut, a.closingBalance],
    ]);
  }

  /// Sổ thu chi (web `reports-ledger` exportCsv) — [rows] phải là TOÀN BỘ dòng của kỳ.
  static Future<void> exportLedger(FinanceLedgerReport report, List<FinanceLedgerReportRow> rows) {
    return share('bao-cao-thu-chi-${report.from}-${report.to}', [
      ['finance.export.ledger_title'.tr(args: {'from': _date(report.from), 'to': _date(report.to)})],
      [
        for (final k in const [
          'no', 'content', 'code', 'creator', 'created_at', 'posted_date', 'account', 'receipt', 'payment', 'balance',
        ])
          'finance.export.ledger_$k'.tr(),
      ],
      ['', 'finance.export.opening_balance'.tr(), '', '', '', '', '', '', '', report.openingBalance],
      for (var i = 0; i < rows.length; i++)
        [
          i + 1,
          rows[i].content,
          rows[i].voucherCode,
          rows[i].createdByName ?? '',
          _date(rows[i].createdAt),
          _date(rows[i].postedDate),
          rows[i].accountName,
          rows[i].receipt,
          rows[i].payment,
          rows[i].balanceAfter,
        ],
      [
        '', 'finance.export.period_total'.tr(), '', '', '', '', '',
        report.totalReceipts, report.totalPayments, report.closingBalance,
      ],
    ]);
  }
}
