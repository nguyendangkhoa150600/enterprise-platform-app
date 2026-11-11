import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';
import 'inventory_material_create_dialog.dart';
import 'inventory_quick_material_dialog.dart';

class InventoryMovementDialog extends StatefulWidget {
  final List<InventoryItem> items;
  final String? initialKind; // 'receipt', 'issue', 'transfer'
  final Future<void> Function()? onSubmitted;

  const InventoryMovementDialog({
    super.key,
    required this.items,
    this.initialKind,
    this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required List<InventoryItem> items,
    String? initialKind,
    Future<void> Function()? onSubmitted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryMovementDialog(
        items: items,
        initialKind: initialKind,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<InventoryMovementDialog> createState() => _InventoryMovementDialogState();
}

class _InventoryMovementDialogState extends State<InventoryMovementDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();

  late String _kind; // 'receipt', 'issue', 'transfer'
  WarehouseItem? _selectedWarehouse;
  WarehouseItem? _targetWarehouse; // for transfer
  final TextEditingController _reasonController = TextEditingController();

  // Quy trình liên kết mở Work Order
  List<ProcedureDefinition> _procedures = [];
  ProcedureDefinition? _selectedProcedure;

  // Tệp chứng từ đính kèm
  PlatformFile? _attachedFile;
  int? _attachedFileSize;

  // Selected item line draft
  late List<InventoryItem> _availableItems;
  InventoryItem? _selectedDraftItem;
  final TextEditingController _draftQtyController = TextEditingController(text: '1');
  final TextEditingController _draftPriceController = TextEditingController();

  final List<({InventoryItem item, double quantity, double? unitCost})> _lines = [];

  List<WarehouseItem> _warehouses = [];
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? 'receipt';
    _availableItems = List.from(widget.items);
    _loadInitialData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _draftQtyController.dispose();
    _draftPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _service.getWarehouses(),
        _service.getProcedureWorkspace(),
      ]);

      final warehouses = results[0] as List<WarehouseItem>;
      final procWs = results[1] as ProcedureWorkspaceData;

      if (mounted) {
        setState(() {
          _warehouses = warehouses;
          if (_warehouses.isNotEmpty) {
            _selectedWarehouse = _warehouses.first;
            if (_warehouses.length > 1) {
              _targetWarehouse = _warehouses[1];
            }
          }
          final published = procWs.definitions.where((d) => d.status == 'published').toList();
          _procedures = published.isNotEmpty ? published : procWs.definitions;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (file != null && mounted) {
        final size = file.lengthSync() ?? await file.length();
        setState(() {
          _attachedFile = file;
          _attachedFileSize = size;
        });
      }
    } catch (e) {
      debugPrint('Lỗi chọn tệp: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openAddMaterialDialog() async {
    await InventoryQuickMaterialDialog.show(
      context,
      onCreated: (newItem) async {
        if (!mounted) return;
        setState(() {
          // Tự động thêm trực tiếp vào danh sách mặt hàng của phiếu (khớp 1:1 với Web)
          _lines.add((
            item: newItem,
            quantity: 1.0,
            unitCost: null,
          ));
          if (!_availableItems.any((it) => it.code == newItem.code)) {
            _availableItems.insert(0, newItem);
          }
        });
      },
    );
  }

  void _handleAddLine() {
    if (_selectedDraftItem == null) return;
    final qty = double.tryParse(_draftQtyController.text.trim()) ?? 1.0;
    if (qty <= 0) return;
    final price = double.tryParse(_draftPriceController.text.trim().replaceAll(',', '').replaceAll('.', ''));

    setState(() {
      _lines.add((
        item: _selectedDraftItem!,
        quantity: qty,
        unitCost: price,
      ));
      _selectedDraftItem = null;
      _draftQtyController.text = '1';
      _draftPriceController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Lý do thực hiện / Số hóa đơn / Số lệnh.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Kho tác nghiệp.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_kind == 'transfer' && _targetWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Kho đích nhận điều chuyển.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất một mặt hàng vào phiếu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    bool overallSuccess = true;

    try {
      // Đảm bảo các mã vật tư mới tạo đã tồn tại trong danh mục trước khi phát sinh giao dịch (chuẩn 1:1 Web)
      for (final line in _lines) {
        try {
          await _service.createMaterial({
            'code': line.item.code,
            'name': line.item.name,
            'category': 'SPARE_PART',
            'unit': line.item.unit,
            'minStock': line.item.minStock ?? 0.0,
            'kind': 'STOCK',
            'isSerialized': false,
          });
        } catch (_) {}
      }

      for (final line in _lines) {
        bool ok = false;
        if (_kind == 'receipt') {
          ok = await _service.receiveStock({
            'warehouseCode': _selectedWarehouse!.code,
            'materialCode': line.item.code,
            'quantity': line.quantity,
            if (line.unitCost != null) 'unitCost': line.unitCost,
            'note': reason,
          });
        } else if (_kind == 'issue') {
          ok = await _service.issueStock({
            'warehouseCode': _selectedWarehouse!.code,
            'materialCode': line.item.code,
            'quantity': line.quantity,
            'note': reason,
          });
        } else if (_kind == 'transfer') {
          ok = await _service.transferStock({
            'fromWarehouseCode': _selectedWarehouse!.code,
            'toWarehouseCode': _targetWarehouse!.code,
            'materialCode': line.item.code,
            'quantity': line.quantity,
            'note': reason,
          });
        }
        if (!ok) overallSuccess = false;
      }

      // Mở Work Order bên Quy trình nếu có chọn quy trình liên kết
      if (_selectedProcedure != null && overallSuccess) {
        try {
          final kindTitle = _kind == 'receipt' ? 'Nhập kho' : (_kind == 'issue' ? 'Xuất kho' : 'Điều chuyển kho');
          await _service.createProcedureInstance(
            definitionId: _selectedProcedure!.id,
            title: '[$kindTitle] $reason',
          );
        } catch (e) {
          debugPrint('Lỗi mở quy trình liên kết: $e');
        }
      }
    } catch (_) {
      overallSuccess = false;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (overallSuccess) {
      Navigator.of(context).pop();
      final kindText = _kind == 'receipt' ? 'nhập' : (_kind == 'issue' ? 'xuất' : 'điều chuyển');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghi nhận phiếu $kindText kho thành công.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      widget.onSubmitted?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi phát sinh khi ghi nhận phiếu kho. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _kind == 'receipt'
        ? 'Phiếu Nhập Kho Vật Tư'
        : (_kind == 'issue' ? 'Phiếu Xuất Kho Vật Tư' : 'Phiếu Điều Chuyển Kho');

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ghi nhận lô hàng mới, thiết bị mua sắm hoặc hoàn kho đa vật tư kèm đơn giá.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Tabs Segment
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab('receipt', 'Nhập kho'),
                    _buildSegmentTab('issue', 'Xuất kho'),
                    _buildSegmentTab('transfer', 'Điều chuyển kho'),
                  ],
                ),
              ),
            ),

            // Form Body
            Expanded(
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Warehouses Selectors
                          if (_kind == 'transfer') ...[
                            _buildFieldLabel('Kho xuất (nguồn)', isRequired: true),
                            const SizedBox(height: 6),
                            SearchableDropdownField<WarehouseItem>(
                              value: _selectedWarehouse,
                              items: _warehouses,
                              hintText: 'Chọn kho xuất...',
                              itemLabel: (w) => '${w.name} (${w.code})',
                              itemSubtitle: (w) => 'Mã: ${w.code}',
                              onChanged: (w) => setState(() => _selectedWarehouse = w),
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Kho nhận (đích)', isRequired: true),
                            const SizedBox(height: 6),
                            SearchableDropdownField<WarehouseItem>(
                              value: _targetWarehouse,
                              items: _warehouses,
                              hintText: 'Chọn kho đích...',
                              itemLabel: (w) => '${w.name} (${w.code})',
                              itemSubtitle: (w) => 'Mã: ${w.code}',
                              onChanged: (w) => setState(() => _targetWarehouse = w),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            _buildFieldLabel(
                              _kind == 'receipt' ? 'Kho tiếp nhận' : 'Kho xuất hàng',
                              isRequired: true,
                            ),
                            const SizedBox(height: 6),
                            SearchableDropdownField<WarehouseItem>(
                              value: _selectedWarehouse,
                              items: _warehouses,
                              hintText: 'Chọn kho...',
                              itemLabel: (w) => '${w.name} (${w.code})',
                              itemSubtitle: (w) => 'Mã: ${w.code}',
                              onChanged: (w) => setState(() => _selectedWarehouse = w),
                            ),
                            const SizedBox(height: 12),

                            // Quy trình liên kết mở Work Order
                            _buildFieldLabel('Quy trình liên kết mở Work Order'),
                            const SizedBox(height: 6),
                            SearchableDropdownField<ProcedureDefinition>(
                              value: _selectedProcedure,
                              items: _procedures,
                              hintText: _procedures.isEmpty
                                  ? '— Không có quy trình —'
                                  : '— Không mở Work Order (tự chọn) —',
                              itemLabel: (p) => p.name,
                              itemSubtitle: (p) => 'Mã: ${p.code}${p.category != null ? ' • ${p.category}' : ''}',
                              showClear: true,
                              onClear: () => setState(() => _selectedProcedure = null),
                              onChanged: (p) => setState(() => _selectedProcedure = p),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Reason input
                          _buildFieldLabel('Lý do thực hiện / Số hoá đơn / Số lệnh', isRequired: true),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _reasonController,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                            decoration: _inputDecoration(
                              _kind == 'receipt'
                                  ? 'VD: Nhập theo Hóa đơn HD-2026-118, hoặc Xuất thay thế theo Lệnh PR-082…'
                                  : (_kind == 'issue'
                                      ? 'VD: Nhập theo Hóa đơn HD-2026-118, hoặc Xuất thay thế theo Lệnh PR-082…'
                                      : 'VD: Điều chuyển tăng cường thiết bị…'),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tệp chứng từ đính kèm
                          _buildFieldLabel('Tệp chứng từ đính kèm (Biên bản giao nhận, Hoá đơn đỏ, Ảnh chụp...)'),
                          const SizedBox(height: 6),
                          if (_attachedFile == null)
                            InkWell(
                              onTap: _pickAttachment,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF2563EB)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Chọn tệp chứng từ từ thiết bị...',
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Hỗ trợ PDF, Excel, JPG, PNG tối đa 25MB',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _attachedFile!.name,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _formatFileSize(_attachedFileSize ?? _attachedFile!.lengthSync() ?? 0),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() {
                                      _attachedFile = null;
                                      _attachedFileSize = null;
                                    }),
                                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: 'Xoá tệp',
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),

                          // Section: Danh sách vật tư / hàng hoá
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Danh sách vật tư trên phiếu',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_lines.length}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _openAddMaterialDialog,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                      SizedBox(width: 2),
                                      Text(
                                        '+ Thêm vật tư mới',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Add line inputs
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SearchableDropdownField<InventoryItem>(
                                  value: _selectedDraftItem,
                                  items: _availableItems,
                                  hintText: 'Tìm mã hoặc tên vật tư để thêm…',
                                  itemLabel: (it) => '${it.name} (${it.code})',
                                  itemSubtitle: (it) => 'Mã: ${it.code} · ĐVT: ${it.unit}',
                                  onChanged: (it) => setState(() => _selectedDraftItem = it),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _draftQtyController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration('Số lượng'),
                                      ),
                                    ),
                                    if (_kind == 'receipt') ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _draftPriceController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _inputDecoration('Đơn giá (VND)'),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _selectedDraftItem == null ? null : _handleAddLine,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('+ Thêm'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Table / List of lines
                          if (_lines.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: Column(
                                children: const [
                                  Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 6),
                                  Text(
                                    'Chưa có vật tư nào trên phiếu',
                                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _lines.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final l = _lines[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.item.name,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Mã: ${l.item.code} · ${l.quantity} ${l.item.unit}${l.unitCost != null ? ' · ${l.unitCost} đ' : ''}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() => _lines.removeAt(index)),
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
            ),

            // Footer
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_lines.length} vật tư · ${_lines.fold(0.0, (s, l) => s + l.quantity)} đơn vị',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Xác nhận ${_kind == 'receipt' ? 'Nhập kho' : (_kind == 'issue' ? 'Xuất kho' : 'Điều chuyển')}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String id, String label) {
    final isSelected = _kind == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _kind = id;
          _lines.clear();
        }),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}

