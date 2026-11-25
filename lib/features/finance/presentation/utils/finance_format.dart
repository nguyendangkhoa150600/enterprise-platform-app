import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/errors/finance_exception.dart';

/// Định dạng tiền như web `formatFinanceMoney` (vi-VN, tối đa 2 chữ số lẻ, không ký hiệu).
String formatFinanceMoney(num value) {
  final locale = AppI18n.instance.locale.languageCode == 'en' ? 'en_US' : 'vi_VN';
  return NumberFormat('#,##0.##', locale).format(value);
}

/// Tiền kèm đơn vị "đ" (thẻ số liệu).
String formatFinanceMoneyVnd(num value) => '${formatFinanceMoney(value)} đ';

/// Tiền rút gọn cho trục biểu đồ: 1,2 tỷ / 350 tr / 12 k.
String formatFinanceMoneyShort(num value) {
  final abs = value.abs();
  String fmt(double v, String unit) => '${NumberFormat('#,##0.#', 'vi_VN').format(v)} $unit';
  if (abs >= 1e9) return fmt(value / 1e9, 'tỷ');
  if (abs >= 1e6) return fmt(value / 1e6, 'tr');
  if (abs >= 1e3) return fmt(value / 1e3, 'k');
  return formatFinanceMoney(value);
}

/// `YYYY-MM-DD` hoặc ISO → `dd/MM/yyyy`. Rỗng → '—'.
String formatFinanceDate(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final d = DateTime.tryParse(value.trim());
  if (d == null) return value;
  final local = value.length > 10 ? d.toLocal() : d;
  return DateFormat('dd/MM/yyyy').format(local);
}

/// ISO thời điểm → `dd/MM/yyyy HH:mm` theo giờ Việt Nam (web `dateTimeVn`).
String formatFinanceDateTime(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final d = DateTime.tryParse(value.trim());
  if (d == null) return value;
  return DateFormat('dd/MM/yyyy HH:mm').format(d.toUtc().add(const Duration(hours: 7)));
}

/// Web `dateVn`: lấy phần `YYYY-MM-DD` đầu chuỗi → `dd/MM/yyyy` (không đổi múi giờ); rỗng → ''.
String financeDateVn(String? value) {
  if (value == null || value.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  return m == null ? value : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// Web `todayVn`: hôm nay theo giờ Việt Nam, `YYYY-MM-DD`.
String financeTodayVn() => financeApiDate(DateTime.now().toUtc().add(const Duration(hours: 7)));

/// DateTime → `YYYY-MM-DD` (định dạng ngày của API).
String financeApiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime? parseFinanceDate(String? value) =>
    (value == null || value.isEmpty) ? null : DateTime.tryParse(value);

/// Kỳ một tháng: ngày đầu và ngày cuối.
({DateTime from, DateTime to}) financeMonthRange(DateTime month) =>
    (from: DateTime(month.year, month.month, 1), to: DateTime(month.year, month.month + 1, 0));

/// "Tháng 11/2026".
String formatFinanceMonth(DateTime month) =>
    'finance.common.month_label'.tr(args: {'month': month.month, 'year': month.year});

/// Lời nhắn lỗi hiện cho người dùng: ưu tiên lời nhắn server (gộp lỗi chi tiết), không thì [fallbackKey] đã dịch.
String financeErrorMessage(Object? error, [String fallbackKey = 'finance.common.error_generic']) {
  if (error is FinanceException) {
    final m = error.displayMessage;
    if (m != null && m.isNotEmpty) return m;
    if (error.isForbidden) return 'finance.common.error_forbidden'.tr();
  }
  return fallbackKey.tr();
}

/// Bỏ dấu để tìm kiếm "nguyen" vẫn ra "Nguyễn".
String financeFold(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
    .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
    .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
    .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
    .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
    .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
    .replaceAll('đ', 'd')
    .trim();

/// Ghi chú lưu HTML (rich text web) → chữ thường để hiển thị trên mobile.
String financeNoteToPlain(String? html) {
  if (html == null || html.isEmpty) return '';
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|li|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      // Giải `&amp;` sau cùng để "&amp;lt;" ra đúng "&lt;" (không bị giải hai lần).
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Chữ thường → HTML đoạn văn để lưu vào ô ghi chú (server lưu HTML).
String financePlainToNote(String text) {
  final t = text.trim();
  if (t.isEmpty) return '';
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return t.split(RegExp(r'\n\s*\n')).map((p) => '<p>${esc(p).replaceAll('\n', '<br>')}</p>').join();
}
