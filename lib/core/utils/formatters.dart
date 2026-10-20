import 'package:intl/intl.dart';

/// Formatting utility methods across all modules
class Formatters {
  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  /// Format money to Vietnamese Dong (VNĐ)
  static String formatCurrency(dynamic amount, {bool showSymbol = true}) {
    if (amount == null) return showSymbol ? '0 đ' : '0';
    final num? val = num.tryParse(amount.toString());
    if (val == null) return showSymbol ? '0 đ' : '0';
    final formatted = _currencyFormatter.format(val.round());
    return showSymbol ? '$formatted đ' : formatted;
  }

  /// Format DateTime or ISO String to dd/MM/yyyy
  static String formatDate(dynamic date) {
    if (date == null || date.toString().trim().isEmpty || date.toString() == 'null') {
      return '----';
    }
    if (date is DateTime) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    final str = date.toString().trim();
    try {
      if (str.length >= 10) {
        final raw = str.substring(0, 10);
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
          final parts = raw.split('-');
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      final parsed = DateTime.parse(str);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return str;
    }
  }

  /// Format DateTime or ISO String to HH:mm (Time of Day)
  static String formatTime(dynamic date) {
    if (date == null) return '--:--';
    if (date is DateTime) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    try {
      final parsed = DateTime.parse(date.toString());
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }
}
