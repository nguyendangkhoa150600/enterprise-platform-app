import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/contracts/contracts_repository.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_warehouse_select.dart';
import '../utils/crm_scope.dart';
import 'crm_fulfillment_ui.dart';

/// Lập hợp đồng (phần đầu; dòng giá khung, đợt thanh toán thêm ở màn chi tiết) hoặc sửa phần đầu hợp đồng Nháp
/// (web `ContractFormDialog`). [draft] điền sẵn khi lập mới (web `initialDraft`, vd. từ kết quả trúng thầu).
/// Trả hợp đồng đã lưu, null khi đóng.
Future<CrmContractDetail?> showCrmContractForm(
  BuildContext context, {
  CrmContractDetail? contract,
  CrmContractFormDraft? draft,
}) => showCrmSheet<CrmContractDetail>(
  context,
  builder: (_) => _ContractFormSheet(contract: contract, draft: draft),
);

/// Giá trị điền sẵn cho form lập hợp đồng mới.
class CrmContractFormDraft {
  final String? type;
  final String? customerId;
  final String? customerName;
  final String? title;
  final double? value;
  final String? validFrom;
  final String? ownerUserId;
  const CrmContractFormDraft({
    this.type,
    this.customerId,
    this.customerName,
    this.title,
    this.value,
    this.validFrom,
    this.ownerUserId,
  });
}

class _ContractFormSheet extends StatefulWidget {
  final CrmContractDetail? contract;
  final CrmContractFormDraft? draft;
  const _ContractFormSheet({this.contract, this.draft});

  @override
  State<_ContractFormSheet> createState() => _ContractFormSheetState();
}

class _ContractFormSheetState extends State<_ContractFormSheet> {
  late final CrmContractDetail? _c = widget.contract;
  late final CrmContractFormDraft? _d = _c == null ? widget.draft : null;
  late String _type = _c?.type ?? (_nonEmpty(_d?.type) ?? 'SALE');
  late String? _customerId = _c?.customerId ?? _nonEmpty(_d?.customerId);
  late String? _customerLabel = _c?.customerName ?? _nonEmpty(_d?.customerName);
  late final TextEditingController _title = TextEditingController(text: _c?.title ?? _d?.title ?? '');
  late String _signedDate = _c?.signedDate ?? '';
  late String _validFrom = _c?.validFrom ?? _d?.validFrom ?? '';
  late String _validTo = _c?.validTo ?? '';
  late final TextEditingController _value = TextEditingController(
    text: _c != null ? formatCrmPrice(_c.value) : (_d?.value == null ? '' : formatCrmPrice(_d!.value!)),
  );
  late final TextEditingController _warranty = TextEditingController(
    text: _c?.warrantyMonths == null ? '' : '${_c!.warrantyMonths}',
  );
  late String? _warehouseCode = _c?.warehouseCode;
  late String? _ownerUserId = _c?.ownerUserId ?? _nonEmpty(_d?.ownerUserId);

  static String? _nonEmpty(String? v) => v == null || v.isEmpty ? null : v;
  late final TextEditingController _note = TextEditingController(text: _c?.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _warranty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? fail;
    if (_customerId == null || _customerId!.isEmpty) {
      fail = 'crm.contracts.form.customer_required'.tr();
    } else if (_title.text.trim().isEmpty) {
      fail = 'crm.contracts.form.title_required'.tr();
    } else if (_validFrom.isEmpty) {
      fail = 'crm.contracts.form.valid_from_required'.tr();
    }
    final valueText = _value.text.trim();
    final amount = valueText.isEmpty ? null : parseCrmNumber(valueText);
    if (fail == null && valueText.isNotEmpty && amount == null) fail = 'crm.contracts.form.value_invalid'.tr();
    if (fail != null) return setState(() => _error = fail);
    final note = _note.text.trim();
    final body = <String, dynamic>{
      'type': _type,
      'customerId': _customerId,
      'title': _title.text.trim(),
      'signedDate': _signedDate.isEmpty ? null : _signedDate,
      'validFrom': _validFrom,
      'validTo': _validTo.isEmpty ? null : _validTo,
      'value': amount,
      'warrantyMonths': _warranty.text.trim().isEmpty ? null : int.tryParse(_warranty.text.trim()),
      'warehouseCode': (_warehouseCode ?? '').trim().isEmpty ? null : _warehouseCode!.trim(),
      'ownerUserId': (_ownerUserId ?? '').isEmpty ? null : _ownerUserId,
      'note': note.isEmpty ? null : note,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ContractsRepository.instance;
      final contract = _c;
      final saved = contract == null
          ? await repo.createContract(body)
          : await repo.updateContract(contract.id, {...body, 'revision': contract.revision});
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.contracts.form.save_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contract = _c;
    return CrmFormSheet(
      title: contract == null
          ? 'crm.contracts.form.create_title'.tr()
          : 'crm.contracts.form.edit_title'.tr(args: {'code': contract.code}),
      subtitle: 'crm.contracts.form.subtitle'.tr(),
      submitLabel: contract == null ? 'crm.contracts.form.create_submit'.tr() : 'crm.common.save'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.contracts.form.type'.tr(),
          required: true,
          child: CrmSelectField(
            value: _type,
            options: [for (final t in kCrmContractTypes) CrmSelectOption(value: t, label: crmContractTypeLabel(t))],
            searchHint: 'crm.common.search_placeholder'.tr(),
            onChanged: (s) => setState(() => _type = s.value ?? _type),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.customer'.tr(),
          required: true,
          child: CrmCustomerSelectField(
            value: _customerId,
            selectedLabel: _customerLabel,
            onChanged: (c) => setState(() {
              _customerId = c?.id;
              _customerLabel = c?.name;
            }),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.title'.tr(),
          required: true,
          child: TextField(controller: _title, maxLength: 300, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.contracts.form.signed_date'.tr(),
          child: CrmDateField(value: _signedDate, onChanged: (v) => setState(() => _signedDate = v)),
        ),
        CrmField(
          label: 'crm.contracts.form.valid_from'.tr(),
          required: true,
          child: CrmDateField(value: _validFrom, onChanged: (v) => setState(() => _validFrom = v)),
        ),
        CrmField(
          label: 'crm.contracts.form.valid_to'.tr(),
          hint: 'crm.contracts.form.valid_to_hint'.tr(),
          child: CrmDateField(value: _validTo, onChanged: (v) => setState(() => _validTo = v)),
        ),
        CrmField(
          label: 'crm.contracts.form.value'.tr(),
          hint: 'crm.contracts.form.value_hint'.tr(),
          child: TextField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: crmInputDecoration(),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.warranty'.tr(),
          child: TextField(
            controller: _warranty,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: crmInputDecoration(),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.warehouse'.tr(),
          hint: 'crm.contracts.form.warehouse_hint'.tr(),
          child: CrmWarehouseSelect(
            value: _warehouseCode,
            placeholder: 'crm.contracts.form.warehouse_placeholder'.tr(),
            onChanged: (code) => setState(() => _warehouseCode = code),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.owner'.tr(),
          hint: 'crm.contracts.form.owner_hint'.tr(),
          child: CrmPersonSelectField(
            value: _ownerUserId,
            placeholder: 'crm.contracts.form.owner_placeholder'.tr(),
            clearable: true,
            onChanged: (v) => setState(() => _ownerUserId = v),
          ),
        ),
        CrmField(
          label: 'crm.contracts.form.note'.tr(),
          child: TextField(
            controller: _note,
            maxLength: 4000,
            minLines: 3,
            maxLines: 6,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}
