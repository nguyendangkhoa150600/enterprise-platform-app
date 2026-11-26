import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../features/inventory/data/assets/inventory_asset_repository.dart';
import '../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../features/inventory/domain/inventory_capabilities.dart';
import '../../features/inventory/presentation/assets/inventory_asset_list_sheet.dart';
import '../../features/inventory/presentation/assets/inventory_asset_tree_tab.dart';
import '../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../features/inventory/presentation/assets/inventory_bulk_return_sheet.dart';
import '../../features/inventory/presentation/assets/inventory_custody_tab.dart';
import '../../features/inventory/presentation/assets/inventory_install_material_sheet.dart';
import '../../features/inventory/presentation/assets/inventory_return_to_stock_sheet.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';
import 'components/inventory_asset_detail_sheet.dart';

/// Hai mục "Tài sản" (tab 0, web NAV `custody`) và "Cây tài sản" (tab 1, web NAV `assets`) của module Kho.
class InventoryAssetsScreen extends StatefulWidget {
  final int initialTab;
  const InventoryAssetsScreen({super.key, this.initialTab = 0});

  @override
  State<InventoryAssetsScreen> createState() => _InventoryAssetsScreenState();
}

class _InventoryAssetsScreenState extends State<InventoryAssetsScreen> with SingleTickerProviderStateMixin {
  final _repo = InventoryAssetRepository.instance;
  late final TabController _tabController =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
  final ValueNotifier<InvAssetWorkspace?> _workspace = ValueNotifier(null);
  final GlobalKey<InventoryCustodyTabState> _custodyKey = GlobalKey();
  final Map<String, List<InvIncidentLog>> _sessionLogs = {};

  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _partialError;
  String? _selectedAssetId;
  int? _custodyCount;
  List<InvProcedureOption>? _procedures;

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _workspace.dispose();
    super.dispose();
  }

  /// Web `reload`: nạp lại dữ liệu cây; lỗi một phần giữ dữ liệu đã có và hiện dải báo kèm nút Tải lại.
  Future<void> _reload() async {
    try {
      final res = await _repo.loadWorkspace();
      if (!mounted) return;
      final ws = res.installedError == null
          ? res.workspace
          : res.workspace.copyWith(installed: _workspace.value?.installed ?? const []);
      _workspace.value = ws;
      setState(() {
        _loading = false;
        _loadError = null;
        _partialError = res.installedError == null
            ? null
            : 'inventory.assets.partial_load_error'.tr(args: {'detail': inventoryErrorMessage(res.installedError)});
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_workspace.value == null) {
          _loadError = inventoryErrorMessage(e);
        } else {
          _partialError = 'inventory.assets.partial_load_error'.tr(args: {'detail': inventoryErrorMessage(e)});
        }
      });
    }
  }

  /// Web `perform`: chạy lệnh ghi, báo kết quả, nạp lại. [rethrow_] để form đang mở hiện lỗi.
  Future<void> _perform(Future<String?> Function() run, {bool rethrow_ = false}) async {
    setState(() => _busy = true);
    try {
      final message = await run();
      if (mounted && message != null) invToast(context, message);
      await _reload();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (rethrow_) rethrow;
      if (mounted) invToast(context, inventoryErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<InvProcedureOption>> _loadProcedures() async {
    final cached = _procedures;
    if (cached != null && cached.isNotEmpty) return cached;
    final list = await _repo.loadProcedureOptions();
    _procedures = list;
    return list;
  }

  /// Mở work order bên Quy trình sau lệnh kho; lỗi chỉ báo, không làm hỏng lệnh đã ghi (web `openMovementWorkOrder`).
  Future<void> _openWorkOrder(String definitionId, String title, String failKey) async {
    try {
      final code = await _repo.openMovementWorkOrder(definitionId: definitionId, title: title);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('inventory.assets.wo_opened_title'.tr()),
          content: Text('inventory.assets.wo_opened_message'.tr(args: {'code': code})),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('inventory.assets.close'.tr()))],
        ),
      );
    } catch (e) {
      if (mounted) {
        invToast(context, '${failKey.tr()} ${inventoryErrorMessage(e)}', error: true);
      }
    }
  }

  // --------------------------------------------------------------------- Thao tác cây

  Future<void> _install(InvAsset? parent) async {
    final ws = _workspace.value;
    if (ws == null) return;
    await invShowSheet<bool>(
      context,
      InventoryInstallMaterialSheet(
        parent: parent,
        workspace: ws,
        onConfirm: (code, body) => _perform(() async {
          final res = await _repo.installItem(code, body);
          final qty = invFormatQty(body['quantity'] as num);
          return parent != null
              ? 'inventory.assets.installed_toast'
                  .tr(args: {'qty': qty, 'code': code, 'wh': body['warehouseCode'], 'parent': parent.code, 'ref': res.reference})
              : 'inventory.assets.installed_root_toast'
                  .tr(args: {'qty': qty, 'code': code, 'wh': body['warehouseCode'], 'ref': res.reference});
        }, rethrow_: true),
      ),
    );
  }

  Map<String, dynamic> _returnBody(InvReturnInput input) => {
        'warehouseCode': input.warehouseCode,
        'quantity': input.quantity,
        if (input.note != null) 'note': input.note,
        if (input.serials != null) 'serials': input.serials,
      };

  Future<void> _returnAsset(InvAsset asset) async {
    final ws = _workspace.value;
    if (ws == null) return;
    final procedures = await _loadProcedures();
    if (!mounted) return;
    await invShowSheet<bool>(
      context,
      InventoryReturnToStockSheet(
        title: 'inventory.assets.return_title'.tr(args: {'name': asset.name}),
        description: 'inventory.assets.return_desc'.tr(args: {'code': asset.code}),
        unit: asset.unit,
        maxQuantity: 1,
        isAsset: true,
        warehouses: ws.warehouses,
        procedures: procedures,
        hasChildren: ws.hasChildren(asset),
        onConfirm: (input) => _perform(() async {
          final res = await _repo.returnItemToStock(asset.code, {
            ..._returnBody(input),
            if (input.procedureDefinitionId != null) 'procedureDefinitionId': input.procedureDefinitionId,
          });
          if (_selectedAssetId == asset.id) _selectedAssetId = null;
          if (input.procedureDefinitionId != null) {
            await _openWorkOrder(
              input.procedureDefinitionId!,
              'inventory.assets.wo_title_return'
                  .tr(args: {'code': asset.code, 'name': asset.name, 'wh': input.warehouseCode, 'ref': res.reference}),
              'inventory.assets.wo_fail_return',
            );
          }
          return res.pending
              ? 'inventory.assets.return_pending_toast'.tr(args: {'ref': res.reference, 'code': asset.code, 'wh': input.warehouseCode})
              : 'inventory.assets.return_done_toast'.tr(args: {'code': asset.code, 'wh': input.warehouseCode, 'ref': res.reference});
        }, rethrow_: true),
      ),
    );
  }

  Future<void> _uninstall(InvAsset asset, InvInstalledMaterial line) async {
    final ws = _workspace.value;
    if (ws == null) return;
    final procedures = await _loadProcedures();
    if (!mounted) return;
    final serialized = ws.materialByCode(line.materialCode)?.isSerialized ?? false;
    await invShowSheet<bool>(
      context,
      InventoryReturnToStockSheet(
        title: 'inventory.assets.uninstall_title'.tr(args: {'name': asset.name}),
        description: 'inventory.assets.uninstall_desc'.tr(args: {
          'code': asset.code,
          'material': line.materialCode,
          'qty': invFormatQty(line.quantity),
          'unit': line.unit ?? '',
        }),
        unit: line.unit,
        maxQuantity: line.quantity,
        serialMaterialCode: serialized ? line.materialCode : null,
        warehouses: ws.warehouses,
        procedures: procedures,
        onConfirm: (input) => _perform(() async {
          final res = await _repo.uninstallMaterial(asset.code, _returnBody(input));
          if (_selectedAssetId == asset.id) _selectedAssetId = null;
          if (input.procedureDefinitionId != null) {
            await _openWorkOrder(
              input.procedureDefinitionId!,
              'inventory.assets.wo_title_uninstall'
                  .tr(args: {'material': line.materialCode, 'code': asset.code, 'wh': input.warehouseCode, 'ref': res.reference}),
              'inventory.assets.wo_fail_uninstall',
            );
          }
          return 'inventory.assets.uninstall_done_toast'.tr(args: {
            'qty': invFormatQty(input.quantity),
            'material': line.materialCode,
            'wh': input.warehouseCode,
            'ref': res.reference,
          });
        }, rethrow_: true),
      ),
    );
  }

  Future<void> _bulkReturn(List<InvBulkReturnEntry> entries) => _perform(() async {
        final pending = <String>[];
        for (final e in entries) {
          final note = e.note.text.trim();
          final res = await _repo.returnItemToStock(e.asset.code, {
            'warehouseCode': e.warehouseCode,
            'quantity': 1,
            if (note.isNotEmpty) 'note': note,
          });
          if (res.pending) pending.add(res.reference);
          if (_selectedAssetId == e.asset.id) _selectedAssetId = null;
        }
        return pending.isNotEmpty
            ? 'inventory.assets.bulk_pending_toast'
                .tr(args: {'n': entries.length - pending.length, 'm': pending.length, 'refs': pending.join(', ')})
            : 'inventory.assets.bulk_done_toast'.tr(args: {'n': entries.length});
      }, rethrow_: true);

  void _move(InvAsset asset, String? parentCode) => _perform(() async {
        await _repo.updateAsset(asset.code, {'parentCode': parentCode});
        return parentCode != null
            ? 'inventory.assets.moved_toast'.tr(args: {'code': asset.code, 'parent': parentCode})
            : 'inventory.assets.moved_root_toast'.tr(args: {'code': asset.code});
      });

  void _openDetail(InvAsset asset, bool canManage) {
    setState(() => _selectedAssetId = asset.id);
    InventoryAssetDetailSheet.show(
      context,
      assetId: asset.id,
      workspace: _workspace,
      onReload: _reload,
      sessionLogs: _sessionLogs,
      onRetire: canManage ? _returnAsset : null,
      onAddChild: canManage ? (a) => _install(a) : null,
    );
  }

  Future<void> _openList(bool canManage) async {
    final ws = _workspace.value;
    if (ws == null) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryAssetListSheet(
        workspace: ws,
        selectedId: _selectedAssetId,
        onBulkReturn: canManage ? _bulkReturn : null,
      ),
    );
    if (id == null || !mounted) return;
    for (final a in _workspace.value?.assets ?? const <InvAsset>[]) {
      if (a.id == id) _openDetail(a, canManage);
    }
  }

  // --------------------------------------------------------------------- Giao diện

  @override
  Widget build(BuildContext context) {
    final treeCount = _workspace.value?.assets.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('inventory.assets.screen_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('inventory.assets.screen_subtitle'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'inventory.assets.refresh'.tr(),
            onPressed: () {
              _reload();
              _custodyKey.currentState?.reload();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: _custodyCount == null ? 'inventory.assets.tab_custody'.tr() : '${'inventory.assets.tab_custody'.tr()} ($_custodyCount)'),
            Tab(text: treeCount == null ? 'inventory.assets.tab_tree'.tr() : '${'inventory.assets.tab_tree'.tr()} ($treeCount)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          InventoryCustodyTab(
            key: _custodyKey,
            onChanged: _reload,
            onCount: (n) {
              if (mounted && n != _custodyCount) setState(() => _custodyCount = n);
            },
          ),
          _treeTab(),
        ],
      ),
    );
  }

  Widget _treeTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ws = _workspace.value;
    if (ws == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Color(0xFFDC2626)),
              const SizedBox(height: 10),
              Text(_loadError ?? 'inventory.common.error_generic'.tr(),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: invPrimaryStyle(),
                onPressed: () {
                  setState(() => _loading = true);
                  _reload();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('inventory.assets.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    return ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) {
        final canManage = caps.canManage;
        return Column(
          children: [
            if (_partialError != null)
              Container(
                width: double.infinity,
                color: const Color(0xFFFDF2F2),
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_partialError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFA12B2B))),
                    ),
                    TextButton(onPressed: _reload, child: Text('inventory.assets.reload'.tr())),
                  ],
                ),
              ),
            Expanded(
              child: InventoryAssetTreeTab(
                workspace: ws,
                busy: _busy,
                selectedId: _selectedAssetId,
                onRefresh: _reload,
                onSelect: (a) => _openDetail(a, canManage),
                onOpenList: () => _openList(canManage),
                onAddRoot: canManage ? () => _install(null) : null,
                onInstall: canManage ? (a) => _install(a) : null,
                onUninstall: canManage ? _uninstall : null,
                onReturn: canManage ? _returnAsset : null,
                onMove: canManage ? _move : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
