import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Ô nhập dùng chung của form phiếu (web `ui/form-parts.tsx`: Field, FormSection, MoneyInput).

const _labelStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155));
const _hintStyle = TextStyle(fontSize: 11.5, color: FinanceColors.muted, height: 1.35);

InputDecoration voucherInputDecoration({String? hint, Widget? suffix, bool disabled = false}) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: FinanceColors.faint),
      filled: true,
      fillColor: disabled ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FinanceColors.border)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FinanceColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FinanceColors.primary, width: 1.4)),
    );

/// Khối thu gọn được ("Thông tin chung", "Chi tiết thu"...).
class VoucherFormSection extends StatefulWidget {
  final String title;
  final bool initiallyOpen;
  final Widget child;
  const VoucherFormSection({super.key, required this.title, required this.child, this.initiallyOpen = true});

  @override
  State<VoucherFormSection> createState() => _VoucherFormSectionState();
}

class _VoucherFormSectionState extends State<VoucherFormSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_more_rounded, size: 20, color: FinanceColors.text),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
              ],
            ),
          ),
          if (_open) ...[const SizedBox(height: 12), widget.child],
        ],
      ),
    );
  }
}

/// Nhãn + ô nhập + gợi ý. [locked]: trường lấy từ hồ sơ quy trình (biểu tượng khoá).
class VoucherField extends StatelessWidget {
  final String label;
  final bool required;
  final bool locked;
  final String? hint;
  final Widget child;
  const VoucherField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.locked = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
              if (locked)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Tooltip(
                    message: 'finance.voucher_form.locked_hint'.tr(),
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock_outline_rounded, size: 13, color: FinanceColors.faint),
                    ),
                  ),
                ),
            ]),
            style: _labelStyle,
          ),
          const SizedBox(height: 5),
          child,
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hint!, style: _hintStyle),
          ],
        ],
      ),
    );
  }
}

/// Ô chữ tự giữ controller; [initialValue] chỉ đọc lần đầu.
class VoucherTextInput extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool enabled;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;

  const VoucherTextInput({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.placeholder,
    this.enabled = true,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
  });

  @override
  State<VoucherTextInput> createState() => _VoucherTextInputState();
}

class _VoucherTextInputState extends State<VoucherTextInput> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType ?? (widget.maxLines > 1 ? TextInputType.multiline : null),
      textAlign: widget.textAlign,
      style: TextStyle(fontSize: 14, color: widget.enabled ? FinanceColors.text : FinanceColors.muted),
      inputFormatters: [
        if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
        ...?widget.inputFormatters,
      ],
      decoration: voucherInputDecoration(hint: widget.placeholder, disabled: !widget.enabled),
      onChanged: widget.onChanged,
    );
  }
}

/// Định dạng phân cách hàng nghìn ngay khi gõ; tối đa 15 chữ số (web `MONEY_INPUT_MAX_DIGITS`).
class _MoneyFormatter extends TextInputFormatter {
  static const int maxDigits = 15;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > maxDigits) return oldValue;
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final caretDigits = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^\d]'), '')
        .length
        .clamp(0, digits.length);
    final display = formatFinanceMoney(int.parse(digits));
    var pos = display.length;
    if (caretDigits < digits.length) {
      var seen = 0;
      pos = 0;
      for (var i = 0; i < display.length && seen < caretDigits; i++) {
        if (RegExp(r'\d').hasMatch(display[i])) seen++;
        pos = i + 1;
      }
    }
    return TextEditingValue(text: display, selection: TextSelection.collapsed(offset: pos));
  }
}

double _parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  return digits.isEmpty ? 0 : double.parse(digits);
}

/// Ô nhập tiền (số nguyên VND, căn phải, phân cách hàng nghìn).
class VoucherMoneyInput extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final String? placeholder;
  const VoucherMoneyInput({super.key, required this.value, required this.onChanged, this.enabled = true, this.placeholder});

  @override
  State<VoucherMoneyInput> createState() => _VoucherMoneyInputState();
}

class _VoucherMoneyInputState extends State<VoucherMoneyInput> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value == 0 ? '' : formatFinanceMoney(widget.value.truncate()));

  @override
  void didUpdateWidget(covariant VoucherMoneyInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _parseMoney(_ctrl.text)) {
      _ctrl.text = widget.value == 0 ? '' : formatFinanceMoney(widget.value.truncate());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: widget.enabled ? FinanceColors.text : FinanceColors.muted,
      ),
      inputFormatters: [_MoneyFormatter()],
      decoration: voucherInputDecoration(
        hint: widget.placeholder ?? 'finance.voucher_form.amount_placeholder'.tr(),
        disabled: !widget.enabled,
      ),
      onChanged: (text) => widget.onChanged(_parseMoney(text)),
    );
  }
}

/// Ô số thập phân (số lượng, thuế suất): chấp nhận "," hoặc "." làm dấu thập phân.
/// Vượt [max] thì kẹp lại và ghi lại số đã kẹp vào ô (như web: ô hiện đúng giá trị đã lưu).
class VoucherDecimalInput extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final double? max;
  const VoucherDecimalInput({super.key, required this.value, required this.onChanged, this.enabled = true, this.max});

  static String _fmt(double v) => v == 0 ? '' : (v == v.truncateToDouble() ? v.toInt().toString() : v.toString());

  @override
  State<VoucherDecimalInput> createState() => _VoucherDecimalInputState();
}

class _VoucherDecimalInputState extends State<VoucherDecimalInput> {
  late final TextEditingController _ctrl = TextEditingController(text: VoucherDecimalInput._fmt(widget.value));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _changed(String text) {
    var v = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    if (v < 0) v = 0;
    final max = widget.max;
    if (max != null && v > max) {
      v = max;
      final clamped = VoucherDecimalInput._fmt(v);
      _ctrl.value = TextEditingValue(text: clamped, selection: TextSelection.collapsed(offset: clamped.length));
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 14, color: widget.enabled ? FinanceColors.text : FinanceColors.muted),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: voucherInputDecoration(disabled: !widget.enabled),
      onChanged: _changed,
    );
  }
}

/// Ô chọn ngày (`YYYY-MM-DD`); [clearable] cho ngày không bắt buộc.
class VoucherDateInput extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool clearable;
  final String? placeholder;
  const VoucherDateInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.clearable = false,
    this.placeholder,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = parseFinanceDate(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(financeApiDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: empty,
        decoration: voucherInputDecoration(
          hint: placeholder ?? 'finance.voucher_form.pick_date'.tr(),
          disabled: !enabled,
          suffix: clearable && !empty && enabled
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: FinanceColors.muted),
                  onPressed: () => onChanged(''),
                )
              : const Icon(Icons.calendar_today_outlined, size: 17, color: FinanceColors.muted),
        ),
        child: Text(
          empty ? '' : formatFinanceDate(value),
          style: TextStyle(fontSize: 14, color: enabled ? FinanceColors.text : FinanceColors.muted),
        ),
      ),
    );
  }
}
