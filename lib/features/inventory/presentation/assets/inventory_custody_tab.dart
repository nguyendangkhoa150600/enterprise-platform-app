import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../screens/inventory/components/inventory_custody_assign_dialog.dart';
import '../../../../screens/inventory/components/inventory_custody_declare_dialog.dart';
import '../../../../theme/colors.dart';
import '../../data/assets/inventory_asset_repository.dart';
import '../../domain/assets/inventory_asset_models.dart';
import '../../domain/inventory_capabilities.dart';
import '../utils/inventory_scope.dart';
import 'inventory_asset_ui.dart';

/// Sổ tài sản — tab "Tài sản" (web `CustodyPanel`): mọi tài sản kèm tình trạng đang sử dụng / bảo trì / tồn kho,
/// khai báo tài sản mới và cấp phát cho nhân viên.
class InventoryCustodyTab extends StatefulWidget {
  /// Báo số tài sản cho tiêu đề tab.
  final ValueChanged<int>? onCount;
  const InventoryCustodyTab({super.key, this.onCount});

  @override
  State<InventoryCustodyTab> createState() => InventoryCustodyTabState();
}

enum _Filter { all, inUse, maintenance, inStock }

class InventoryCustodyTabState extends State<InventoryCustodyTab> with AutomaticKeepAliveClientMixin {
  final _repo = InventoryAssetRepository.instance;
  List<InvMaterial> _assets = [];
  List<InvEmployeeOption> _employees = [];
  bool _loading = true;
  String? _loadError;
  _Filter _filter = _Filter.all;
  final _search = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repo.loadEmployees().then((list) {
      if (mounted) setState(() => _employees = list);
    }).catchError((_) {});
    reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final list = await _repo.loadCustodyAssets();
      if (!mounted) return;
      setState(() {
        _assets = list;
        _loadError = null;
        _loading = false;
      });
      widget.onCount?.call(list.length);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'inventory.assets.custody_load_error'.tr();
      });
    }
  }

  InvCustodyState? _stateOf(_Filter f) => switch (f) {
        _Filter.all => null,
        _Filter.inUse => InvCustodyState.inUse,
        _Filter.maintenance => InvCustodyState.maintenance,
        _Filter.inStock => InvCustodyState.inStock,
      };

  InvEmployeeOption? _owner(String? id) {
    if (id == null) return null;
    for (final e in _employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _openAssign([String? code]) async {
    await invShowSheet<bool>(
      context,
      InventoryCustodyAssignDialog(
        assets: _assets.where((a) => invCustodyStateOf(a) == InvCustodyState.inStock).toList(),
        employees: _employees,
        initialCode: code,
        onSubmit: (asset, employeeId) async {
          try {
            await _repo.assignCustody(asset.code, employeeId);
          } finally {
            await reload();
          }
          if (mounted) invToast(context, 'inventory.assets.assigned_toast'.tr(args: {'code': asset.code}));
        },
      ),
    );
  }

  Future<void> _openDeclare() async {
    await invShowSheet<bool>(
      context,
      InventoryCustodyDeclareDialog(
        onSubmit: (input) async {
          String code;
          try {
            code = await _repo.createAsset(input);
          } finally {
            await reload();
          }
          if (mounted) invToast(context, 'inventory.assets.declared_toast'.tr(args: {'code': code}));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final counts = <_Filter, int>{
      _Filter.all: _assets.length,
      for (final f in [_Filter.inUse, _Filter.maintenance, _Filter.inStock])
        f: _assets.where((a) => invCustodyStateOf(a) == _stateOf(f)).length,
    };
    final term = _search.text.trim().toLowerCase();
    final rows = _assets.where((a) {
      final st = _stateOf(_filter);
      if (st != null && invCustodyStateOf(a) != st) return false;
      if (term.isEmpty) return true;
      final owner = _owner(a.assignedEmployeeId);
      return [a.code, a.name, a.serialNumber, owner?.name, owner?.code].any((v) => v?.toLowerCase().contains(term) ?? false);
    }).toList();
    final labels = {
      _Filter.all: 'inventory.assets.filter_all'.tr(),
      _Filter.inUse: invCustodyStateLabel(InvCustodyState.inUse),
      _Filter.maintenance: invCustodyStateLabel(InvCustodyState.maintenance),
      _Filter.inStock: invCustodyStateLabel(InvCustodyState.inStock),
    };

    return ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) => RefreshIndicator(
        onRefresh: reload,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  if (caps.canManage) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: invOutlineStyle(),
                            onPressed: _openDeclare,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('inventory.assets.declare_title'.tr()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: invPrimaryStyle(),
                            onPressed: () => _openAssign(),
                            icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                            label: Text('inventory.assets.assign'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _search,
                    decoration: invInputDecoration(
                      hint: 'inventory.assets.custody_search'.tr(),
                      prefix: const Icon(Icons.search, size: 18, color: AppColors.slate500),
                      suffix: _search.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(_search.clear))
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _Filter.values.map((f) {
                        final sel = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${labels[f]} (${counts[f]})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                  color: sel ? Colors.white : AppColors.slate600,
                                )),
                            selected: sel,
                            showCheckmark: false,
                            selectedColor: const Color(0xFF1D4ED8),
                            backgroundColor: AppColors.slate100,
                            side: BorderSide(color: sel ? const Color(0xFF1D4ED8) : AppColors.slate200),
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.slate200),
            Expanded(
              child: rows.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 60),
                      InvEmptyText(_loadError ??
                          (_assets.isEmpty ? 'inventory.assets.custody_empty'.tr() : 'inventory.assets.custody_no_match'.tr())),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _card(rows[i], caps.canManage),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(InvMaterial a, bool canManage) {
    final state = invCustodyStateOf(a);
    final owner = _owner(a.assignedEmployeeId);
    final ownerText = a.assignedEmployeeId == null
        ? '—'
        : owner != null
            ? '${owner.name}${owner.code != null ? ' (${owner.code})' : ''}'
            : a.assignedEmployeeId!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InvCodeTag(a.code),
              const SizedBox(width: 8),
              Expanded(
                child: Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
              ),
              const SizedBox(width: 8),
              InvPill(invCustodyStateLabel(state), tone: invCustodyTone(state)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'inventory.assets.custody_group'.tr()}: ${invAssetCategoryLabel(a.assetCategory)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                    const SizedBox(height: 2),
                    Text('${'inventory.assets.custody_owner'.tr()}: $ownerText',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate700, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${'inventory.assets.custody_assigned_at'.tr()}: ${invFormatDate(a.assignedAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
              if (canManage && state == InvCustodyState.inStock)
                OutlinedButton.icon(
                  style: invOutlineStyle(color: const Color(0xFF1D4ED8)),
                  icon: const Icon(Icons.assignment_ind_outlined, size: 15),
                  label: Text('inventory.assets.assign'.tr()),
                  onPressed: () => _openAssign(a.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
