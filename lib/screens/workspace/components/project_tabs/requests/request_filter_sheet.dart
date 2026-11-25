import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import 'request_filter.dart';

/// Bảng "Bộ lọc đơn từ" (bottom sheet thay panel thả xuống của web). Đổi là áp dụng ngay như web.
Future<void> showRequestFilterSheet(
  BuildContext context, {
  required List<ProjectRequestItem> items,
  required RequestFilter filter,
  required RequestSort sort,
  required void Function(RequestFilter filter, RequestSort sort) onChanged,
}) {
  var current = filter;
  var currentSort = sort;

  final types = items.map((e) => e.requestTypeLabel).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final people = <String, String>{};
  for (final item in items) {
    people[item.requesterUserId] = requesterNameOf(item);
  }
  final personEntries = people.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheet) {
        void update(RequestFilter f, RequestSort s) {
          setSheet(() {
            current = f;
            currentSort = s;
          });
          onChanged(f, s);
        }

        Widget field(String label, String value, Map<String, String> options, ValueChanged<String> pick) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: ValueKey('$label:$value'),
                initialValue: options.containsKey(value) ? value : options.keys.first,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
                items: [
                  for (final e in options.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => v == null ? null : pick(v),
              ),
            );

        final all = 'common.all'.tr();
        final dirty = current.facets > 0 || !currentSort.isDefault;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('workspace.requests.filter_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  field('workspace.requests.f_status'.tr(), current.status, {
                    'all': all,
                    for (final s in projectRequestStatuses) s: requestStatusLabel(s),
                  }, (v) => update(current.copyWith(status: v), currentSort)),
                  field('workspace.requests.f_type'.tr(), current.type, {
                    'all': all,
                    for (final t in types) t: t,
                  }, (v) => update(current.copyWith(type: v), currentSort)),
                  field('workspace.requests.f_person'.tr(), current.person, {
                    'all': all,
                    'me': 'workspace.requests.person_me'.tr(),
                    for (final e in personEntries) e.key: e.value,
                  }, (v) => update(current.copyWith(person: v), currentSort)),
                  field('workspace.requests.f_source'.tr(), current.source, {
                    for (final e in requestSourceKeys.entries) e.key: e.value.tr(),
                  }, (v) => update(current.copyWith(source: v), currentSort)),
                  field('workspace.requests.f_period'.tr(), current.period, {
                    for (final e in requestPeriodKeys.entries) e.key: e.value.tr(),
                  }, (v) => update(current.copyWith(period: v), currentSort)),
                  field('workspace.requests.f_sort'.tr(), currentSort.field, {
                    for (final e in requestSortKeys.entries) e.key: e.value.tr(),
                  }, (v) => update(current, RequestSort(field: v, ascending: currentSort.ascending))),
                  field('workspace.requests.f_direction'.tr(), currentSort.ascending ? 'asc' : 'desc', {
                    'desc': 'workspace.requests.dir_desc'.tr(),
                    'asc': 'workspace.requests.dir_asc'.tr(),
                  }, (v) => update(current, RequestSort(field: currentSort.field, ascending: v == 'asc'))),
                  if (dirty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => update(RequestFilter.none, RequestSort.initial),
                        child: Text('workspace.requests.clear_filter'.tr()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
