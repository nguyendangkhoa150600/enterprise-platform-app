import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/stocktake/stocktake_repository.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/domain/stocktake/stocktake_models.dart';
import '../../../features/inventory/presentation/stocktake/create_stocktake_sheet.dart';
import '../../../features/inventory/presentation/stocktake/stocktake_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../models/inventory_models.dart';
import '../../../theme/colors.dart';
import 'stocktake_detail_sheet.dart';

/// Tab "Lịch sử kiểm đếm" của trang Kho hàng (danh sách đợt của web `stocktake-hub.tsx`).
///
/// Tự nạp đợt từ `GET /stocktakes?limit=200` (đủ trường như web). Các tham số cũ được giữ để
/// màn cha không phải đổi; [onRefresh] vẫn được gọi khi kéo làm mới để màn cha đồng bộ.
class InventoryStocktakesView extends StatefulWidget {
  final List<StocktakeSession> stocktakes;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const InventoryStocktakesView({
    super.key,
    required this.stocktakes,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<InventoryStocktakesView> createState() => _InventoryStocktakesViewState();
}

class _InventoryStocktakesViewState extends State<InventoryStocktakesView> {
  final _repo = StocktakeRepository.instance;

  List<InvStocktakeSession> _sessions = [];
  List<InvStocktakeWarehouse> _warehouses = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _statusFilter = 'all';
  String _warehouseFilter = 'all';

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _sessions.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _repo.loadStocktakes(),
        _repo.loadWarehouses().catchError((Object _) => <InvStocktakeWarehouse>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<InvStocktakeSession>;
        _warehouses = results[1] as List<InvStocktakeWarehouse>;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _load(),
      InventoryScope.instance.ensureCapabilities(force: true),
      widget.onRefresh().catchError((Object _) {}),
    ]);
  }

  void _replaceSession(InvStocktakeSession s) {
    if (!mounted) return;
    setState(() {
      final i = _sessions.indexWhere((x) => x.id == s.id);
      if (i >= 0) {
        _sessions[i] = s;
      } else {
        _sessions.insert(0, s);
      }
    });
  }

  Future<void> _openDetail(InvStocktakeSession s) async {
    await StocktakeDetailSheet.show(context, session: s, onSessionUpdated: _replaceSession);
  }

  Future<void> _create() async {
    final created = await CreateStocktakeSheet.show(context, warehouses: _warehouses);
    if (created == null || !mounted) return;
    StocktakeUi.notice(context, 'inventory.stocktake.notice_created'.tr(args: {'code': created.code}));
    await _load();
    if (!mounted) return;
    final fresh = _sessions.where((x) => x.id == created.id).firstOrNull ?? created;
    await _openDetail(fresh);
  }

  List<InvStocktakeSession> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _sessions.where((s) {
      if (_statusFilter != 'all' && s.status != _statusFilter) return false;
      if (_warehouseFilter != 'all' && s.warehouseCode != _warehouseFilter) return false;
      if (q.isNotEmpty && !s.code.toLowerCase().contains(q) && !s.title.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickWarehouseFilter() async {
    final v = await showStocktakePicker(
      context,
      title: 'inventory.stocktake.filter_warehouse'.tr(),
      selected: _warehouseFilter,
      options: [
        StocktakePickOption('all', 'inventory.stocktake.filter_all_warehouses'.tr()),
        ..._warehouses.map((w) => StocktakePickOption(w.code, w.code)),
      ],
    );
    if (!mounted || v == null) return;
    setState(() => _warehouseFilter = v);
  }

  Future<void> _pickStatusFilter() async {
    final v = await showStocktakePicker(
      context,
      title: 'inventory.stocktake.filter_status'.tr(),
      selected: _statusFilter,
      options: [
        StocktakePickOption('all', 'inventory.stocktake.filter_all_statuses'.tr()),
        ...StocktakeStatuses.all.map((st) => StocktakePickOption(st, StocktakeUi.statusLabel(st))),
      ],
    );
    if (!mounted || v == null) return;
    setState(() => _statusFilter = v);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) {
        final filtered = _filtered;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildToolbar(caps),
              const SizedBox(height: 10),
              _buildFilters(),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else if (filtered.isEmpty)
                _buildEmpty()
              else
                ...filtered.map(_buildSessionCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: StocktakeUi.blue50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Text('inventory.stocktake.hub_badge'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StocktakeUi.blue600)),
          ),
          const SizedBox(height: 6),
          Text('inventory.stocktake.hub_title'.tr(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          const SizedBox(height: 3),
          Text('inventory.stocktake.hub_desc'.tr(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500, height: 1.4)),
        ],
      );

  Widget _buildToolbar(InventoryCapabilities caps) => Row(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: StocktakeUi.blue600,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: caps.canCreateStocktake ? _create : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text('inventory.stocktake.create_button'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: StocktakeUi.input(
                hint: 'inventory.stocktake.list_search'.tr(),
                prefix: const Icon(Icons.search, size: 18, color: AppColors.slate400),
              ),
            ),
          ),
        ],
      );

  Widget _buildFilters() {
    final whText = _warehouseFilter == 'all' ? 'inventory.stocktake.filter_all_warehouses'.tr() : _warehouseFilter;
    final stText =
        _statusFilter == 'all' ? 'inventory.stocktake.filter_all_statuses'.tr() : StocktakeUi.statusLabel(_statusFilter);
    return Row(children: [
      Expanded(child: StocktakeSelectField(text: whText, onTap: _pickWarehouseFilter)),
      const SizedBox(width: 8),
      Expanded(child: StocktakeSelectField(text: stText, onTap: _pickStatusFilter)),
    ]);
  }

  Widget _buildSessionCard(InvStocktakeSession s) {
    final meta = '${s.warehouseCode}${s.stocktakeDate != null ? ' · ${s.stocktakeDate}' : ''}';
    final progress = s.totalItems > 0
        ? 'inventory.stocktake.card_counted'.tr(args: {'counted': s.countedItems, 'total': s.totalItems})
        : 'inventory.stocktake.card_no_snapshot'.tr();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetail(s),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(s.code,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate900)),
                  ),
                  StocktakeUi.statusBadge(s.status),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate400),
                ]),
                const SizedBox(height: 6),
                Text(s.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800, height: 1.3)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.slate500))),
                  Text(progress, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                ]),
                if (s.differenceItems > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: StocktakeUi.red600),
                    const SizedBox(width: 4),
                    Text('inventory.stocktake.card_diff'.tr(args: {'n': s.differenceItems}),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StocktakeUi.red600)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          const Icon(Icons.fact_check_outlined, size: 44, color: AppColors.slate400),
          const SizedBox(height: 10),
          Text('inventory.stocktake.list_empty'.tr(),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate400)),
        ]),
      );

  Widget _buildError() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          const Icon(Icons.error_outline, size: 40, color: StocktakeUi.red600),
          const SizedBox(height: 10),
          Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: Text('inventory.stocktake.retry'.tr())),
        ]),
      );
}
