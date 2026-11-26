import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';

/// Định dạng số/tiền/ngày của CRM, khớp web (`Intl.NumberFormat('vi-VN')`: nhóm nghìn `.`, thập phân `,`).

final NumberFormat _int = NumberFormat('#,##0', 'vi_VN');
final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'vi_VN');
final NumberFormat _twoDecimals = NumberFormat('#,##0.##', 'vi_VN');
final NumberFormat _threeDecimals = NumberFormat('#,##0.###', 'vi_VN');
final NumberFormat _fourDecimals = NumberFormat('#,##0.####', 'vi_VN');

/// Web `sales.model formatMoney`: `1234567` → `1.234.567 ₫`; null → ''.
String formatCrmMoney(num? value) => value == null ? '' : '${_int.format(value)} ₫';

/// Web `pricing.model formatMoney` (bảng giá, chiết khấu, đơn giá): tối đa 2 chữ số lẻ, không ký hiệu; null → ''.
String formatCrmPrice(num? value) => value == null ? '' : _twoDecimals.format(value);

/// Web `formatVndCompact`: `25500000000` → `25,5 tỷ`; `850000000` → `850 triệu`; dưới nghìn `950 ₫`; null → `—`.
String formatCrmVndCompact(num? value) {
  if (value == null || !value.isFinite) return '—';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  String scaled(num amount, String unitKey) => '$sign${_oneDecimal.format(amount)} ${unitKey.tr()}';
  if (abs >= 1e9) return scaled(abs / 1e9, 'crm.format.billion');
  if (abs >= 1e6) return scaled(abs / 1e6, 'crm.format.million');
  if (abs >= 1e3) return scaled(abs / 1e3, 'crm.format.thousand');
  return '$sign${_int.format(abs)} ₫';
}

/// Web `formatRate`: `66.67` → `66,7%`; null → `—`.
String formatCrmRate(num? value) => value == null ? '—' : '${_oneDecimal.format(value)}%';

/// Web `formatCount`: số nguyên kiểu Việt Nam.
String formatCrmCount(num value) => _int.format(value);

/// Web `formatQuantity`: tối đa 3 chữ số lẻ; null → ''.
String formatCrmQuantity(num? value) => value == null ? '' : _threeDecimals.format(value);

/// Web `pricing.model formatPercent`: tối đa 4 chữ số lẻ kèm `%`; null → ''.
String formatCrmPercent(num? value) => value == null ? '' : '${_fourDecimals.format(value)}%';

/// Web `formatDay` / `formatDate`: `YYYY-MM-DD` → `DD/MM/YYYY` (lấy 10 ký tự đầu nếu là ISO); rỗng → ''.
String formatCrmDay(String? value) {
  if (value == null || value.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  return m == null ? value : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// Thời điểm ISO → `dd/MM/yyyy HH:mm` theo giờ Việt Nam (web hiển thị `toLocaleString('vi-VN')` múi Asia/Ho_Chi_Minh).
String formatCrmDateTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final d = DateTime.tryParse(value);
  if (d == null) return value;
  return DateFormat('dd/MM/yyyy HH:mm').format(d.toUtc().add(const Duration(hours: 7)));
}

/// DateTime → `YYYY-MM-DD` (định dạng ngày của API).
String crmApiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Hôm nay theo giờ Việt Nam, `YYYY-MM-DD` (web `todayInVietnam`).
String crmTodayVn() => crmApiDate(DateTime.now().toUtc().add(const Duration(hours: 7)));

/// `YYYY-MM-DD` → DateTime (00:00 giờ máy); rỗng/sai → null.
DateTime? parseCrmDay(String? value) {
  if (value == null || value.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

/// Web `formatBytes`: `1536` → `1.5 KB`.
String formatCrmBytes(num? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '${bytes.toInt()} B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final whole = value == value.truncateToDouble();
  return '${value.toStringAsFixed(value >= 100 || whole ? 0 : 1)} ${units[unit]}';
}

/// Web `parseNumber`: nhận `1.234.567,5`, `1,234,567.5`, `1234,5`, bỏ khoảng trắng và `%`; sai → null.
double? parseCrmNumber(String text) {
  final value = text.trim().replaceAll(RegExp(r'\s|%'), '');
  if (value.isEmpty) return null;
  String normalized;
  if (RegExp(r'^-?\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(value)) {
    normalized = value.replaceAll('.', '').replaceFirst(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(value)) {
    normalized = value.replaceAll(',', '');
  } else {
    normalized = value.replaceFirst(',', '.');
  }
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(normalized)) return null;
  return double.tryParse(normalized);
}

/// Kết quả kiểm một ô số: [value] khi hợp lệ, [error] (đã dịch) khi sai.
class CrmParsedNumber {
  final double? value;
  final String? error;
  const CrmParsedNumber.ok(double this.value) : error = null;
  const CrmParsedNumber.fail(String this.error) : value = null;
  bool get ok => error == null;
}

bool _atMostTwoDecimals(double value) => ((value * 100).round() - value * 100).abs() < 1e-6;

/// Web `parseVatRate`: số từ 0 đến 100, tối đa 2 chữ số lẻ.
CrmParsedNumber parseCrmVatRate(String text) {
  final value = parseCrmNumber(text);
  if (value == null) return CrmParsedNumber.fail('crm.validation.vat_nan'.tr());
  if (value < 0 || value > 100) return CrmParsedNumber.fail('crm.validation.vat_range'.tr());
  if (!_atMostTwoDecimals(value)) return CrmParsedNumber.fail('crm.validation.vat_decimals'.tr());
  return CrmParsedNumber.ok(value);
}

/// Web `parseUnitPrice`: số không âm, tối đa 2 chữ số lẻ.
CrmParsedNumber parseCrmUnitPrice(String text) {
  final value = parseCrmNumber(text);
  if (value == null || value < 0) return CrmParsedNumber.fail('crm.validation.unit_price_invalid'.tr());
  if (!_atMostTwoDecimals(value)) return CrmParsedNumber.fail('crm.validation.unit_price_decimals'.tr());
  return CrmParsedNumber.ok(value);
}
