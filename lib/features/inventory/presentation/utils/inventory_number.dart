/// Đọc số người dùng gõ / ô Excel theo chuẩn Việt Nam, dùng chung cho mọi ô số của module Kho
/// (web `VnNumberInput` dùng shared-ui `parseVnNumber`).
/// Web shared-ui `parseVnNumber`: `500.000.000,01`, `500000000,01`, `500000000.01`, `(1.500)`; sai → null.
double? parseVnNumber(String? text) {
  if (text == null) return null;
  var value = text.trim();
  if (value.isEmpty) return null;
  var negative = false;
  if (RegExp(r'^\(.*\)$').hasMatch(value)) {
    negative = true;
    value = value.substring(1, value.length - 1);
  }
  value = value.replaceAll(RegExp(r'[\s₫đ]|vnd', caseSensitive: false), '');
  if (value.startsWith('-')) {
    negative = true;
    value = value.substring(1);
  }
  if (value.isEmpty || !RegExp(r'^[\d.,]+$').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) return null;
  final hasDot = value.contains('.');
  final hasComma = value.contains(',');
  String normalized;
  if (hasDot && hasComma) {
    final decimal = value.lastIndexOf(',') > value.lastIndexOf('.') ? ',' : '.';
    final group = decimal == ',' ? '.' : ',';
    if (value.split(decimal).length != 2) return null;
    normalized = value.split(group).join().replaceFirst(decimal, '.');
  } else if (hasComma) {
    if (value.split(',').length != 2) return null;
    normalized = value.replaceFirst(',', '.');
  } else if (hasDot) {
    if (RegExp(r'^[1-9]\d{0,2}(\.\d{3})+$').hasMatch(value)) {
      normalized = value.replaceAll('.', '');
    } else if (value.split('.').length == 2) {
      normalized = value;
    } else {
      return null;
    }
  } else {
    normalized = value;
  }
  // `Number('.5')` của JS = 0.5; Dart cần số 0 đứng trước.
  final result = double.tryParse(normalized.startsWith('.') ? '0$normalized' : normalized);
  if (result == null || !result.isFinite) return null;
  if (result == 0) return 0;
  return negative ? -result : result;
}
