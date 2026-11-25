import 'package:intl/intl.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Định dạng tiền như web `money.ts` (vi-VN).
final NumberFormat _grouped = NumberFormat('#,##0', 'vi');
final NumberFormat _oneDecimal = NumberFormat('#,##0.#', 'vi');
final NumberFormat _twoDecimals = NumberFormat('#,##0.##', 'vi');

/// `25500000000` → `25.500.000.000 ₫`; rỗng → `—`.
String formatVnd(num? value) {
  if (value == null || !value.isFinite) return '—';
  return '${_grouped.format(value.round())} ₫';
}

/// `25500000000` → `25,5 tỷ`; `850000000` → `850 triệu`. Số âm giữ dấu.
String formatVndCompact(num? value) {
  if (value == null || !value.isFinite) return '—';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  String scaled(num amount, String unitKey) => '$sign${_oneDecimal.format(amount)} ${unitKey.tr()}';
  if (abs >= 1e9) return scaled(abs / 1e9, 'workspace.finance.unit_billion');
  if (abs >= 1e6) return scaled(abs / 1e6, 'workspace.finance.unit_million');
  if (abs >= 1e3) return scaled(abs / 1e3, 'workspace.finance.unit_thousand');
  return '$sign${_twoDecimals.format(abs)} đ';
}

/// `21.2` → `21,2%`.
String formatPercent(num? value) {
  if (value == null || !value.isFinite) return '—';
  return '${_oneDecimal.format(value)}%';
}

/// Chuỗi người dùng gõ → số. Rỗng → null (xoá giá trị); không đọc được → [double.nan].
double? parseVndInput(String text) {
  final trimmed = text.trim().replaceAll(RegExp(r'\s|₫|đ', caseSensitive: false), '');
  if (trimmed.isEmpty) return null;
  final normalised = trimmed.replaceAll('.', '').replaceFirst(',', '.');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(normalised)) return double.nan;
  return double.parse(normalised);
}

/// Số → chuỗi điền sẵn vào ô nhập, đúng cách người dùng sẽ gõ.
String toVndInput(num? value) => value == null ? '' : _twoDecimals.format(value);

/// `2026-10-09` → `09/10/2026`; đọc thẳng chuỗi, không qua DateTime (lệch múi giờ).
String formatDay(String? value) {
  if (value == null || value.length < 10) return '—';
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) return '—';
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// ISO datetime → `09/10/2026 14:05` theo giờ máy (như `formatDateTime` của shared-ui).
String formatDateTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}';
}
