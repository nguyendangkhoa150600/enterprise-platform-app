import 'package:flutter/material.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';
import 'asset_tabs/asset_bom_tab_view.dart';
import 'asset_tabs/asset_documents_tab_view.dart';
import 'asset_tabs/asset_history_tab_view.dart';
import 'asset_tabs/asset_maintenance_plan_tab_view.dart';
import 'asset_tabs/asset_overview_tab_view.dart';
import 'inventory_asset_create_dialog.dart';

class InventoryAssetDetailSheet extends StatefulWidget {
  final AssetItem asset;
  final VoidCallback onSaved;
  final VoidCallback? onAssetDeleted;

  const InventoryAssetDetailSheet({
    super.key,
    required this.asset,
    required this.onSaved,
    this.onAssetDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required AssetItem asset,
    required VoidCallback onSaved,
    VoidCallback? onAssetDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InventoryAssetDetailSheet(
        asset: asset,
        onSaved: onSaved,
        onAssetDeleted: onAssetDeleted,
      ),
    );
  }

  @override
  State<InventoryAssetDetailSheet> createState() => _InventoryAssetDetailSheetState();
}

class _InventoryAssetDetailSheetState extends State<InventoryAssetDetailSheet>
    with SingleTickerProviderStateMixin {
  final _moduleService = ModuleBusinessService();

  late TabController _tabController;
  late AssetItem _currentAsset;
  bool _isSaving = false;

  final List<String> _tabLabels = [
    'Tổng quan tham số',
    'Tài liệu',
    'Lịch sử vận hành - sự cố',
    'Phụ tùng (BOM)',
    'Kế hoạch bảo trì',
  ];

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Edit Basic Info (Name, Status, Criticality, SerialNumber)
  void _openEditBasicDialog() {
    final nameCtrl = TextEditingController(text: _currentAsset.name);
    final serialCtrl = TextEditingController(text: _currentAsset.serialNumber ?? '');
    String selectedStatus = _currentAsset.status ?? 'OPERATING';
    String selectedCriticality = _currentAsset.criticality ?? 'MEDIUM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Chỉnh sửa thiết bị', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tên thiết bị *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Trạng thái vận hành', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OPERATING', child: Text('Đang vận hành')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì')),
                    DropdownMenuItem(value: 'IDLE', child: Text('Chờ vận hành')),
                    DropdownMenuItem(value: 'DISPOSED', child: Text('Thanh lý')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Độ quan trọng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedCriticality,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CRITICAL', child: Text('Cấp Nghiêm trọng')),
                    DropdownMenuItem(value: 'HIGH', child: Text('Cấp Cao')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Cấp Trung bình')),
                    DropdownMenuItem(value: 'LOW', child: Text('Cấp Thấp')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedCriticality = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Số Serial / Khung', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                TextField(
                  controller: serialCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tùy chọn',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isSaving = true);
                final ok = await _moduleService.updateAsset(_currentAsset.code, {
                  'name': newName,
                  'status': selectedStatus,
                  'criticality': selectedCriticality,
                  'serialNumber': serialCtrl.text.trim().isEmpty ? null : serialCtrl.text.trim(),
                });
                setState(() => _isSaving = false);
                if (ok) {
                  setState(() {
                    _currentAsset = AssetItem(
                      id: _currentAsset.id,
                      code: _currentAsset.code,
                      name: newName,
                      parentId: _currentAsset.parentId,
                      type: _currentAsset.type,
                      status: selectedStatus,
                      criticality: selectedCriticality,
                      serialNumber: serialCtrl.text.trim().isEmpty ? null : serialCtrl.text.trim(),
                      specs: _currentAsset.specs,
                      taskTemplate: _currentAsset.taskTemplate,
                      qrCode: _currentAsset.qrCode,
                      purchasePrice: _currentAsset.purchasePrice,
                      manufactureYear: _currentAsset.manufactureYear,
                      manufacturer: _currentAsset.manufacturer,
                      supplier: _currentAsset.supplier,
                    );
                  });
                  widget.onSaved();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật thông tin thiết bị thành công')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm and Retire Asset
  void _confirmRetireAsset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Thanh lý ${_currentAsset.name}?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: Text(
          'Xác nhận để mở quy trình tháo dỡ và thanh lý hoàn kho cho thiết bị ${_currentAsset.code} (${_currentAsset.name}). Thao tác này không thể hoàn tác.',
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
              setState(() => _isSaving = true);
              final ok = await _moduleService.retireAsset(_currentAsset.code);
              setState(() => _isSaving = false);
              if (ok) {
                if (mounted) {
                  Navigator.pop(context);
                  widget.onAssetDeleted?.call();
                  widget.onSaved();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thanh lý thiết bị ${_currentAsset.code} thành công')),
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

  // Show QR Modal
  void _showQrDialog() {
    final qrCodeStr = _currentAsset.qrCode ?? 'QR-AMM-${_currentAsset.code}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2_rounded, size: 140, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentAsset.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Mã quét: $qrCodeStr',
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                'Sẵn sàng quét hiện trường',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // HEADER SECTION (Matching Web 1:1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges & Close Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        _currentAsset.typeLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        _currentAsset.statusLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _currentAsset.criticalityLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Asset Name
                Text(
                  _currentAsset.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),

                // Subtitle: Mã thiết bị & Serial
                Row(
                  children: [
                    const Text('Mã thiết bị: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text(
                      _currentAsset.code,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    if (_currentAsset.serialNumber != null && _currentAsset.serialNumber!.isNotEmpty) ...[
                      const Text(' · Serial: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text(
                        _currentAsset.serialNumber!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons Row (Chỉnh sửa, + Thêm thiết bị con, In mã QR, Thanh lý)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: _openEditBasicDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Chỉnh sửa', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          InventoryAssetCreateDialog.show(
                            context,
                            parentAsset: _currentAsset,
                            onCreated: widget.onSaved,
                          );
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Thêm thiết bị con', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _showQrDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('In mã QR', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _confirmRetireAsset,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Thanh lý', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5 SUB-TABS NAVIGATION
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF1D4ED8),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1D4ED8),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: _tabLabels.map((title) => Tab(text: title)).toList(),
            ),
          ),

          // TAB VIEWS
          Expanded(
            child: _isSaving
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      AssetOverviewTabView(
                        asset: _currentAsset,
                        moduleService: _moduleService,
                        onSaved: widget.onSaved,
                      ),
                      AssetDocumentsTabView(
                        assetCode: _currentAsset.code,
                        moduleService: _moduleService,
                      ),
                      AssetHistoryTabView(
                        assetCode: _currentAsset.code,
                        moduleService: _moduleService,
                      ),
                      AssetBomTabView(
                        assetCode: _currentAsset.code,
                        moduleService: _moduleService,
                      ),
                      AssetMaintenancePlanTabView(
                        taskTemplate: _currentAsset.taskTemplate,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
