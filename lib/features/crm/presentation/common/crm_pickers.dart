import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_directory_models.dart';
import '../utils/crm_scope.dart';
import 'crm_select.dart';

/// Tuỳ chọn từ danh bạ (web `peopleOptions`).
List<CrmSelectOption> crmPeopleOptions(List<CrmPerson> people) =>
    people.map((p) => CrmSelectOption(value: p.userId, label: p.displayName)).toList();

/// Tuỳ chọn nhóm khách, mã ở badge (web `groupOptions`).
List<CrmSelectOption> crmGroupOptions(List<CrmCustomerGroup> groups) =>
    groups.map((g) => CrmSelectOption(value: g.id, label: g.name, badge: g.code)).toList();

/// Tuỳ chọn phân loại khách (web `kindOptions`).
List<CrmSelectOption> crmKindOptions(List<CrmCustomerKind> kinds) =>
    kinds.map((k) => CrmSelectOption(value: k.code, label: k.name)).toList();

/// Tuỳ chọn từ bảng nhãn `{ KEY: 'Nhãn' }` (web `labelOptions`); nhãn nên đã dịch.
List<CrmSelectOption> crmLabelOptions(Map<String, String> labels) =>
    labels.entries.map((e) => CrmSelectOption(value: e.key, label: e.value)).toList();

/// Tìm khách hàng trên server cho ô chọn khách (web: không từ khoá `listCustomers({ limit: 100 })`, có từ khoá
/// `listCustomers({ q, limit: 20 })`). [onResults] nhận bản đầy đủ của các dòng (để lấy mã, phân loại…).
Future<List<CrmSelectOption>> Function(String query) crmCustomerSearch({
  void Function(List<CrmCustomerSummary> rows)? onResults,
}) {
  return (query) async {
    final page = await CrmScope.instance.repository.listCustomers(
      CrmCustomerListQuery(q: query.isEmpty ? null : query, limit: query.isEmpty ? 100 : 20),
    );
    onResults?.call(page.items);
    return page.items.map((c) => CrmSelectOption(value: c.id, label: c.name, badge: c.code)).toList();
  };
}

/// Mở sheet chọn khách hàng (tìm trên server). Trả khách đã chọn; `null` khi đóng; khi [clearable] và bấm "Bỏ chọn"
/// trả [CrmSelection] với value null qua [onCleared].
Future<CrmCustomerSummary?> showCrmCustomerPicker(
  BuildContext context, {
  String? selectedId,
  String? title,
  bool clearable = false,
  VoidCallback? onCleared,
}) async {
  final seen = <String, CrmCustomerSummary>{};
  final picked = await showCrmSelectSheet(
    context,
    title: title ?? 'crm.picker.customer_title'.tr(),
    remoteSearch: crmCustomerSearch(
      onResults: (rows) {
        for (final row in rows) {
          seen[row.id] = row;
        }
      },
    ),
    selected: selectedId,
    searchHint: 'crm.picker.customer_search'.tr(),
    emptyText: 'crm.picker.customer_empty'.tr(),
    clearable: clearable,
  );
  if (picked == null) return null;
  if (picked.value == null) {
    onCleared?.call();
    return null;
  }
  return seen[picked.value];
}

/// Ô chọn khách hàng trong biểu mẫu (tìm trên server). [selectedLabel] là tên khách đang chọn (để hiện khi chưa
/// tìm). [onChanged] nhận null khi bỏ chọn.
class CrmCustomerSelectField extends StatelessWidget {
  final String? value;
  final String? selectedLabel;
  final ValueChanged<CrmCustomerSummary?> onChanged;
  final String? placeholder;
  final bool clearable;
  final bool enabled;

  const CrmCustomerSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.selectedLabel,
    this.placeholder,
    this.clearable = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final seen = <String, CrmCustomerSummary>{};
    return CrmSelectField(
      value: value,
      selectedLabel: selectedLabel,
      placeholder: placeholder ?? 'crm.picker.customer_placeholder'.tr(),
      sheetTitle: 'crm.picker.customer_title'.tr(),
      searchHint: 'crm.picker.customer_search'.tr(),
      emptyText: 'crm.picker.customer_empty'.tr(),
      clearable: clearable,
      enabled: enabled,
      remoteSearch: crmCustomerSearch(
        onResults: (rows) {
          for (final row in rows) {
            seen[row.id] = row;
          }
        },
      ),
      onChanged: (selection) => onChanged(selection.value == null ? null : seen[selection.value]),
    );
  }
}

/// Ô chọn người (người phụ trách, người được giao) từ danh bạ CRM ([CrmScope.people]).
class CrmPersonSelectField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? placeholder;
  final bool clearable;
  final bool enabled;

  const CrmPersonSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.clearable = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CrmPerson>>(
      valueListenable: CrmScope.instance.people,
      builder: (context, people, _) => CrmSelectField(
        value: value,
        options: crmPeopleOptions(people),
        selectedLabel: CrmScope.instance.personName(value),
        placeholder: placeholder ?? 'crm.picker.person_placeholder'.tr(),
        searchHint: 'crm.picker.person_search'.tr(),
        clearable: clearable,
        enabled: enabled,
        onChanged: (selection) => onChanged(selection.value),
      ),
    );
  }
}
