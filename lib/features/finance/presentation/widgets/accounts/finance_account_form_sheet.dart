import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';
import 'finance_bank_picker_sheet.dart';
import 'finance_money_field.dart';

/// Lưu tài khoản: [account] null = thêm mới. Ném lỗi để form hiện lời nhắn của server.
typedef FinanceAccountSaver = Future<void> Function(String? id, Map<String, dynamic> body);

/// Form "Thêm tài khoản" / "Sửa tài khoản" (web `AccountDialog`) dạng bottom sheet gần toàn màn.
/// Trả true khi đã lưu.
Future<bool> showFinanceAccountForm(BuildContext context, {FinanceAccount? account, required FinanceAccountSaver onSave}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _AccountFormSheet(account: account, onSave: onSave),
  );
  return saved ?? false;
}

/// Tài khoản đã có phát sinh thu/chi (web `hasMovements`): khoá số dư đầu kỳ, ngày bắt đầu và loại tài khoản.
bool financeAccountHasMovements(FinanceAccount a) => (a.totalReceipts ?? 0) > 0 || (a.totalPayments ?? 0) > 0;

/// Mã tài khoản hợp lệ (server `CODE`).
final RegExp _codePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,49}$');

class _AccountFormSheet extends StatefulWidget {
  final FinanceAccount? account;
  final FinanceAccountSaver onSave;
  const _AccountFormSheet({this.account, required this.onSave});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _accountNumber;
  late final TextEditingController _holder;
  late final TextEditingController _branch;
  late final TextEditingController _opening;
  late final TextEditingController _note;
  late FinanceAccountType _type;
  late String _bankName;
  late String _openingDate;
  late bool _allowNegative;
  late bool _isActive;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  bool get _locked => widget.account != null && financeAccountHasMovements(widget.account!);
  bool get _bank => _type == FinanceAccountType.bank;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _code = TextEditingController(text: a?.code ?? '');
    _name = TextEditingController(text: a?.name ?? '');
    _accountNumber = TextEditingController(text: a?.accountNumber ?? '');
    _holder = TextEditingController(text: a?.accountHolder ?? '');
    _branch = TextEditingController(text: a?.branch ?? '');
    _opening = TextEditingController(text: financeMoneyInputText(a?.openingBalance ?? 0));
    _note = TextEditingController(text: a?.note ?? '');
    _type = a?.accountType ?? FinanceAccountType.bank;
    _bankName = a?.bankName ?? '';
    _openingDate = (a != null && a.openingDate.isNotEmpty) ? a.openingDate : financeApiDate(DateTime.now());
    _allowNegative = a?.allowNegative ?? true;
    _isActive = a?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _accountNumber, _holder, _branch, _opening, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Kiểm tra trước như server (`saveAccount`) để báo lỗi ngay tại ô.
  String? _codeError() {
    final v = _code.text.trim();
    if (v.isEmpty) return 'finance.accounts.error_code_required'.tr();
    if (!_codePattern.hasMatch(v)) return 'finance.accounts.error_code_invalid'.tr();
    return null;
  }

  String? _nameError() => _name.text.trim().isEmpty ? 'finance.accounts.error_name_required'.tr() : null;
  String? _bankError() => _bank && _bankName.trim().isEmpty ? 'finance.accounts.error_bank_required'.tr() : null;
  String? _numberError() =>
      _bank && _accountNumber.text.trim().isEmpty ? 'finance.accounts.error_number_required'.tr() : null;

  Future<void> _pickDate() async {
    final initial = parseFinanceDate(_openingDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _openingDate = financeApiDate(picked));
  }

  Future<void> _pickBank() async {
    final picked = await showFinanceBankPicker(context, selected: _bankName);
    if (!mounted || picked == null) return;
    setState(() => _bankName = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if ([_codeError(), _nameError(), _bankError(), _numberError()].any((e) => e != null)) return;
    final opening = financeParseMoneyInput(_opening.text, allowNegative: true);
    if (opening.abs() > kFinanceMaxAmount) {
      setState(() => _error = 'finance.accounts.error_opening_invalid'.tr());
      return;
    }
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    final body = <String, dynamic>{
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'accountType': _type.api,
      'bankName': _bank ? orNull(_bankName) : null,
      'accountNumber': _bank ? orNull(_accountNumber.text) : null,
      'accountHolder': _bank ? orNull(_holder.text) : null,
      'branch': _bank ? orNull(_branch.text) : null,
      'allowNegative': _allowNegative,
      'isActive': _isActive,
      'note': orNull(_note.text),
      if (!_locked) 'openingBalance': opening,
      if (!_locked) 'openingDate': _openingDate,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.account?.id, body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = financeErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.account != null;
    final lockedHint = 'finance.accounts.locked_hint'.tr();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(editing ? 'finance.accounts.edit_title'.tr() : 'finance.accounts.add'.tr(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FinanceColors.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_error != null) _ErrorBanner(message: _error!),
                  _Labeled(
                    label: 'finance.accounts.field_code'.tr(),
                    required: true,
                    child: _input(_code, maxLength: 50, error: _submitted ? _codeError() : null),
                  ),
                  _Labeled(
                    label: 'finance.accounts.field_type'.tr(),
                    required: true,
                    hint: _locked ? lockedHint : null,
                    child: SegmentedButton<FinanceAccountType>(
                      showSelectedIcon: false,
                      segments: [
                        for (final t in FinanceAccountType.values)
                          ButtonSegment(value: t, label: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      selected: {_type},
                      onSelectionChanged: _locked ? null : (s) => setState(() => _type = s.first),
                    ),
                  ),
                  _Labeled(
                    label: 'finance.accounts.field_name'.tr(),
                    required: true,
                    child: _input(_name, maxLength: 255, error: _submitted ? _nameError() : null),
                  ),
                  if (_bank) ...[
                    _Labeled(
                      label: 'finance.accounts.field_bank'.tr(),
                      required: true,
                      child: _PickerBox(
                        text: _bankName.isEmpty ? null : _bankName,
                        placeholder: 'finance.accounts.bank_placeholder'.tr(),
                        error: _submitted ? _bankError() : null,
                        onTap: _pickBank,
                      ),
                    ),
                    _Labeled(
                      label: 'finance.accounts.field_number'.tr(),
                      required: true,
                      child: _input(_accountNumber, maxLength: 60, error: _submitted ? _numberError() : null),
                    ),
                    _Labeled(label: 'finance.accounts.field_holder'.tr(), child: _input(_holder, maxLength: 255)),
                    _Labeled(label: 'finance.accounts.field_branch'.tr(), child: _input(_branch, maxLength: 255)),
                  ],
                  _Labeled(
                    label: 'finance.accounts.field_opening_balance'.tr(),
                    hint: _locked ? lockedHint : null,
                    child: TextField(
                      controller: _opening,
                      enabled: !_locked,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      inputFormatters: [FinanceMoneyInputFormatter(allowNegative: true)],
                      textAlign: TextAlign.right,
                      decoration: _decoration(hint: '0'),
                    ),
                  ),
                  _Labeled(
                    label: 'finance.accounts.field_opening_date'.tr(),
                    hint: _locked ? lockedHint : 'finance.accounts.opening_date_hint'.tr(),
                    child: _PickerBox(
                      text: formatFinanceDate(_openingDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _locked ? null : _pickDate,
                    ),
                  ),
                  CheckboxListTile(
                    value: _allowNegative,
                    onChanged: (v) => setState(() => _allowNegative = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('finance.accounts.allow_negative'.tr(), style: const TextStyle(fontSize: 14)),
                  ),
                  CheckboxListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('finance.accounts.is_active'.tr(), style: const TextStyle(fontSize: 14)),
                  ),
                  _Labeled(
                    label: 'common.note'.tr(),
                    child: _input(_note, maxLength: 2000, maxLines: 3),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: FinanceColors.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: Text('finance.accounts.cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: FinanceColors.primary,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(editing ? 'common.update'.tr() : 'finance.accounts.add'.tr(),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({String? error, String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        errorText: error,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _input(TextEditingController c, {int? maxLength, String? error, int maxLines = 1}) => TextField(
        controller: c,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        onChanged: _submitted ? (_) => setState(() {}) : null,
        decoration: _decoration(error: error),
      );
}

class _Labeled extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final Widget child;
  const _Labeled({required this.label, required this.child, this.required = false, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: label),
            if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
          ]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          child,
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Ô chọn (ngân hàng / ngày) trông như ô nhập.
class _PickerBox extends StatelessWidget {
  final String? text;
  final String? placeholder;
  final String? error;
  final IconData icon;
  final VoidCallback? onTap;
  const _PickerBox({this.text, this.placeholder, this.error, this.onTap, this.icon = Icons.expand_more_rounded});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: text == null,
        decoration: InputDecoration(
          isDense: true,
          enabled: !disabled,
          hintText: placeholder,
          errorText: error,
          suffixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: text == null
            ? null
            : Text(text!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: disabled ? FinanceColors.faint : FinanceColors.text)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
    );
  }
}
