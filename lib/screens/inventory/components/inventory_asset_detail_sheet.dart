import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/assets/inventory_asset_repository.dart';
import '../../../features/inventory/domain/assets/inventory_asset_models.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/presentation/assets/inventory_asset_ui.dart';
import '../../../features/inventory/presentation/assets/inventory_incident_record_sheet.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';
import 'asset_tabs/asset_bom_tab_view.dart';
import 'asset_tabs/asset_documents_tab_view.dart';
import 'asset_tabs/asset_history_tab_view.dart';
import 'asset_tabs/asset_maintenance_plan_tab_view.dart';
import 'asset_tabs/asset_overview_tab_view.dart';

/// Hồ sơ một thiết bị trên cây (web `AssetDetail`): đầu trang + 5 tab con.
/// Đọc thiết bị từ [workspace] (nạp lại sau mỗi lần lưu); thiết bị biến mất (đã tháo về kho) thì tự đóng.
///
/// Chế độ "hồ sơ theo mã" ([showProfile], web `ItemProfileDialog`): nạp mã bằng `GET /items/:code`
/// (kho hay đã lắp đều mở được) và tự nạp workspace để hiện vị trí theo chuỗi cha.
class InventoryAssetDetailSheet extends StatefulWidget {
  final String assetId;

  /// Mã mở ở chế độ hồ sơ theo mã; `null` = mở từ cây tài sản.
  final String? profileCode;
  final ValueNotifier<InvAssetWorkspace?>? workspace;
  final Future<void> Function() onReload;
  final void Function(InvAsset asset)? onRetire;
  final void Function(InvAsset asset)? onAddChild;

  /// Nhật ký sự cố ghi trong phiên, theo mã thiết bị (web `historyLogsByAsset`).
  final Map<String, List<InvIncidentLog>> sessionLogs;

  const InventoryAssetDetailSheet({
    super.key,
    required this.assetId,
    required this.workspace,
    required this.onReload,
    required this.sessionLogs,
    this.onRetire,
    this.onAddChild,
  }) : profileCode = null;

  const InventoryAssetDetailSheet._profile({
    required String this.profileCode,
    required this.onReload,
  })  : assetId = '',
        workspace = null,
        sessionLogs = const {},
        onRetire = null,
        onAddChild = null;

  static Future<void> show(
    BuildContext context, {
    required String assetId,
    required ValueNotifier<InvAssetWorkspace?> workspace,
    required Future<void> Function() onReload,
    required Map<String, List<InvIncidentLog>> sessionLogs,
    void Function(InvAsset asset)? onRetire,
    void Function(InvAsset asset)? onAddChild,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InventoryAssetDetailSheet(
          assetId: assetId,
          workspace: workspace,
          onReload: onReload,
          sessionLogs: sessionLogs,
          onRetire: onRetire,
          onAddChild: onAddChild,
        ),
      );

  /// Hồ sơ đầy đủ của một mã (web `ItemProfileDialog`); [onSaved] chạy sau mỗi lần lưu (web nạp lại workspace).
  /// Như web: không có "Thêm thiết bị con" / "Thanh lý" (chỉ có nghĩa với thiết bị trên cây).
  static Future<void> showProfile(
    BuildContext context, {
    required String code,
    required Future<void> Function() onSaved,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InventoryAssetDetailSheet._profile(profileCode: code, onReload: onSaved),
      );

  @override
  State<InventoryAssetDetailSheet> createState() => _InventoryAssetDetailSheetState();
}

class _InventoryAssetDetailSheetState extends State<InventoryAssetDetailSheet> with SingleTickerProviderStateMixin {
  final _repo = InventoryAssetRepository.instance;
  late final TabController _tabs = TabController(length: 5, vsync: this);
  bool _hasMaintenance = false;
  bool _syncing = false;
  List<InvMaintenanceOccurrence> _occurrences = [];
  String? _loadedFor;
  bool _closing = false;

  // Chế độ hồ sơ theo mã (web `ItemProfileDialog`).
  bool get _isProfile => widget.profileCode != null;
  late final ValueNotifier<InvAssetWorkspace?> _workspace = widget.workspace ?? ValueNotifier(null);
  InvAsset? _profile;
  String? _profileError;
  final Map<String, List<InvIncidentLog>> _profileLogs = {};

  Map<String, List<InvIncidentLog>> get _logs => _isProfile ? _profileLogs : widget.sessionLogs;

  @override
  void initState() {
    super.initState();
    if (_isProfile) {
      _loadProfile();
      _loadProfileWorkspace();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    if (widget.workspace == null) _workspace.dispose();
    super.dispose();
  }

  /// Web `reload`: nạp lại hồ sơ từ server (dòng trên bảng là bản rút gọn).
  Future<void> _loadProfile() async {
    try {
      final asset = await _repo.loadItemProfile(widget.profileCode!);
      if (!mounted) return;
      setState(() {
        _profile = asset;
        _profileError = null;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _profileError = inventoryErrorMessage(e, 'inventory.assets.profile_error'));
    }
  }

  /// Workspace (vị trí theo chuỗi cha, vật tư, tồn); lỗi thì dùng workspace rỗng như web `assets = []`.
  Future<void> _loadProfileWorkspace() async {
    InvAssetWorkspace ws;
    try {
      ws = (await _repo.loadWorkspace()).workspace;
    } catch (_) {
      ws = InvAssetWorkspace(warehouses: const [], materials: const [], assets: const [], stock: const [], installed: const []);
    }
    if (!mounted) return;
    _workspace.value = ws;
  }

  /// Sau khi lưu: cây → nạp lại workspace của màn cha; hồ sơ → nạp lại hồ sơ + báo nơi mở (web `onSaved`).
  Future<void> _afterSave() async {
    if (!_isProfile) return widget.onReload();
    unawaited(widget.onReload());
    await Future.wait([_loadProfile(), _loadProfileWorkspace()]);
  }

  InvAsset? _find(InvAssetWorkspace? ws) {
    if (ws == null) return null;
    for (final a in ws.assets) {
      if (a.id == widget.assetId) return a;
    }
    return null;
  }

  Future<void> _loadMaintenance(String code) async {
    _loadedFor = code;
    setState(() => _syncing = true);
    final items = await _repo.loadMaintenanceHistory(code);
    if (!mounted || _loadedFor != code) return;
    setState(() {
      _syncing = false;
      _hasMaintenance = items != null;
      _occurrences = items ?? const [];
    });
  }

  /// Lưu một phần hồ sơ (web `save`): lỗi hiện toast, trả `true` khi lưu xong.
  Future<bool> _save(InvAsset asset, Map<String, dynamic> patch) async {
    try {
      // Hồ sơ theo mã (mở từ kho): lưu qua `/items/:code` — web dùng `/assets/:code` nên mã không phải ASSET bị 404.
      if (_isProfile) {
        await _repo.updateItemProfile(asset.code, patch);
      } else {
        await _repo.updateAsset(asset.code, patch);
      }
      await _afterSave();
      return true;
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (mounted) invToast(context, inventoryErrorMessage(e, 'inventory.assets.save_error'), error: true);
      return false;
    }
  }

  Future<void> _recordIncident(InvAsset asset) async {
    final log = await invShowSheet<InvIncidentLog>(context, InventoryIncidentRecordSheet(asset: asset));
    if (log == null || !mounted) return;
    setState(() => _logs[asset.code] = [log, ...?_logs[asset.code]]);
    if (log.syncToMaintenance) {
      final ok = await _repo.createMaintenanceIncident(
        assetCode: asset.code,
        title: log.title,
        description: log.desc,
        priority: log.severity == 'CRITICAL' || log.severity == 'HIGH' ? 'High' : 'Normal',
      );
      if (ok && mounted) await _loadMaintenance(asset.code);
    }
  }

  Future<void> _editBasic(InvAsset asset) async {
    await invShowSheet<void>(context, _EditBasicSheet(asset: asset, onSave: (patch) => _save(asset, patch)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InvAssetWorkspace?>(
      valueListenable: _workspace,
      builder: (context, ws, _) {
        final asset = _isProfile ? _profile : _find(ws);
        if (_isProfile && (asset == null || ws == null)) return _profilePlaceholder();
        if (asset == null || ws == null) {
          if (!_closing) {
            _closing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
          return const SizedBox.shrink();
        }
        if (_loadedFor != asset.code) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _loadedFor != asset.code) _loadMaintenance(asset.code);
          });
        }
        return ValueListenableBuilder<InventoryCapabilities>(
          valueListenable: InventoryScope.instance.capabilities,
          builder: (context, caps, _) => _content(asset, ws, caps.canManage),
        );
      },
    );
  }

  /// Web: lỗi "Không đọc được hồ sơ vật tư." hoặc "Đang tải hồ sơ…" dưới tiêu đề "Hồ sơ {mã}".
  Widget _profilePlaceholder() {
    final error = _profileError;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
              children: [
                Expanded(child: _profileTitle()),
                IconButton(icon: const Icon(Icons.close, color: AppColors.slate500), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: error != null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(error, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('inventory.assets.profile_loading'.tr(),
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _profileTitle() => Text(
        'inventory.assets.profile_title'.tr(args: {'code': widget.profileCode ?? ''}),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
      );

  Widget _content(InvAsset asset, InvAssetWorkspace ws, bool canManage) {
    final mq = MediaQuery.of(context);
    final childMaterials = ws.childMaterialsOf(asset);
    final statusTone = asset.status == 'OPERATING'
        ? InvTone.success
        : asset.status == 'MAINTENANCE'
            ? InvTone.warn
            : InvTone.danger;
    final tabLabels = [
      'inventory.assets.tab_overview'.tr(),
      'inventory.assets.tab_documents'.tr(),
      'inventory.assets.tab_history'.tr(),
      'inventory.assets.tab_bom'.tr(),
      'inventory.assets.tab_plan'.tr(),
    ];
    return Container(
      height: mq.size.height * 0.92,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isProfile) ...[_profileTitle(), const SizedBox(height: 8)],
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              InvPill(invAssetTypeLabel(asset.type)),
                              InvPill(invAssetStatusLabel(asset.status), tone: statusTone),
                              InvPill('inventory.assets.level'.tr(args: {'label': invAssetCriticalityLabel(asset.criticality)})),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(asset.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                          const SizedBox(height: 2),
                          Text(
                            '${'inventory.assets.device_code'.tr(args: {'code': asset.code})}'
                            '${asset.serialNumber != null ? ' · Serial: ${asset.serialNumber}' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.slate500), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (canManage) ...[
                        OutlinedButton.icon(
                          style: invOutlineStyle(),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text('inventory.assets.edit'.tr()),
                          onPressed: () => _editBasic(asset),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.onAddChild != null) ...[
                        ElevatedButton.icon(
                          style: invPrimaryStyle(),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('inventory.assets.add_child'.tr()),
                          onPressed: () => widget.onAddChild!(asset),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        style: invOutlineStyle(),
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: Text('inventory.assets.print_qr'.tr()),
                        onPressed: () => showInvAssetQrLabel(context, asset),
                      ),
                      if (widget.onRetire != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: invOutlineStyle(color: const Color(0xFFDC2626)),
                          icon: const Icon(Icons.remove_circle_outline, size: 16),
                          label: Text('inventory.assets.retire'.tr()),
                          onPressed: () async {
                            final cluster = childMaterials.isNotEmpty;
                            final ok = await invConfirm(
                              context,
                              title: (cluster ? 'inventory.assets.retire_cluster_title' : 'inventory.assets.retire_title')
                                  .tr(args: {'name': asset.name}),
                              message: cluster
                                  ? 'inventory.assets.retire_cluster_message'.tr()
                                  : 'inventory.assets.retire_message'.tr(args: {'code': asset.code}),
                            );
                            if (ok && mounted) widget.onRetire!(asset);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF1D4ED8),
                  unselectedLabelColor: AppColors.slate600,
                  indicatorColor: const Color(0xFF1D4ED8),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  tabs: tabLabels.map((t) => Tab(text: t)).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                AssetOverviewTabView(
                  asset: asset,
                  assets: ws.assets,
                  canManage: canManage,
                  onSave: (p) => _save(asset, p),
                ),
                AssetDocumentsTabView(assetCode: asset.code, canManage: canManage),
                AssetHistoryTabView(
                  asset: asset,
                  hasMaintenanceModule: _hasMaintenance,
                  syncing: _syncing,
                  occurrences: _occurrences,
                  logs: _logs[asset.code] ?? const [],
                  canManage: canManage,
                  onRecordIncident: () => _recordIncident(asset),
                ),
                AssetBomTabView(
                  assetCode: asset.code,
                  workspace: ws,
                  childMaterials: childMaterials,
                  canManage: canManage,
                ),
                AssetMaintenancePlanTabView(
                  asset: asset,
                  occurrences: _occurrences,
                  canManage: canManage,
                  onSave: (p) => _save(asset, p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sửa thông tin cơ bản (web khối `editingBasic`): tên, trạng thái, độ quan trọng, serial.
class _EditBasicSheet extends StatefulWidget {
  final InvAsset asset;
  final Future<bool> Function(Map<String, dynamic> patch) onSave;
  const _EditBasicSheet({required this.asset, required this.onSave});
  @override
  State<_EditBasicSheet> createState() => _EditBasicSheetState();
}

class _EditBasicSheetState extends State<_EditBasicSheet> {
  late final _name = TextEditingController(text: widget.asset.name);
  late final _serial = TextEditingController(text: widget.asset.serialNumber ?? '');
  late String _status = widget.asset.status;
  late String _criticality = widget.asset.criticality;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final serial = _serial.text.trim();
    final ok = await widget.onSave({
      'name': _name.text.trim(),
      'status': _status,
      'criticality': _criticality,
      if (serial.isNotEmpty) 'serialNumber': serial,
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = {...kInvAssetStatuses, _status}.toList();
    return InvSheetFrame(
      title: 'inventory.assets.edit_basic_title'.tr(),
      subtitle: '${invAssetTypeLabel(widget.asset.type)} · ${'inventory.assets.device_code'.tr(args: {'code': widget.asset.code})}',
      onClose: () {
        if (!_saving) Navigator.pop(context);
      },
      actions: [
        OutlinedButton(
          style: invOutlineStyle(),
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('inventory.assets.cancel'.tr()),
        ),
        ElevatedButton(
          style: invPrimaryStyle(),
          onPressed: _saving || _name.text.trim().isEmpty ? null : _submit,
          child: Text(_saving ? 'inventory.assets.saving'.tr() : 'inventory.assets.save_changes'.tr()),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvFieldLabel('inventory.assets.device_name'.tr(), required: true),
          TextField(controller: _name, decoration: invInputDecoration(), onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          InvFieldLabel('inventory.assets.operating_status'.tr()),
          InvSelectField(
            options: statuses.map((s) => InvOption(s, invAssetStatusLabel(s))).toList(),
            value: _status,
            placeholder: 'inventory.assets.operating_status'.tr(),
            onChanged: (v) => setState(() => _status = v.isEmpty ? _status : v),
          ),
          const SizedBox(height: 14),
          InvFieldLabel('inventory.assets.col_criticality'.tr()),
          InvSelectField(
            options: kInvAssetCriticalities.map((c) => InvOption(c, invAssetCriticalityLabel(c))).toList(),
            value: _criticality,
            placeholder: 'inventory.assets.col_criticality'.tr(),
            onChanged: (v) => setState(() => _criticality = v.isEmpty ? _criticality : v),
          ),
          const SizedBox(height: 14),
          InvFieldLabel('inventory.assets.serial_frame'.tr()),
          TextField(controller: _serial, decoration: invInputDecoration(hint: 'inventory.assets.optional'.tr())),
        ],
      ),
    );
  }
}
