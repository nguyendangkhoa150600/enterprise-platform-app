import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/common/crm_directory_models.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_format.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';

/// Tab "Thông tin" của hồ sơ khách (web `tab === 'info'` + `ProfileNotePanel`).
class CrmCustomerInfoTab extends StatelessWidget {
  final CrmCustomerDetail customer;
  final bool canWrite;
  final ValueChanged<CrmCustomerDetail> onSaved;

  const CrmCustomerInfoTab({super.key, required this.customer, required this.canWrite, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    String join(List<String?> parts) => parts.where((p) => p != null && p.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmCard(
          child: ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: CrmScope.instance.people,
            builder: (context, _, _) => Column(
              children: [
                CrmInfoRow(label: 'crm.customers.info.tax_code'.tr(), value: c.taxCode),
                CrmInfoRow(label: 'crm.customers.info.group'.tr(), value: c.groupName),
                CrmInfoRow(label: 'crm.customers.info.owner'.tr(), value: CrmScope.instance.personName(c.ownerUserId)),
                CrmInfoRow(label: 'crm.customers.info.address'.tr(), value: c.address),
                CrmInfoRow(label: 'crm.customers.info.province_region'.tr(), value: join([c.province, c.region])),
                CrmInfoRow(label: 'crm.customers.info.industry'.tr(), value: c.industry),
                CrmInfoRow(label: 'crm.customers.info.phone_email'.tr(), value: join([c.phone, c.email])),
                CrmInfoRow(label: 'crm.customers.info.credit_limit'.tr(), value: formatCrmMoney(c.creditLimit)),
                CrmInfoRow(
                  label: 'crm.customers.info.payment_term'.tr(),
                  value: c.paymentTermDays == null
                      ? ''
                      : 'crm.customers.info.days'.tr(args: {'days': c.paymentTermDays}),
                ),
                CrmInfoRow(label: 'crm.customers.info.note'.tr(), value: c.note),
                CrmInfoRow(label: 'crm.customers.info.created_at'.tr(), value: formatCrmDay(c.createdAt)),
              ],
            ),
          ),
        ),
        CrmCard(
          title: 'crm.customers.profile.title'.tr(),
          trailing: canWrite
              ? TextButton(
                  onPressed: () async {
                    final saved = await showCrmSheet<CrmCustomerDetail>(
                      context,
                      builder: (_) => _ProfileNoteSheet(customer: c),
                    );
                    if (saved != null) onSaved(saved);
                  },
                  child: Text('crm.customers.profile.edit'.tr()),
                )
              : null,
          child: Text(
            c.profileNote ?? 'crm.customers.profile.empty'.tr(),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: c.profileNote == null ? CrmColors.muted : CrmColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sửa "Chân dung khách hàng" (web `ProfileNotePanel` dialog): rỗng là xoá; tối đa 4000 ký tự.
class _ProfileNoteSheet extends StatefulWidget {
  final CrmCustomerDetail customer;
  const _ProfileNoteSheet({required this.customer});

  @override
  State<_ProfileNoteSheet> createState() => _ProfileNoteSheetState();
}

class _ProfileNoteSheetState extends State<_ProfileNoteSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.customer.profileNote ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Web `parseNoteInput`: rỗng là xoá (null); quá độ dài thì báo lỗi.
    final value = _text.text.trim();
    if (value.length > kCrmCustomerProfileNoteMax) {
      return setState(() => _error = 'crm.customers.profile.too_long'.tr(args: {'max': kCrmCustomerProfileNoteMax}));
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saved = await CrmCustomersRepository.instance.saveProfile(
        widget.customer.id,
        profileNote: value.isEmpty ? null : value,
        version: widget.customer.version,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.customers.profile.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.customers.profile.title'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: 'crm.customers.profile.field'.tr(),
          hint: 'crm.customers.profile.hint'.tr(args: {'max': kCrmCustomerProfileNoteMax}),
          child: TextField(
            controller: _text,
            minLines: 8,
            maxLines: 14,
            maxLength: kCrmCustomerProfileNoteMax,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
      ],
    );
  }
}
