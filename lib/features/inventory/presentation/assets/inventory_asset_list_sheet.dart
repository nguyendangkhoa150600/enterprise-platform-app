import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';
import 'inventory_asset_ui.dart';
import 'inventory_bulk_return_sheet.dart';

/// Danh mục thiết bị dạng bảng liệt kê đồng cấp (web `AssetListModal`): tìm, lọc loại/tình trạng/mức độ,
/// sắp xếp, phân trang, chọn nhiều để gỡ hàng loạt. Trả id thiết bị được chọn xem (hoặc `null`).
class InventoryAssetListSheet extends StatefulWidget {
  final InvAssetWorkspace workspace;
  final String? selectedId;

  /// `null` khi không có quyền (ẩn nút gỡ hàng loạt). Ném lỗi để hộp thoại gỡ hiện lý do.
  final Future<void> Function(List<InvBulkReturnEntry> entries)? onBulkReturn;

  const InventoryAssetListSheet({super.key, required this.workspace, this.selectedId, this.onBulkReturn});

  @override
  State<InventoryAssetListSheet> createState() => _InventoryAssetListSheetState();
}

enum _SortField { code, name, type, parent, status, criticality }

class _InventoryAssetListSheetState extends State<InventoryAssetListSheet> {
  final Set<String> _checked = {};
  final _search = TextEditingController();
  String _type = 'all';
  String _status = 'all';
  String _criticality = 'all';
  _SortField _sortField = _SortField.code;
  bool _sortAsc = true;
  int _page = 1;
  int _pageSize = 15;

  List<InvAsset> get _assets => widget.workspace.assets;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, InvAsset> get _byId => {for (final a in _assets) a.id: a};

  List<InvAsset> _filtered() {
    final q = _search.text.trim().toLowerCase();
    final byId = _byId;
    return _assets.where((a) {
      if (_type != 'all' && a.type != _type) return false;
      if (_status != 'all' && a.status != _status) return false;
      if (_criticality != 'all' && a.criticality != _criticality) return false;
      if (q.isEmpty) return true;
      final parent = a.parentId != null ? byId[a.parentId] : null;
      return a.code.toLowerCase().contains(q) ||
          a.name.toLowerCase().contains(q) ||
          (a.serialNumber ?? '').toLowerCase().contains(q) ||
          (a.manufacturer ?? '').toLowerCase().contains(q) ||
          (parent?.name ?? '').toLowerCase().contains(q) ||
          (parent?.code ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<InvAsset> _sorted(List<InvAsset> list) {
    final byId = _byId;
    String parentName(InvAsset a) => a.parentId != null ? byId[a.parentId]?.name ?? '' : '';
    final out = [...list]
      ..sort((a, b) {
        final cmp = switch (_sortField) {
          _SortField.code => invViCompare(a.code, b.code),
          _SortField.name => invViCompare(a.name, b.name),
          _SortField.type => invViCompare(a.type, b.type),
          _SortField.parent => invViCompare(parentName(a), parentName(b)),
          _SortField.status => invViCompare(a.status, b.status),
          _SortField.criticality => invViCompare(a.criticality, b.criticality),
        };
        return _sortAsc ? cmp : -cmp;
      });
    return out;
  }

  bool get _isFiltered => _search.text.trim().isNotEmpty || _type != 'all' || _status != 'all' || _criticality != 'all';

  void _resetFilters() => setState(() {
        _search.clear();
        _type = 'all';
        _status = 'all';
        _criticality = 'all';
        _page = 1;
      });

  String _sortLabel(_SortField f) => switch (f) {
        _SortField.code => 'inventory.assets.col_code'.tr(),
        _SortField.name => 'inventory.assets.col_name'.tr(),
        _SortField.type => 'inventory.assets.col_type'.tr(),
        _SortField.parent => 'inventory.assets.col_parent'.tr(),
        _SortField.status => 'inventory.assets.col_status'.tr(),
        _SortField.criticality => 'inventory.assets.col_criticality'.tr(),
      };

  Future<void> _openBulk() async {
    final checked = _assets.where((a) => _checked.contains(a.id)).toList();
    final done = await invShowSheet<bool>(
      context,
      InventoryBulkReturnSheet(
        assets: checked,
        warehouses: widget.workspace.warehouses,
        onConfirm: widget.onBulkReturn!,
      ),
    );
    if (done == true && mounted) Navigator.pop(context);
  }

  Widget _filterChip(String label, String value, List<InvOption> options, ValueChanged<String> onChanged) {
    final active = value != 'all';
    String current = label;
    for (final o in options) {
      if (o.value == value) current = o.label;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(current,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.slate700)),
        avatar: Icon(Icons.filter_list, size: 14, color: active ? Colors.white : AppColors.slate500),
        backgroundColor: active ? const Color(0xFF1D4ED8) : Colors.white,
        side: BorderSide(color: active ? const Color(0xFF1D4ED8) : AppColors.slate300),
        onPressed: () async {
          final v = await invPickOption(context, title: label, options: options, selected: value);
          if (v != null && mounted) {
            onChanged(v);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted(_filtered());
    final totalPages = sorted.isEmpty ? 1 : (sorted.length / _pageSize).ceil();
    final page = _page.clamp(1, totalPages);
    final start = (page - 1) * _pageSize;
    final paged = sorted.skip(start).take(_pageSize).toList();
    final allChecked = sorted.isNotEmpty && sorted.every((a) => _checked.contains(a.id));
    final someChecked = !allChecked && sorted.any((a) => _checked.contains(a.id));
    final byId = _byId;
    final mq = MediaQuery.of(context);

    final typeOptions = [
      InvOption('all', 'inventory.assets.filter_all_types'.tr()),
      ...kInvAssetTypes.map((t) => InvOption(t, invAssetTypeLabel(t))),
    ];
    final statusOptions = [
      InvOption('all', 'inventory.assets.filter_all_status'.tr()),
      ...kInvAssetStatuses.map((s) => InvOption(s, invAssetStatusLabel(s))),
    ];
    final critOptions = [
      InvOption('all', 'inventory.assets.filter_all_criticality'.tr()),
      ...kInvAssetCriticalities.map((c) => InvOption(c, invAssetCriticalityLabel(c))),
    ];

    return Container(
      height: mq.size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('inventory.assets.list_title'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                      const SizedBox(height: 3),
                      Text('inventory.assets.list_subtitle'.tr(args: {'n': _assets.length}),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: AppColors.slate500), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: invInputDecoration(
                    hint: 'inventory.assets.list_search'.tr(),
                    prefix: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                    suffix: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _search.clear();
                              _page = 1;
                            }),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _page = 1),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('inventory.assets.col_type'.tr(), _type, typeOptions, (v) => setState(() {
                            _type = v;
                            _page = 1;
                          })),
                      _filterChip('inventory.assets.col_status'.tr(), _status, statusOptions, (v) => setState(() {
                            _status = v;
                            _page = 1;
                          })),
                      _filterChip('inventory.assets.col_criticality'.tr(), _criticality, critOptions, (v) => setState(() {
                            _criticality = v;
                            _page = 1;
                          })),
                      if (_isFiltered)
                        TextButton(onPressed: _resetFilters, child: Text('inventory.assets.clear_filters'.tr())),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: allChecked ? true : (someChecked ? null : false),
                      tristate: true,
                      onChanged: sorted.isEmpty
                          ? null
                          : (_) => setState(() {
                                if (allChecked) {
                                  _checked.clear();
                                } else {
                                  _checked
                                    ..clear()
                                    ..addAll(sorted.map((a) => a.id));
                                }
                              }),
                    ),
                    Expanded(
                      child: Text('inventory.assets.select_all'.tr(args: {'n': sorted.length}),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
                    ),
                    PopupMenuButton<_SortField>(
                      tooltip: 'inventory.assets.sort'.tr(),
                      onSelected: (f) => setState(() {
                        if (_sortField == f) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortField = f;
                          _sortAsc = true;
                        }
                      }),
                      itemBuilder: (_) => _SortField.values
                          .map((f) => PopupMenuItem(
                                value: f,
                                child: Text('${_sortLabel(f)}${_sortField == f ? (_sortAsc ? ' ▲' : ' ▼') : ''}'),
                              ))
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text('${_sortLabel(_sortField)} ${_sortAsc ? '▲' : '▼'}',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_checked.isNotEmpty)
            Container(
              color: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('inventory.assets.checked_count'.tr(args: {'n': _checked.length}),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                  ),
                  TextButton(
                    onPressed: () => setState(_checked.clear),
                    child: Text('inventory.assets.uncheck_all'.tr(), style: const TextStyle(fontSize: 12.5)),
                  ),
                  if (widget.onBulkReturn != null)
                    ElevatedButton.icon(
                      style: invPrimaryStyle(color: const Color(0xFFDC2626)),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text('inventory.assets.bulk_remove'.tr(args: {'n': _checked.length})),
                      onPressed: _openBulk,
                    ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: sorted.isEmpty
                ? InvEmptyText(_isFiltered ? 'inventory.assets.list_no_match'.tr() : 'inventory.assets.list_empty'.tr())
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: paged.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final a = paged[i];
                      final parent = a.parentId != null ? byId[a.parentId] : null;
                      final line = widget.workspace.installedFor(a.id);
                      final isSel = a.id == widget.selectedId;
                      final isChecked = _checked.contains(a.id);
                      return _row(a, start + i + 1, parent, line, isSel, isChecked);
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + mq.padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'inventory.assets.paging_info'.tr(args: {
                      'from': sorted.isEmpty ? 0 : start + 1,
                      'to': (start + _pageSize).clamp(0, sorted.length),
                      'total': sorted.length,
                    }) +
                        (_assets.length != sorted.length ? ' ${'inventory.assets.paging_of'.tr(args: {'n': _assets.length})}' : ''),
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                ),
                PopupMenuButton<int>(
                  onSelected: (v) => setState(() {
                    _pageSize = v;
                    _page = 1;
                  }),
                  itemBuilder: (_) => [15, 30, 45, 60]
                      .map((n) => PopupMenuItem(value: n, child: Text('inventory.assets.page_size'.tr(args: {'n': n}))))
                      .toList(),
                  child: Text('inventory.assets.page_size'.tr(args: {'n': _pageSize}),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: page <= 1 ? null : () => setState(() => _page = page - 1),
                ),
                Text('$page / $totalPages', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: page >= totalPages ? null : () => setState(() => _page = page + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(InvAsset a, int stt, InvAsset? parent, InvInstalledMaterial? line, bool isSel, bool isChecked) {
    final statusTone = invAssetStatusTone(a.status);
    return InkWell(
      onTap: () => Navigator.pop(context, a.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFFF0FDF4) : (isSel ? const Color(0xFFEFF6FF) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isChecked ? const Color(0xFF16A34A) : (isSel ? const Color(0xFF2563EB) : AppColors.slate200),
              width: isChecked || isSel ? 4 : 1,
            ),
            top: const BorderSide(color: AppColors.slate200),
            right: const BorderSide(color: AppColors.slate200),
            bottom: const BorderSide(color: AppColors.slate200),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (_) => setState(() {
                if (isChecked) {
                  _checked.remove(a.id);
                } else {
                  _checked.add(a.id);
                }
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$stt.', style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
                      const SizedBox(width: 6),
                      Text(a.code,
                          style: const TextStyle(
                              fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      const Spacer(),
                      InvPill(invAssetStatusLabel(a.status), tone: statusTone),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(a.name,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: isSel ? const Color(0xFF1D4ED8) : AppColors.slate900)),
                  if (a.serialNumber != null)
                    Text(
                      'S/N: ${a.serialNumber}${a.manufacturer != null ? ' · ${'inventory.assets.manufacturer_short'.tr()}: ${a.manufacturer}' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InvPill(invAssetTypeLabel(a.type), tone: InvTone.muted),
                      parent != null
                          ? Text('↳ ${parent.name} (${parent.code})', style: const TextStyle(fontSize: 12, color: AppColors.slate700))
                          : InvPill('inventory.assets.root_node'.tr(), tone: InvTone.success),
                      Text(invAssetCriticalityLabel(a.criticality),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: invCriticalityColor(a.criticality))),
                      if (line != null)
                        InvPill(
                          'inventory.assets.installed_qty'.tr(args: {'n': invFormatQty(line.quantity), 'unit': line.unit ?? ''}),
                          tone: InvTone.success,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: isSel
                  ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF16A34A))
                  : const Icon(Icons.chevron_right, size: 20, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}
