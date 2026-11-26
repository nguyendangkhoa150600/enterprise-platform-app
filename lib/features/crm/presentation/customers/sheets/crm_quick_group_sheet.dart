import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/customers/customers_repository.dart';
import '../../../domain/crm_exception.dart';
import '../../../domain/customers/crm_customer_models.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';

/// Tạo nhanh nhóm hoặc phân loại khách ngay trong form khách (web `QuickGroupDialog` / `QuickKindDialog`): mã sinh
/// từ tên, tên trùng (bỏ dấu, hoa thường) thì báo lỗi, không đóng form khách. Trả mã (phân loại) hoặc id (nhóm) vừa
/// tạo kèm tên; null khi đóng.
Future<({String value, String name})?> showCrmQuickGroupSheet(BuildContext context, {required bool kind}) =>
    showCrmSheet<({String value, String name})>(context, builder: (_) => _QuickGroupSheet(kind: kind));

class _QuickGroupSheet extends StatefulWidget {
  final bool kind;
  const _QuickGroupSheet({required this.kind});

  @override
  State<_QuickGroupSheet> createState() => _QuickGroupSheetState();
}

class _QuickGroupSheetState extends State<_QuickGroupSheet> {
  final TextEditingController _name = TextEditingController();
  bool _submitting = false;
  String? _error;

  String get _p => widget.kind ? 'crm.customers.quick_kind' : 'crm.customers.quick_group';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) return setState(() => _error = '$_p.name_required'.tr());
    final code = crmGroupCodeFromName(trimmed);
    if (code.isEmpty) return setState(() => _error = '$_p.name_invalid'.tr());
    final scope = CrmScope.instance;
    final normalized = crmNormalizeGroupName(trimmed);
    final exists = widget.kind
        ? scope.kinds.value.any((k) => crmNormalizeGroupName(k.name) == normalized)
        : scope.groups.value.any((g) => crmNormalizeGroupName(g.name) == normalized);
    if (exists) return setState(() => _error = '$_p.exists'.tr());
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = CrmCustomersRepository.instance;
    try {
      final String value;
      if (widget.kind) {
        value = (await repo.createKind(code: code, name: trimmed)).code;
        scope.reloadKinds();
      } else {
        value = (await repo.createGroup(code: code, name: trimmed)).id;
        scope.reloadGroups();
      }
      if (!mounted) return;
      showCrmSnack(context, '$_p.created'.tr());
      Navigator.of(context).pop((value: value, name: trimmed));
    } catch (e) {
      if (!mounted) return;
      scope.onError(e);
      final duplicateCode = widget.kind ? 'KIND_CODE_EXISTS' : 'GROUP_CODE_EXISTS';
      setState(() {
        _submitting = false;
        _error = e is CrmException && e.code == duplicateCode ? '$_p.exists'.tr() : crmErrorMessage(e, '$_p.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: '$_p.title'.tr(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      children: [
        CrmField(
          label: '$_p.name'.tr(),
          required: true,
          child: TextField(
            controller: _name,
            autofocus: true,
            maxLength: 200,
            decoration: crmInputDecoration().copyWith(counterText: ''),
          ),
        ),
      ],
    );
  }
}
