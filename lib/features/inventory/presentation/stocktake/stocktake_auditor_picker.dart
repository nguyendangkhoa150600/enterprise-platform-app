import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/stocktake/stocktake_models.dart';
import 'stocktake_ui.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'NV';
  if (parts.length == 1) {
    final p = parts.first;
    return (p.length > 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Chọn thành viên tổ kiểm kê (web `AuditorPicker` trong create-stocktake-dialog).
class StocktakeAuditorPicker extends StatefulWidget {
  final List<InvAuditorCandidate> candidates;
  final List<String> selectedNames;
  final String leadAuditorName;
  final ValueChanged<String> onToggleName;
  final ValueChanged<String> onAddCustomName;

  const StocktakeAuditorPicker({
    super.key,
    required this.candidates,
    required this.selectedNames,
    required this.leadAuditorName,
    required this.onToggleName,
    required this.onAddCustomName,
  });

  @override
  State<StocktakeAuditorPicker> createState() => _StocktakeAuditorPickerState();
}

class _StocktakeAuditorPickerState extends State<StocktakeAuditorPicker> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String v) {
    _queryCtrl.text = v;
    setState(() => _query = v);
  }

  bool get _hasExactMatch {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return widget.candidates.any((c) => c.name.toLowerCase() == q) ||
        widget.selectedNames.any((n) => n.toLowerCase() == q);
  }

  @override
  Widget build(BuildContext context) {
    final wh = <InvAuditorCandidate>[];
    final ext = <InvAuditorCandidate>[];
    for (final c in widget.candidates) {
      if (!c.matches(_query)) continue;
      (c.hasWarehouseAccess ? wh : ext).add(c);
    }
    final visible = wh.length + ext.length;
    final q = _query.trim();
    final selected = widget.selectedNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.groups_outlined, size: 17, color: StocktakeUi.blue600),
          const SizedBox(width: 6),
          Expanded(
            child: Text('inventory.stocktake.auditors_title'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          selected.isNotEmpty
              ? 'inventory.stocktake.auditors_selected'.tr(args: {'n': selected.length})
              : 'inventory.stocktake.auditors_optional'.tr(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
            color: selected.isNotEmpty ? StocktakeUi.blue600 : AppColors.slate400,
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected.map((name) {
              final cand = widget.candidates.where((c) => c.name == name).firstOrNull;
              return InputChip(
                visualDensity: VisualDensity.compact,
                backgroundColor: StocktakeUi.blue50,
                side: const BorderSide(color: StocktakeUi.blue200),
                avatar: CircleAvatar(
                  backgroundColor: StocktakeUi.blue600,
                  child: Text(_initials(name),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF))),
                  ),
                  if (cand?.hasWarehouseAccess == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF16A34A)),
                  ],
                ]),
                deleteIcon: const Icon(Icons.close, size: 14),
                deleteButtonTooltipMessage: 'inventory.stocktake.auditor_remove'.tr(args: {'name': name}),
                onDeleted: () => widget.onToggleName(name),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _queryCtrl,
          style: const TextStyle(fontSize: 13),
          textInputAction: TextInputAction.done,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (_) {
            if (q.isEmpty) return;
            final match = [...wh, ...ext].where((c) => c.name != widget.leadAuditorName).firstOrNull;
            if (match != null) {
              widget.onToggleName(match.name);
            } else if (!_hasExactMatch) {
              widget.onAddCustomName(q);
              _setQuery('');
            }
          },
          decoration: StocktakeUi.input(
            hint: 'inventory.stocktake.auditors_search'.tr(),
            prefix: const Icon(Icons.search, size: 18, color: AppColors.slate400),
          ).copyWith(
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'inventory.stocktake.clear_search'.tr(),
                    icon: const Icon(Icons.cancel, size: 18, color: AppColors.slate400),
                    onPressed: () => _setQuery(''),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              if (visible == 0 && q.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.candidates.isEmpty
                        ? 'inventory.stocktake.no_warehouse_staff'.tr()
                        : 'inventory.stocktake.auditors_none'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate400),
                  ),
                ),
              if (visible == 0 && q.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('inventory.stocktake.auditors_not_found'.tr(args: {'q': _query}),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
                ),
              if (wh.isNotEmpty) ...[
                _groupHeader(Icons.verified_user_outlined, const Color(0xFF16A34A),
                    'inventory.stocktake.auditors_group_wh'.tr(), wh.length),
                ...wh.map(_row),
              ],
              if (ext.isNotEmpty) ...[
                _groupHeader(Icons.groups_outlined, AppColors.slate500, 'inventory.stocktake.auditors_group_ext'.tr(),
                    ext.length),
                ...ext.map(_row),
              ],
              if (q.isNotEmpty && !_hasExactMatch)
                InkWell(
                  onTap: () {
                    widget.onAddCustomName(q);
                    _setQuery('');
                  },
                  child: Container(
                    color: const Color(0xFFF0FDF4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('inventory.stocktake.auditors_add_custom'.tr(args: {'name': q}),
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupHeader(IconData icon, Color color, String title, int n) => Container(
        color: AppColors.slate50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate700)),
          ),
          Text('inventory.stocktake.auditors_group_count'.tr(args: {'n': n}),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        ]),
      );

  Widget _row(InvAuditorCandidate c) {
    final isLead = c.name == widget.leadAuditorName;
    final isSel = widget.selectedNames.contains(c.name);
    final sub = [
      c.position,
      c.department,
      c.hasWarehouseAccess ? 'inventory.stocktake.auditor_wh_duty'.tr() : 'inventory.stocktake.auditor_outside'.tr(),
    ].where((e) => e != null && e.isNotEmpty).join(' • ');
    return InkWell(
      onTap: isLead ? null : () => widget.onToggleName(c.name),
      child: Container(
        color: isLead ? AppColors.slate50 : (isSel ? const Color(0x0D2563EB) : null),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(
            isLead
                ? Icons.how_to_reg_outlined
                : (isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
            size: 20,
            color: isLead ? StocktakeUi.blue700 : (isSel ? StocktakeUi.blue600 : AppColors.slate300),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 15,
            backgroundColor: StocktakeUi.indigo100,
            child: Text(_initials(c.name),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: StocktakeUi.indigo800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 5, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(c.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                if (c.code != null)
                  Text('(${c.code})', style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
                if (isLead)
                  StocktakeUi.tag('inventory.stocktake.auditor_lead_badge'.tr(), StocktakeUi.blue50, StocktakeUi.blue700),
                if (c.hasWarehouseAccess)
                  StocktakeUi.tag('inventory.stocktake.auditor_has_access'.tr(), const Color(0xFFF0FDF4),
                      const Color(0xFF166534)),
              ]),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            ]),
          ),
        ]),
      ),
    );
  }
}
