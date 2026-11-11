import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../models/hrm_models.dart';
import '../../models/inventory_models.dart';
import '../../services/hrm_service.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import '../../utils/user_resolver.dart';
import 'components/inventory_asset_create_dialog.dart';
import 'components/inventory_asset_detail_sheet.dart';
import 'components/inventory_custody_declare_dialog.dart';
import 'components/inventory_custody_assign_dialog.dart';

class InventoryAssetsScreen extends StatefulWidget {
  final int initialTab;
  const InventoryAssetsScreen({super.key, this.initialTab = 0});

  @override
  State<InventoryAssetsScreen> createState() => _InventoryAssetsScreenState();
}

class _InventoryAssetsScreenState extends State<InventoryAssetsScreen> with SingleTickerProviderStateMixin {
  final ModuleBusinessService _service = ModuleBusinessService();
  final HrmService _hrmService = HrmService();
  final Map<String, String> _employeeNameMap = {};

  late TabController _tabController;
  List<CustodyAssetItem> _custodyAssets = [];
  List<AssetItem> _treeAssets = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Custody Tab filters
  String _selectedCustodyFilter = 'ALL';
  String _custodySearchQuery = '';
  final TextEditingController _custodySearchController = TextEditingController();

  // Asset Tree Tab state
  bool _isTreeView = true;
  String _treeSearchQuery = '';
  final TextEditingController _treeSearchController = TextEditingController();
  final Set<String> _collapsedNodes = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _custodySearchController.dispose();
    _treeSearchController.dispose();
    super.dispose();
  }

  String _getEmployeeDisplayName(String? empId, [String? fallbackName]) {
    if (fallbackName != null && fallbackName.trim().isNotEmpty && !UserResolver.isUuid(fallbackName)) {
      return fallbackName.trim();
    }
    if (empId == null || empId.trim().isEmpty) return '—';
    final cleanId = empId.trim();
    if (_employeeNameMap.containsKey(cleanId)) {
      return _employeeNameMap[cleanId]!;
    }
    final resolved = UserResolver.resolveName(cleanId, fallback: '');
    if (resolved.isNotEmpty && !UserResolver.isUuid(resolved)) {
      return resolved;
    }
    return fallbackName ?? cleanId;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getCustodyAssets(),
        _service.getAssets(),
        UserResolver.ensureLoaded(),
        _hrmService.getEmployees(forceRefresh: false).catchError((_) => <HrmEmployeeItem>[]),
        _service.getAuditorCandidates().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      // Populate employee name mappings
      final emps = results[3] as List<HrmEmployeeItem>;
      for (final e in emps) {
        if (e.id.isNotEmpty && e.fullName.isNotEmpty) {
          _employeeNameMap[e.id] = e.fullName;
        }
        if (e.code.isNotEmpty && e.fullName.isNotEmpty) {
          _employeeNameMap[e.code] = e.fullName;
        }
      }

      final auditors = results[4] as List<Map<String, dynamic>>;
      for (final a in auditors) {
        final id = a['id']?.toString() ?? a['employeeId']?.toString();
        final name = a['name']?.toString() ?? a['fullName']?.toString();
        final code = a['code']?.toString() ?? a['employeeCode']?.toString();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          _employeeNameMap[id] = name;
        }
        if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
          _employeeNameMap[code] = name;
        }
      }

      final rawCustody = results[0] as List<CustodyAssetItem>;
      final rawTree = results[1] as List<AssetItem>;

      final mappedCustody = rawCustody.map((a) {
        final name = _getEmployeeDisplayName(a.assignedEmployeeId, a.assignedEmployeeName);
        if (name != a.assignedEmployeeId) {
          return CustodyAssetItem(
            id: a.id,
            code: a.code,
            name: a.name,
            status: a.status,
            assetCategory: a.assetCategory,
            serialNumber: a.serialNumber,
            unit: a.unit,
            purchasePrice: a.purchasePrice,
            assignedEmployeeId: a.assignedEmployeeId,
            assignedEmployeeName: name,
            assignedAt: a.assignedAt,
          );
        }
        return a;
      }).toList();

      if (mounted) {
        setState(() {
          _custodyAssets = mappedCustody;
          _treeAssets = rawTree;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không tải được dữ liệu: $e';
        });
      }
    }
  }

  // --- CUSTODY TAB HELPERS ---
  List<CustodyAssetItem> get _filteredCustodyAssets {
    return _custodyAssets.where((asset) {
      if (_selectedCustodyFilter == 'IN_USE' && asset.custodyState != CustodyState.inUse) return false;
      if (_selectedCustodyFilter == 'MAINTENANCE' && asset.custodyState != CustodyState.maintenance) return false;
      if (_selectedCustodyFilter == 'IN_STOCK' && asset.custodyState != CustodyState.inStock) return false;

      if (_custodySearchQuery.isNotEmpty) {
        final q = _custodySearchQuery.toLowerCase();
        final matchCode = asset.code.toLowerCase().contains(q);
        final matchName = asset.name.toLowerCase().contains(q);
        final matchSerial = asset.serialNumber?.toLowerCase().contains(q) ?? false;
        final matchEmp = asset.assignedEmployeeName?.toLowerCase().contains(q) ?? false;
        return matchCode || matchName || matchSerial || matchEmp;
      }
      return true;
    }).toList();
  }

  List<CustodyAssetItem> get _inStockAssets {
    return _custodyAssets.where((a) => a.custodyState == CustodyState.inStock).toList();
  }

  void _openDeclareDialog() {
    showDialog(
      context: context,
      builder: (_) => InventoryCustodyDeclareDialog(onDeclared: _loadData),
    );
  }

  void _openAssignDialog({String? initialCode}) {
    showDialog(
      context: context,
      builder: (_) => InventoryCustodyAssignDialog(
        assets: _inStockAssets,
        initialCode: initialCode,
        onAssigned: _loadData,
      ),
    );
  }

  // --- ASSET TREE TAB HELPERS (Matching Web buildAssetTree 1:1) ---
  List<_AssetTreeEntry> get _flatTreeNodes {
    final assets = _treeAssets;
    final present = assets.map((a) => a.id).toSet();
    final byId = {for (final a in assets) a.id: a};
    final childrenOf = <String, List<AssetItem>>{};
    final roots = <AssetItem>[];

    for (final a in assets) {
      final pid = a.parentId;
      if (pid != null && pid.isNotEmpty && present.contains(pid)) {
        childrenOf.putIfAbsent(pid, () => []).add(a);
      } else {
        roots.pushIfAbsent(a);
      }
    }

    // Determine visible IDs by search query
    final keep = <String>{};
    final q = _treeSearchQuery.trim().toLowerCase();
    for (final a in assets) {
      final match = q.isEmpty || a.code.toLowerCase().contains(q) || a.name.toLowerCase().contains(q);
      if (match) {
        AssetItem? cursor = a;
        while (cursor != null && !keep.contains(cursor.id)) {
          keep.add(cursor.id);
          final pid = cursor.parentId;
          cursor = (pid != null && pid.isNotEmpty) ? byId[pid] : null;
        }
      }
    }

    final flat = <_AssetTreeEntry>[];
    int byCode(AssetItem a, AssetItem b) => a.code.compareTo(b.code);

    void emit(AssetItem asset, int depth) {
      if (!keep.contains(asset.id)) return;
      final children = (childrenOf[asset.id] ?? []).where((c) => keep.contains(c.id)).toList()..sort(byCode);
      final isCollapsed = _collapsedNodes.contains(asset.id);
      flat.add(_AssetTreeEntry(
        asset: asset,
        depth: depth,
        hasChildren: children.isNotEmpty,
        expanded: children.isNotEmpty && !isCollapsed,
      ));
      if (isCollapsed) return;
      for (final child in children) {
        emit(child, depth + 1);
      }
    }

    final sortedRoots = roots.where((r) => keep.contains(r.id)).toList()..sort(byCode);
    for (final root in sortedRoots) {
      emit(root, 0);
    }

    return flat;
  }

  void _toggleNode(String id) {
    setState(() {
      if (_collapsedNodes.contains(id)) {
        _collapsedNodes.remove(id);
      } else {
        _collapsedNodes.add(id);
      }
    });
  }

  void _showAssetDetailSheet(AssetItem asset) {
    InventoryAssetDetailSheet.show(
      context,
      asset: asset,
      onSaved: _loadData,
      onAssetDeleted: _loadData,
    );
  }

  void _confirmRetireNode(AssetItem asset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Thanh lý ${asset.name}?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: Text(
          'Xác nhận để mở quy trình tháo dỡ và thanh lý hoàn kho cho thiết bị ${asset.code} (${asset.name}).',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _service.retireAsset(asset.code);
              if (ok) {
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thanh lý thiết bị ${asset.code} thành công')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể thanh lý thiết bị, vui lòng thử lại sau.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận thanh lý'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tài sản & Cây thiết bị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Sổ theo dõi tài sản và cây cấu trúc thiết bị phân cấp',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
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
            Tab(text: 'Tài sản (${_custodyAssets.length})'),
            Tab(text: 'Cây tài sản (${_treeAssets.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCustodyTab(),
          _buildAssetTreeTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: TÀI SẢN (Matching Web CustodyPanel 1:1)
  // =========================================================================
  Widget _buildCustodyTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredCustodyAssets;
    final inUseCount = _custodyAssets.where((a) => a.custodyState == CustodyState.inUse).length;
    final maintCount = _custodyAssets.where((a) => a.custodyState == CustodyState.maintenance).length;
    final inStockCount = _custodyAssets.where((a) => a.custodyState == CustodyState.inStock).length;

    final filterTabs = [
      {'id': 'ALL', 'label': 'Tất cả (${_custodyAssets.length})'},
      {'id': 'IN_USE', 'label': 'Đang sử dụng ($inUseCount)'},
      {'id': 'MAINTENANCE', 'label': 'Bảo trì ($maintCount)'},
      {'id': 'IN_STOCK', 'label': 'Tồn kho ($inStockCount)'},
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Filter & Search Header (Matching Web: Tabs on left, Actions & Search on right)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action Buttons Row (Khai báo tài sản & Cấp phát)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openDeclareDialog,
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Khai báo tài sản', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openAssignDialog(),
                        icon: const Icon(Icons.assignment_ind_outlined, size: 15),
                        label: const Text('Cấp phát', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Box
                TextField(
                  controller: _custodySearchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm tài sản, số sê-ri hoặc nhân viên...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _custodySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _custodySearchController.clear();
                              setState(() => _custodySearchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _custodySearchQuery = val.trim()),
                ),
                const SizedBox(height: 10),

                // Horizontal Filter Chips with counters (Matching Web: Tất cả (0), Đang sử dụng (0)...)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filterTabs.map((f) {
                      final isSelected = _selectedCustodyFilter == f['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            f['label']!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1D4ED8),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0)),
                          onSelected: (_) => setState(() => _selectedCustodyFilter = f['id']!),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Custody List Body
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.devices_other_rounded, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 10),
                          Text(
                            _custodyAssets.isEmpty
                                ? 'Chưa có tài sản nào được khai báo.'
                                : 'Không có tài sản phù hợp.',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final asset = filtered[index];
                      return _buildCustodyAssetCard(asset);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustodyAssetCard(CustodyAssetItem asset) {
    final state = asset.custodyState;
    Color stateBg;
    Color stateFg;
    Color stateBorder;

    switch (state) {
      case CustodyState.inUse:
        stateBg = const Color(0xFFF0FDF4);
        stateFg = const Color(0xFF15803D);
        stateBorder = const Color(0xFFBBF7D0);
        break;
      case CustodyState.maintenance:
        stateBg = const Color(0xFFFFFBEB);
        stateFg = const Color(0xFFB45309);
        stateBorder = const Color(0xFFFDE68A);
        break;
      case CustodyState.inStock:
        stateBg = const Color(0xFFEFF6FF);
        stateFg = const Color(0xFF1D4ED8);
        stateBorder = const Color(0xFFBFDBFE);
        break;
      case CustodyState.stopped:
        stateBg = const Color(0xFFF1F5F9);
        stateFg = const Color(0xFF475569);
        stateBorder = const Color(0xFFCBD5E1);
        break;
      case CustodyState.disposed:
        stateBg = const Color(0xFFFEF2F2);
        stateFg = const Color(0xFF991B1B);
        stateBorder = const Color(0xFFFECACA);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dòng 1: [Mã] [Tên tài sản] ................. [Trạng thái Badge]
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  asset.code,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  asset.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: stateBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: stateBorder),
                ),
                child: Text(
                  '• ' + asset.stateLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: stateFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dòng 2: Metadata (Nhóm, SN, Giá) + Nút cấp phát gọn gàng bên phải
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.category_outlined, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          asset.categoryLabel,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (asset.serialNumber != null && asset.serialNumber!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Text(
                            asset.serialNumber!,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    if (asset.purchasePrice != null && asset.purchasePrice! > 0)
                      Text(
                        Formatters.formatCurrency(asset.purchasePrice!),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                  ],
                ),
              ),
              if (state == CustodyState.inStock) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openAssignDialog(initialCode: asset.code),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_ind_outlined, size: 13, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 4),
                        Text(
                          'Cấp phát',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Nếu đang sử dụng: Hiển thị dòng người nhận gọn nhẹ
          if (state == CustodyState.inUse && (asset.assignedEmployeeName != null || asset.assignedEmployeeId != null)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Người nhận: ' + _getEmployeeDisplayName(asset.assignedEmployeeId, asset.assignedEmployeeName),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (asset.assignedAt != null)
                    Text(
                      '${asset.assignedAt!.day.toString().padLeft(2, '0')}/${asset.assignedAt!.month.toString().padLeft(2, '0')}/${asset.assignedAt!.year}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: CÂY TÀI SẢN (Matching Web AssetTree 1:1)
  // =========================================================================
  Widget _buildAssetTreeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final nodes = _flatTreeNodes;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Header Card: Title, Count hint, Buttons: Dạng bảng/cây toggle, + Gốc
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cây cấu trúc thiết bị',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_treeAssets.length} vị trí / thiết bị',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _isTreeView = !_isTreeView),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            _isTreeView ? 'Dạng bảng' : 'Dạng cây',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => InventoryAssetCreateDialog.show(context, onCreated: _loadData),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('+ Gốc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Box: Tìm theo mã hoặc tên thiết bị...
                TextField(
                  controller: _treeSearchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã hoặc tên thiết bị...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _treeSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _treeSearchController.clear();
                              setState(() => _treeSearchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _treeSearchQuery = val.trim()),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Tree / Table Body
          Expanded(
            child: nodes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 10),
                          Text(
                            _treeAssets.isEmpty
                                ? 'Chưa có thiết bị nào trong cây cấu trúc.'
                                : 'Không có tài sản khớp tìm kiếm.',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: nodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final node = nodes[index];
                      return _buildTreeNodeCard(node);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNodeCard(_AssetTreeEntry entry) {
    final asset = entry.asset;
    final depth = entry.depth;

    String depthBadgeChar;
    Color depthBg;
    Color depthFg;

    switch (depth) {
      case 0:
        depthBadgeChar = 'R';
        depthBg = const Color(0xFFEFF6FF);
        depthFg = const Color(0xFF1D4ED8);
        break;
      case 1:
        depthBadgeChar = '1';
        depthBg = const Color(0xFFFEF3C7);
        depthFg = const Color(0xFFB45309);
        break;
      case 2:
        depthBadgeChar = '2';
        depthBg = const Color(0xFFF0FDF4);
        depthFg = const Color(0xFF15803D);
        break;
      default:
        depthBadgeChar = '$depth';
        depthBg = const Color(0xFFF5F3FF);
        depthFg = const Color(0xFF6D28D9);
    }

    final double indent = _isTreeView ? (depth * 20.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: InkWell(
        onTap: () => _showAssetDetailSheet(asset),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              if (_isTreeView) ...[
                if (entry.hasChildren)
                  InkWell(
                    onTap: () => _toggleNode(asset.id),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        entry.expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
              ],

              // Depth badge box matching Web (R for Root #eff6ff / #1d4ed8)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: depthBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  depthBadgeChar,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: depthFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Asset Name (bold 13.5) & Code below
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.code,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick action buttons [+] (green) and [-] (red)
              InkWell(
                onTap: () => InventoryAssetCreateDialog.show(context, parentAsset: asset, onCreated: _loadData),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 15, color: Color(0xFF15803D)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _confirmRetireNode(asset),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Center(
                    child: Icon(Icons.remove, size: 15, color: Color(0xFFB91C1C)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetTreeEntry {
  final AssetItem asset;
  final int depth;
  final bool hasChildren;
  final bool expanded;

  const _AssetTreeEntry({
    required this.asset,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
  });
}

extension _ListExtensions<T> on List<T> {
  void pushIfAbsent(T item) {
    if (!contains(item)) add(item);
  }
}
