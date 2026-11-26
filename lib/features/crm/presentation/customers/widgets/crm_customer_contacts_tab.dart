import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';

/// Tab "Người liên hệ" (web `ContactsTab`): thêm, sửa, đặt làm chính, xoá (quyền ghi).
class CrmCustomerContactsTab extends StatelessWidget {
  final CrmCustomerDetail customer;
  final bool canWrite;
  final ValueChanged<CrmCustomerDetail> onChanged;

  const CrmCustomerContactsTab({super.key, required this.customer, required this.canWrite, required this.onChanged});

  Future<void> _run(BuildContext context, Future<CrmCustomerDetail> Function() operation, String successKey) async {
    try {
      final saved = await operation();
      onChanged(saved);
      if (!context.mounted) return;
      showCrmSnack(context, successKey.tr());
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!context.mounted) return;
      showCrmSnack(context, crmErrorMessage(e, 'crm.customers.contacts.error'), error: true);
    }
  }

  Future<void> _edit(BuildContext context, CrmCustomerContact? contact) async {
    final saved = await showCrmSheet<CrmCustomerDetail>(
      context,
      builder: (_) => _ContactSheet(customer: customer, contact: contact),
    );
    if (saved == null) return;
    onChanged(saved);
    if (!context.mounted) return;
    showCrmSnack(context, 'crm.customers.contacts.saved'.tr());
  }

  Future<void> _delete(BuildContext context, CrmCustomerContact contact) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.customers.contacts.delete_title'.tr(),
      message: contact.isPrimary ? 'crm.customers.contacts.delete_primary_hint'.tr() : null,
      confirmLabel: 'crm.customers.contacts.delete'.tr(),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => CrmCustomersRepository.instance.deleteContact(customer.id, contact.id),
      'crm.customers.contacts.deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = customer.contacts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canWrite)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CrmButton(
              label: 'crm.customers.contacts.add'.tr(),
              icon: Icons.add_rounded,
              onPressed: () => _edit(context, null),
            ),
          ),
        if (contacts.isEmpty)
          CrmStateView(emptyIcon: Icons.contact_phone_outlined, emptyText: 'crm.customers.contacts.empty'.tr())
        else
          for (final contact in contacts) _contactCard(context, contact),
      ],
    );
  }

  Widget _contactCard(BuildContext context, CrmCustomerContact contact) {
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contact.fullName,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
              ),
              if (contact.isPrimary)
                CrmStatusPill(label: 'crm.customers.contacts.primary'.tr(), tone: CrmTone.success, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          CrmInfoRow(label: 'crm.customers.contacts.title_field'.tr(), value: contact.title, labelWidth: 90),
          CrmInfoRow(label: 'crm.customers.contacts.phone'.tr(), value: contact.phone, labelWidth: 90),
          CrmInfoRow(label: 'crm.customers.contacts.email'.tr(), value: contact.email, labelWidth: 90),
          if (canWrite)
            Wrap(
              spacing: 4,
              children: [
                if (!contact.isPrimary)
                  TextButton(
                    onPressed: () => _run(
                      context,
                      () => CrmCustomersRepository.instance.setPrimaryContact(customer.id, contact.id),
                      'crm.customers.contacts.primary_changed',
                    ),
                    child: Text('crm.customers.contacts.set_primary'.tr()),
                  ),
                TextButton(onPressed: () => _edit(context, contact), child: Text('crm.customers.contacts.edit'.tr())),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: CrmColors.danger),
                  onPressed: () => _delete(context, contact),
                  child: Text('crm.customers.contacts.delete'.tr()),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Thêm / sửa người liên hệ (web `ContactDialog`). Người liên hệ đầu tiên luôn là người chính.
class _ContactSheet extends StatefulWidget {
  final CrmCustomerDetail customer;
  final CrmCustomerContact? contact;
  const _ContactSheet({required this.customer, this.contact});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final CrmCustomerContact? _c = widget.contact;
  late final bool _first = widget.customer.contacts.isEmpty;
  late final _fullName = TextEditingController(text: _c?.fullName ?? '');
  late final _title = TextEditingController(text: _c?.title ?? '');
  late final _phone = TextEditingController(text: _c?.phone ?? '');
  late final _email = TextEditingController(text: _c?.email ?? '');
  late final _note = TextEditingController(text: _c?.note ?? '');
  late bool _isPrimary = _c?.isPrimary ?? _first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullName, _title, _phone, _email, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty) {
      return setState(() => _error = 'crm.customers.contacts.name_required'.tr());
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final body = {
      'fullName': _fullName.text.trim(),
      'title': _text(_title),
      'phone': _text(_phone),
      'email': _text(_email),
      'note': _text(_note),
      'isPrimary': _isPrimary,
    };
    final repo = CrmCustomersRepository.instance;
    try {
      final c = _c;
      final saved = c == null
          ? await repo.addContact(widget.customer.id, body)
          : await repo.updateContact(widget.customer.id, c.id, body);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      CrmScope.instance.onError(e);
      setState(() {
        _submitting = false;
        _error = crmErrorMessage(e, 'crm.customers.contacts.error');
      });
    }
  }

  Widget _input(
    String key,
    TextEditingController ctrl,
    int max, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) => CrmField(
    label: key.tr(),
    required: required,
    child: TextField(
      controller: ctrl,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: keyboard,
      decoration: crmInputDecoration().copyWith(counterText: ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lockPrimary = (_c?.isPrimary ?? false) || _first;
    return CrmFormSheet(
      title: (_c == null ? 'crm.customers.contacts.add' : 'crm.customers.contacts.edit_title').tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        _input('crm.customers.contacts.full_name', _fullName, 200, required: true),
        _input('crm.customers.contacts.title_field', _title, 200),
        _input('crm.customers.contacts.phone', _phone, 50, keyboard: TextInputType.phone),
        _input('crm.customers.contacts.email', _email, 200, keyboard: TextInputType.emailAddress),
        _input('crm.customers.contacts.note', _note, 1000, lines: 2),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _isPrimary,
          onChanged: lockPrimary ? null : (v) => setState(() => _isPrimary = v ?? false),
          title: Text('crm.customers.contacts.primary'.tr(), style: const TextStyle(fontSize: 13.5)),
          subtitle: _first
              ? Text(
                  'crm.customers.contacts.first_hint'.tr(),
                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                )
              : null,
        ),
      ],
    );
  }
}
