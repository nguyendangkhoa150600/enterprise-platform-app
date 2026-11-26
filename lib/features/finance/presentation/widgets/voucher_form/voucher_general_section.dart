import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_labels.dart';
import 'voucher_form_data.dart';
import 'voucher_form_fields.dart';
import 'voucher_select_field.dart';

/// Khối "Thông tin chung" của form phiếu (web `voucher-form-screen.tsx`), đúng các trường web hiện theo loại phiếu.
class VoucherGeneralSection extends StatelessWidget {
  final FinanceVoucherKind kind;
  final VoucherFormData form;
  final String code;
  final List<VoucherSelectOption> reasonOptions;
  final List<VoucherSelectOption> accountOptions;
  final List<VoucherSelectOption> groupOptions;
  final List<VoucherSelectOption> projectOptions;
  final bool projectRequired;

  /// Gợi ý khi Workspace lỗi; null khi bình thường.
  final String? workspaceHint;
  final String? workspaceProblem;

  /// Trường lấy từ hồ sơ quy trình (khoá).
  final bool Function(String field) fromSource;

  /// Gọi sau khi [form] đã đổi để vẽ lại.
  final VoidCallback onChanged;

  const VoucherGeneralSection({
    super.key,
    required this.kind,
    required this.form,
    required this.code,
    required this.reasonOptions,
    required this.accountOptions,
    required this.groupOptions,
    required this.projectOptions,
    required this.projectRequired,
    required this.workspaceHint,
    required this.workspaceProblem,
    required this.fromSource,
    required this.onChanged,
  });

  String _choose(String label) => 'finance.voucher_form.choose'.tr(args: {'label': label.toLowerCase()});

  void _set(void Function() apply) {
    apply();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      VoucherField(
        label: kind.label('code_label'),
        child: InputDecorator(
          decoration: voucherInputDecoration(disabled: true),
          child: Text(code, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: VoucherField(
              label: kind.label('date_label'),
              required: true,
              locked: fromSource('voucherDate'),
              child: VoucherDateInput(
                value: form.voucherDate,
                enabled: !fromSource('voucherDate'),
                onChanged: (v) => _set(() => form.voucherDate = v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: VoucherField(
              label: 'finance.voucher_form.posting_date'.tr(),
              required: true,
              child: VoucherDateInput(value: form.postingDate, onChanged: (v) => _set(() => form.postingDate = v)),
            ),
          ),
        ],
      ),
      VoucherField(
        label: kind.label('content_label'),
        required: true,
        locked: fromSource('content'),
        child: VoucherTextInput(
          initialValue: form.content,
          enabled: !fromSource('content'),
          placeholder: kind.label('content_placeholder'),
          maxLength: 500,
          maxLines: 3,
          keyboardType: TextInputType.text,
          onChanged: (v) => form.content = v,
        ),
      ),
      if (kind.hasLines) ..._receiptPaymentFields() else ..._transferFields(),
    ];
    return VoucherFormSection(
      title: 'finance.voucher_form.section_general'.tr(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  List<Widget> _receiptPaymentFields() {
    final projectHint = workspaceHint ??
        (projectRequired
            ? 'finance.voucher_form.alloc_hint_required'.tr()
            : 'finance.voucher_form.alloc_hint_optional'.tr());
    return [
      VoucherField(
        label: kind.label('reason_label'),
        required: true,
        child: VoucherSelectField(
          options: reasonOptions,
          value: form.reasonId,
          placeholder: _choose(kind.label('reason_label')),
          sheetTitle: kind.label('reason_label'),
          onChanged: (v) => _set(() => form.reasonId = v),
        ),
      ),
      VoucherField(
        label: kind.label('account_label'),
        required: true,
        child: VoucherSelectField(
          options: accountOptions,
          value: form.accountId,
          placeholder: _choose(kind.label('account_label')),
          sheetTitle: kind.label('account_label'),
          onChanged: (v) => _set(() => form.accountId = v),
        ),
      ),
      VoucherField(
        label: kind.label('counterparty_label'),
        required: true,
        child: VoucherSelectField(
          options: groupOptions,
          value: form.counterpartyGroupId,
          placeholder: _choose(kind.label('counterparty_label')),
          sheetTitle: kind.label('counterparty_label'),
          onChanged: (v) => _set(() => form.counterpartyGroupId = v),
        ),
      ),
      VoucherField(
        label: kind.label('person_label'),
        locked: fromSource('counterpartyName'),
        child: VoucherTextInput(
          initialValue: form.counterpartyName,
          enabled: !fromSource('counterpartyName'),
          maxLength: 255,
          onChanged: (v) => form.counterpartyName = v,
        ),
      ),
      VoucherField(
        label: kind.label('person_account_label'),
        locked: fromSource('counterpartyAccountNo'),
        child: VoucherTextInput(
          initialValue: form.counterpartyAccountNo,
          enabled: !fromSource('counterpartyAccountNo'),
          maxLength: 60,
          onChanged: (v) => form.counterpartyAccountNo = v,
        ),
      ),
      VoucherField(
        label: kind.label('person_bank_label'),
        locked: fromSource('counterpartyBank'),
        child: VoucherTextInput(
          initialValue: form.counterpartyBank,
          enabled: !fromSource('counterpartyBank'),
          maxLength: 120,
          onChanged: (v) => form.counterpartyBank = v,
        ),
      ),
      VoucherField(
        label: 'finance.voucher_form.allocation_label'.tr(),
        required: projectRequired,
        locked: fromSource('allocation'),
        hint: projectHint,
        child: VoucherSelectField(
          enabled: !fromSource('allocation'),
          options: projectOptions,
          value: form.allocProjectId,
          placeholder: projectRequired
              ? 'finance.voucher_form.choose_project'.tr()
              : 'finance.voucher_form.no_allocation'.tr(),
          sheetTitle: 'finance.voucher_form.allocation_label'.tr(),
          searchPlaceholder: 'finance.voucher_form.project_search'.tr(),
          emptyText: workspaceProblem ?? 'finance.voucher_form.no_projects'.tr(),
          fallbackLabel: 'finance.voucher_form.project_missing'.tr(),
          onChanged: (v) => _set(() => form.allocProjectId = v),
        ),
      ),
    ];
  }

  List<Widget> _transferFields() => [
        VoucherField(
          label: 'finance.voucher_form.amount'.tr(),
          required: true,
          child: VoucherMoneyInput(value: form.amount, onChanged: (v) => _set(() => form.amount = v)),
        ),
        VoucherField(
          label: kind.label('account_label'),
          required: true,
          child: VoucherSelectField(
            options: accountOptions,
            value: form.accountId,
            placeholder: 'finance.voucher_form.choose_source_account'.tr(),
            sheetTitle: kind.label('account_label'),
            onChanged: (v) => _set(() => form.accountId = v),
          ),
        ),
        VoucherField(
          label: 'finance.voucher_form.dest_account'.tr(),
          required: true,
          child: VoucherSelectField(
            options: accountOptions.where((o) => o.value != form.accountId).toList(),
            value: form.destAccountId,
            placeholder: 'finance.voucher_form.choose_dest_account'.tr(),
            sheetTitle: 'finance.voucher_form.dest_account'.tr(),
            onChanged: (v) => _set(() => form.destAccountId = v),
          ),
        ),
      ];
}
