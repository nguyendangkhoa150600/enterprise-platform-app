import 'package:intl/intl.dart';

/// Định dạng số kiểu vi-VN như web `formatQuantityVn` / `formatCurrencyVn` / `formatDateTime`.
class InventoryOverviewFormat {
  InventoryOverviewFormat._();

  static final NumberFormat _quantity = NumberFormat('#,##0.###', 'vi_VN');
  static final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// Số lượng: tối đa 3 chữ số thập phân.
  static String quantity(num value) => _quantity.format(value);

  /// Tiền: không thập phân, không hậu tố đơn vị (như `formatCurrencyVn(total, { maxDecimals: 0 })`).
  static String currency(num value) => _currency.format(value);

  static String dateTime(String value) {
    if (value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '—';
    return _dateTime.format(parsed.toLocal());
  }
}
