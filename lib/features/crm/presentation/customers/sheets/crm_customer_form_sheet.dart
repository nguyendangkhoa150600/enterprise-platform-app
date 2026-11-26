import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/common/crm_directory_models.dart';
import '../../../domain/crm_exception.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_pickers.dart';
import '../../common/crm_select.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_quick_group_sheet.dart';

/// Thêm hoặc sửa khách hàng (web `CustomerFormDialog`). Trả hồ sơ đã lưu; null khi đóng.
Future<CrmCustomerDetail?> showCrmCustomerFormSheet(BuildContext context, {CrmCustomerDetail? customer}) =>
    showCrmSheet<CrmCustomerDetail>(context, builder: (_) => _CustomerFormSheet(customer: customer));

class _CustomerFormSheet extends StatefulWidget {
  final CrmCustomerDetail? customer;
  const _CustomerFormSheet({this.customer});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final CrmScope _scope = CrmScope.instance;
  late final CrmCustomerDetail? _c = widget.customer;
  late final _code = TextEditingController(text: _c?.code ?? '');
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _taxCode = TextEditingController(text: _c?.taxCode ?? '');
  late final _province = TextEditingController(text: _c?.province ?? '');
  late final _region = TextEditingController(text: _c?.region ?? '');
  late final _industry = TextEditingController(text: _c?.industry ?? '');
  late final _phone = TextEditingController(text: _c?.phone ?? '');
  late final _email = TextEditingController(text: _c?.email ?? '');
  late final _creditLimit = TextEditingController(
    text: _c?.creditLimit == null ? '' : _c!.creditLimit!.round().toString(),
  );
  late final _paymentTermDays = TextEditingController(text: _c?.paymentTermDays?.toString() ?? '');
  late final _address = TextEditingController(text: _c?.address ?? '');
  late final _note = TextEditingController(text: _c?.note ?? '');
  late String _kind = _c?.kind ?? CrmCustomerKind.defaultKind;
  late String? _groupId = _c?.groupId;
  late String? _ownerUserId = _c?.ownerUserId;
  String? _createdKindName;
  String? _createdGroupName;

  List<CrmTaxCodeMatch> _matches = const [];
  bool _confirmDuplicate = false;
  bool _submitting = false;
  String? _error;
  Timer? _taxTimer;
  int _taxRequest = 0;

  String get _duplicatePrompt => 'crm.customers.form.duplicate_prompt'.tr();
  bool get _canManageGroups => _scope.capabilities.isManager;

  @override
  void dispose() {
    _taxTimer?.cancel();
    for (final c in [
      _code, _name, _taxCode, _province, _region, _industry, _phone, _email, _creditLimit, _paymentTermDays, //
      _address, _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _taxCodeError => crmTaxCodeLooksValid(_taxCode.text) ? null : 'crm.customers.form.tax_code_invalid'.tr();

  /// Web: cảnh báo trùng MST ngay khi nhập xong một MST hợp lệ (chờ 400 ms).
  void _onTaxCodeChanged(String _) {
    _taxTimer?.cancel();
    final request = ++_taxRequest;
    setState(() {
      _confirmDuplicate = false;
      if (_error == _duplicatePrompt) _error = null;
    });
    final value = _taxCode.text.trim();
    if (value.isEmpty || !crmTaxCodeLooksValid(value) || value == _c?.taxCode) {
      setState(() => _matches = const []);
      return;
    }
    _taxTimer = Timer(const Duration(milliseconds: 400), () async {
      List<CrmTaxCodeMatch> rows;
      try {
        rows = await CrmCustomersRepository.instance.findTaxCodeMatches(value, excludeId: _c?.id);
      } catch (_) {
        rows = const [];
      }
      if (!mounted || request != _taxRequest) return;
      setState(() => _matches = rows);
    });
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  int? _number(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return setState(() => _error = 'crm.customers.form.name_required'.tr());
    final taxError = _taxCodeError;
    if (taxError != null) return setState(() => _error = taxError);
    // Trùng MST: lần bấm đầu chỉ cảnh báo, bấm "Vẫn lưu" mới gửi xác nhận.
    if (_matches.isNotEmpty && !_confirmDuplicate) {
      return setState(() {
        _confirmDuplicate = true;
        _error = _duplicatePrompt;
      });
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'taxCode': _text(_taxCode),
      'address': _text(_address),
      'province': _text(_province),
      'region': _text(_region),
      'industry': _text(_industry),
      'phone': _text(_phone),
      'email': _text(_email),
      'groupId': (_groupId == null || _groupId!.isEmpty) ? null : _groupId,
      'kind': _kind,
      'creditLimit': _number(_creditLimit),
      'paymentTermDays': _number(_paymentTermDays),
      'note': _text(_note),
      'ownerUserId': (_ownerUserId == null || _ownerUserId!.isEmpty) ? null : _ownerUserId,
      'confirmDuplicateTaxCode': _confirmDuplicate,
    };
    final repo = CrmCustomersRepository.instance;
    final c = _c;
    try {
      final saved = c != null
          ? await repo.updateCustomer(c.id, {
              ...fields,
              'code': _code.text.trim().isEmpty ? c.code : _code.text.trim(),
              'version': c.version,
            })
          : await repo.createCustomer({...fields, 'code': _text(_code)});
      if (!mounted) return;
      showCrmSnack(
        context,
        c != null ? 'crm.customers.form.saved'.tr() : 'crm.customers.form.created'.tr(args: {'code': saved.code}),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      _scope.onError(e);
      setState(() {
        _submitting = false;
        if (e is CrmException && e.code == kCrmDuplicateTaxCode) {
          _matches = e.listOf('matches').map(CrmTaxCodeMatch.fromJson).toList();
          _confirmDuplicate = true;
          _error = _duplicatePrompt;
        } else {
          _error = crmErrorMessage(e, 'crm.customers.form.error');
        }
      });
    }
  }

  Future<void> _createKind() async {
    final created = await showCrmQuickGroupSheet(context, kind: true);
    if (!mounted || created == null) return;
    setState(() {
      _kind = created.value;
      _createdKindName = created.name;
    });
  }

  Future<void> _createGroup() async {
    final created = await showCrmQuickGroupSheet(context, kind: false);
    if (!mounted || created == null) return;
    setState(() {
      _groupId = created.value;
      _createdGroupName = created.name;
    });
  }

  Widget _input(
    String labelKey,
    TextEditingController ctrl, {
    int maxLength = 100,
    bool required = false,
    bool digits = false,
    int lines = 1,
    String? hint,
    String? placeholder,
    String? error,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) {
    return CrmField(
      label: labelKey.tr(),
      required: required,
      hint: hint,
      error: error,
      child: TextField(
        controller: ctrl,
        maxLength: digits ? 18 : maxLength,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        keyboardType: digits ? TextInputType.number : keyboard,
        inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
        onChanged: onChanged,
        decoration: crmInputDecoration(hint: placeholder).copyWith(counterText: ''),
      ),
    );
  }

  Widget _footerAction(String labelKey, VoidCallback onTap) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(labelKey.tr()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final duplicate = _matches.isNotEmpty;
    return CrmFormSheet(
      title: c != null
          ? 'crm.customers.form.edit_title'.tr(args: {'code': c.code})
          : 'crm.customers.form.create_title'.tr(),
      subtitle: c != null ? null : 'crm.customers.form.create_subtitle'.tr(),
      submitLabel: duplicate && _confirmDuplicate ? 'crm.customers.form.save_anyway'.tr() : null,
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        _input(
          'crm.customers.form.code',
          _code,
          maxLength: 50,
          hint: c != null ? null : 'crm.customers.form.code_hint'.tr(),
        ),
        _input('crm.customers.form.name', _name, maxLength: 300, required: true),
        _input(
          'crm.customers.form.tax_code',
          _taxCode,
          maxLength: 14,
          placeholder: 'crm.customers.form.tax_code_placeholder'.tr(),
          error: _taxCodeError,
          onChanged: _onTaxCodeChanged,
        ),
        if (duplicate)
          CrmBanner(
            kind: CrmBannerKind.warning,
            message: [
              'crm.customers.form.duplicate_title'.tr(),
              for (final m in _matches) '• ${m.code} - ${m.name}',
              'crm.customers.form.duplicate_hint'.tr(),
            ].join('\n'),
          ),
        ValueListenableBuilder<List<CrmCustomerKind>>(
          valueListenable: _scope.kinds,
          builder: (context, kinds, _) => CrmField(
            label: 'crm.customers.form.kind'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CrmSelectField(
                  value: _kind,
                  options: crmKindOptions(kinds),
                  selectedLabel: _createdKindName,
                  placeholder: 'crm.customers.form.kind_placeholder'.tr(),
                  onChanged: (s) => setState(() => _kind = s.value ?? CrmCustomerKind.defaultKind),
                ),
                if (_canManageGroups) _footerAction('crm.customers.form.create_kind', _createKind),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<List<CrmCustomerGroup>>(
          valueListenable: _scope.groups,
          builder: (context, groups, _) => CrmField(
            label: 'crm.customers.form.group'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CrmSelectField(
                  value: _groupId,
                  options: crmGroupOptions(groups),
                  selectedLabel: _createdGroupName ?? c?.groupName,
                  placeholder: 'crm.customers.form.group_placeholder'.tr(),
                  emptyText: _canManageGroups
                      ? 'crm.customers.form.group_empty'.tr()
                      : 'crm.customers.form.group_empty_ask_admin'.tr(),
                  clearable: true,
                  onChanged: (s) => setState(() => _groupId = s.value),
                ),
                if (_canManageGroups) _footerAction('crm.customers.form.create_group', _createGroup),
              ],
            ),
          ),
        ),
        CrmField(
          label: 'crm.customers.form.owner'.tr(),
          hint: c != null ? null : 'crm.customers.form.owner_hint'.tr(),
          child: CrmPersonSelectField(
            value: _ownerUserId,
            placeholder: 'crm.customers.form.owner_placeholder'.tr(),
            clearable: true,
            onChanged: (v) => setState(() => _ownerUserId = v),
          ),
        ),
        _input('crm.customers.form.province', _province),
        _input('crm.customers.form.region', _region),
        _input('crm.customers.form.industry', _industry),
        _input('crm.customers.form.phone', _phone, maxLength: 50, keyboard: TextInputType.phone),
        _input('crm.customers.form.email', _email, maxLength: 200, keyboard: TextInputType.emailAddress),
        _input('crm.customers.form.credit_limit', _creditLimit, digits: true),
        _input('crm.customers.form.payment_term_days', _paymentTermDays, digits: true),
        _input('crm.customers.form.address', _address, maxLength: 500),
        _input('crm.customers.form.note', _note, maxLength: 2000, lines: 3),
      ],
    );
  }
}
