import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import '../../../../../models/workspace_models.dart';
import '../../../../../utils/user_resolver.dart';

/// `1.5` → `1,5` (như `formatUnits` của web).
String formatUnits(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');

String _ruleLabel(WorkdayRule rule) {
  if (rule.label.isNotEmpty) return rule.label;
  return switch (rule.kind) {
    'leave' => 'workspace.requests.rule_leave'.tr(),
    'business_trip' => 'workspace.requests.rule_trip'.tr(),
    _ => rule.kind,
  };
}

/// "Thứ tự ưu tiên tính công" (web `PriorityDialog`): quản trị (`canEdit`) kéo thả đổi thứ tự và sửa số công; người khác chỉ xem.
class WorkdayPriorityDialog extends StatefulWidget {
  final WorkdayRuleSet? rules;
  final WorkspaceRequestsApi api;
  final ValueChanged<WorkdayRuleSet> onSaved;

  const WorkdayPriorityDialog({super.key, required this.rules, required this.api, required this.onSaved});

  @override
  State<WorkdayPriorityDialog> createState() => _WorkdayPriorityDialogState();
}

class _WorkdayPriorityDialogState extends State<WorkdayPriorityDialog> {
  late final WorkdayRuleSet _source = widget.rules ?? WorkdayRuleSet.defaults;
  late final bool _editable = widget.rules?.canEdit ?? false;
  late final List<WorkdayRule> _order = [..._source.rules];
  late final Map<String, TextEditingController> _units = {
    for (final r in _source.rules) r.kind: TextEditingController(text: formatUnits(r.units)),
  };
  late final TextEditingController _normal = TextEditingController(text: formatUnits(_source.normalUnits));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _units.values) {
      c.dispose();
    }
    _normal.dispose();
    super.dispose();
  }

  double _parse(String value) => double.tryParse(value.trim().replaceAll(',', '.')) ?? double.nan;

  Future<void> _save() async {
    if (!_editable) {
      Navigator.of(context).pop();
      return;
    }
    final units = {for (final r in _order) r.kind: _parse(_units[r.kind]!.text)};
    final normal = _parse(_normal.text);
    if ([...units.values, normal].any((v) => !v.isFinite || v < 0 || v > 10)) {
      setState(() => _error = 'workspace.requests.priority_err_units'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.api.updateWorkdayRules(
      order: _order.map((r) => r.kind).toList(),
      units: units,
      normalUnits: normal,
    );
    if (!mounted) return;
    if (result.ok && result.data != null) {
      widget.onSaved(result.data!);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = result.error ?? 'workspace.requests.priority_err_save'.tr();
    });
  }

  Widget _unitsCell(TextEditingController controller, double value) => SizedBox(
        width: 64,
        child: _editable
            ? TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              )
            : Text(formatUnits(value), textAlign: TextAlign.center),
      );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text('workspace.requests.priority_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_editable ? 'workspace.requests.priority_sub_edit' : 'workspace.requests.priority_sub_view').tr(),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  if (!_editable) return;
                  setState(() {
                    final picked = _order.removeAt(from);
                    _order.insert(to > from ? to - 1 : to, picked);
                  });
                },
                children: [
                  for (var i = 0; i < _order.length; i++)
                    ListTile(
                      key: ValueKey(_order[i].kind),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _editable
                          ? ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, size: 18))
                          : null,
                      title: Text('${i + 1}. ${_ruleLabel(_order[i])}'),
                      trailing: _unitsCell(_units[_order[i].kind]!, _order[i].units),
                    ),
                ],
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: _editable ? const SizedBox(width: 18) : null,
                title: Text('— ${'workspace.requests.priority_normal'.tr()}'),
                trailing: _unitsCell(_normal, _source.normalUnits),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('workspace.requests.priority_units_col'.tr(), style: TextStyle(fontSize: 11, color: muted)),
              ),
              const SizedBox(height: 8),
              Text(
                '${'workspace.requests.priority_note'.tr()}${_editable ? '' : ' ${'workspace.requests.priority_admin_only'.tr()}'}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_editable)
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text('common.cancel'.tr())),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text((_editable ? 'workspace.requests.priority_save' : 'workspace.requests.priority_ok').tr()),
        ),
      ],
    );
  }
}

class _MemberWorkdays {
  final String name;
  final int tripDays;
  final int overriddenTripDays;
  final double total;
  const _MemberWorkdays(this.name, this.tripDays, this.overriddenTripDays, this.total);
}

/// Port `computeMonthlyWorkdays`: mỗi ngày chỉ một đơn đã duyệt "thắng" theo rank.
List<_MemberWorkdays> _computeMonthly(
  List<({String userId, String name})> members,
  List<ProjectRequestItem> requests,
  DateTime month,
  WorkdayRuleSet config,
) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  String two(int n) => n.toString().padLeft(2, '0');
  final days = [for (var d = 1; d <= daysInMonth; d++) '${month.year}-${two(month.month)}-${two(d)}'];
  final ruleOf = {for (final r in config.rules) r.kind: r};
  return members.map((m) {
    final own = requests
        .where((r) => r.requesterUserId == m.userId && r.status == 'APPROVED' && ruleOf.containsKey(r.sourceKind))
        .toList();
    var trip = 0;
    var overridden = 0;
    var total = 0.0;
    for (final day in days) {
      final matched = own
          .where((r) {
            final from = r.fromDate;
            final to = r.toDate ?? r.fromDate;
            return from != null && to != null && from.compareTo(day) <= 0 && day.compareTo(to) <= 0;
          })
          .map((r) => ruleOf[r.sourceKind]!)
          .toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
      final hasTrip = matched.any((r) => r.kind == 'business_trip');
      final winner = matched.firstOrNull;
      if (hasTrip && winner?.kind == 'business_trip') {
        trip++;
      } else if (hasTrip) {
        overridden++;
      }
      total += winner?.units ?? config.normalUnits;
    }
    return _MemberWorkdays(m.name, trip, overridden, (total * 100).round() / 100);
  }).toList();
}

/// "Báo cáo công tác" theo tháng (web `WorkdayReportDrawer`), không có nút xuất CSV trên mobile.
class WorkdayReportSheet extends StatefulWidget {
  final Future<List<ProjectMemberItem>> Function() loadMembers;
  final List<ProjectRequestItem> requests;
  final WorkdayRuleSet rules;

  const WorkdayReportSheet({super.key, required this.loadMembers, required this.requests, required this.rules});

  @override
  State<WorkdayReportSheet> createState() => _WorkdayReportSheetState();
}

class _WorkdayReportSheetState extends State<WorkdayReportSheet> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<String>? _memberIds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<String> ids;
    try {
      ids = (await widget.loadMembers()).map((m) => m.userId).toList();
    } catch (_) {
      ids = const [];
    }
    if (!mounted) return;
    setState(() => _memberIds = ids);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final memberIds = _memberIds;
    List<_MemberWorkdays> rows = const [];
    if (memberIds != null) {
      // Người gửi đơn nhưng đã rời dự án vẫn có mặt trong báo cáo.
      final ids = {...memberIds, ...widget.requests.map((r) => r.requesterUserId)};
      final members = ids.map((id) {
        final named = widget.requests.where((r) => r.requesterUserId == id && (r.requesterName ?? '').isNotEmpty).firstOrNull;
        return (userId: id, name: named?.requesterName ?? UserResolver.resolve(id));
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      rows = _computeMonthly(members, widget.requests, _month, widget.rules);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('workspace.requests.report_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('workspace.requests.report_subtitle'.tr(), style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('workspace.requests.report_month'.tr(), style: TextStyle(fontSize: 12, color: muted)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Text('${_month.month.toString().padLeft(2, '0')}/${_month.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 12,
                  horizontalMargin: 0,
                  columns: [
                    DataColumn(label: Text('workspace.requests.report_member'.tr())),
                    DataColumn(label: Text('workspace.requests.report_trip_days'.tr()), numeric: true),
                    DataColumn(label: Text('workspace.requests.report_overridden'.tr()), numeric: true),
                    DataColumn(label: Text('workspace.requests.report_total'.tr()), numeric: true),
                  ],
                  rows: memberIds == null
                      ? [
                          DataRow(cells: [
                            DataCell(Text('workspace.requests.loading'.tr())),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                          ]),
                        ]
                      : [
                          for (final r in rows)
                            DataRow(cells: [
                              DataCell(Text(r.name)),
                              DataCell(Text('${r.tripDays}')),
                              DataCell(Text('${r.overriddenTripDays}')),
                              DataCell(Text(formatUnits(r.total))),
                            ]),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('workspace.requests.report_note'.tr(), style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
    );
  }
}
