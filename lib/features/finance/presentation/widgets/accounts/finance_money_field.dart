import 'package:flutter/services.dart';

/// Số chữ số tối đa của ô nhập tiền (web `MONEY_INPUT_MAX_DIGITS`, khớp `kFinanceMaxAmount`).
const int kFinanceMoneyInputMaxDigits = 15;

/// "1500000" → "1.500.000" (luôn dùng dấu chấm như web `groupDigits`).
String financeGroupDigits(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Giá trị số → chuỗi hiển thị trong ô nhập ("-1.500.000"; 0 → "").
String financeMoneyInputText(num value) {
  final v = value.round();
  if (v == 0) return '';
  return '${v < 0 ? '-' : ''}${financeGroupDigits(v.abs().toString())}';
}

/// Chuỗi trong ô nhập → số (web `parseMoneyInput`, giữ dấu âm khi cho phép).
double financeParseMoneyInput(String text, {bool allowNegative = false}) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return 0;
  final value = double.tryParse(digits) ?? 0;
  return allowNegative && text.trimLeft().startsWith('-') ? -value : value;
}

/// Định dạng ô nhập tiền khi gõ: nhóm nghìn bằng dấu chấm, tối đa 15 chữ số, tuỳ chọn số âm.
class FinanceMoneyInputFormatter extends TextInputFormatter {
  final bool allowNegative;
  FinanceMoneyInputFormatter({this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final negative = allowNegative && raw.trimLeft().startsWith('-');
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > kFinanceMoneyInputMaxDigits) return oldValue;

    // Số chữ số đứng trước con trỏ để đặt lại con trỏ sau khi nhóm nghìn.
    final caret = newValue.selection.baseOffset.clamp(0, raw.length);
    final rawBefore = raw.substring(0, caret).replaceAll(RegExp(r'[^\d]'), '');
    final removedZeros = raw.replaceAll(RegExp(r'[^\d]'), '').length - digits.length;
    final before = (rawBefore.length - removedZeros).clamp(0, digits.length);

    final sign = negative ? '-' : '';
    final text = digits.isEmpty ? sign : sign + financeGroupDigits(digits);

    var position = sign.length;
    if (before > 0) {
      var seen = 0;
      for (var i = sign.length; i < text.length; i++) {
        if (RegExp(r'\d').hasMatch(text[i])) seen++;
        if (seen == before) {
          position = i + 1;
          break;
        }
      }
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: position));
  }
}
