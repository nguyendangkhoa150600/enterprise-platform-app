import '../../core/utils/formatters.dart';
import '../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_document_detail_sheet.dart';
import 'components/inventory_document_create_dialog.dart';

class InventoryDocumentsScreen extends StatefulWidget {
  final String? initialStatus;
  final String title;
  final String subtitle;

  const InventoryDocumentsScreen({
    super.key,
    this.initialStatus,
    this.title = 'Chứng từ kho',
    this.subtitle = 'Danh sách phiếu nhập, xuất & luân chuyển kho',
  });

  @override
  State<InventoryDocumentsScreen> createState() => _InventoryDocumentsScreenState();
}

class _InventoryDocumentsScreenState extends State<InventoryDocumentsScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();

  bool get isApprovalMode => widget.initialStatus == 'PENDING';

  List<StockDocumentItem> _documents = [];
  List<WarehouseItem> _warehouses = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedType = '';
  String _selectedStatus = '';
  String _selectedWarehouse = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  static const List<Map<String, String>> _typeOptions = [
    {'value': '', 'label': 'Mọi loại'},
    {'value': 'RECEIPT_PURCHASE', 'label': 'Nhập mua hàng'},
    {'value': 'RECEIPT_SALES_RETURN', 'label': 'Nhập trả hàng bán'},
    {'value': 'RECEIPT_TRANSFER', 'label': 'Nhập điều chuyển'},
    {'value': 'RECEIPT_OTHER', 'label': 'Nhập khác'},
    {'value': 'ISSUE_SALES', 'label': 'Xuất bán hàng'},
    {'value': 'ISSUE_PROJECT', 'label': 'Xuất cho dự án'},
    {'value': 'ISSUE_WARRANTY', 'label': 'Xuất bảo hành'},
    {'value': 'ISSUE_TRANSFER', 'label': 'Xuất điều chuyển'},
    {'value': 'ISSUE_OTHER', 'label': 'Xuất khác'},
    {'value': 'ADJUSTMENT', 'label': 'Điều chỉnh tồn'},
    {'value': 'TRANSFER', 'label': 'Điều chuyển kho'},
  ];

  static const List<Map<String, String>> _statusOptions = [
    {'value': '', 'label': 'Mọi trạng thái'},
    {'value': 'POSTED', 'label': 'Đã ghi sổ'},
    {'value': 'DRAFT', 'label': 'Nháp'},
    {'value': 'PENDING', 'label': 'Chờ duyệt'},
    {'value': 'APPROVED', 'label': 'Đã duyệt'},
    {'value': 'REJECTED', 'label': 'Từ chối'},
    {'value': 'CANCELLED', 'label': 'Đã huỷ'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? '';
    _loadWarehouses();
    _loadData();
  }

  Future<void> _loadWarehouses() async {
    try {
      final whs = await _service.getWarehouses();
      if (mounted) setState(() => _warehouses = whs);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fromStr = _fromDate != null ? '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}' : null;
      final toStr = _toDate != null ? '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}' : null;

      final docs = await _service.getStockDocuments(
        docType: _selectedType.isNotEmpty ? _selectedType : null,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        warehouseCode: _selectedWarehouse.isNotEmpty ? _selectedWarehouse : null,
        fromDate: fromStr,
        toDate: toStr,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không tải được danh sách chứng từ: $e';
        });
      }
    }
  }

    Future<void> _handleApproveDoc(StockDocumentItem doc) async {
    final ok = await _service.approveStockDocument(doc.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã phê duyệt chứng từ ' + doc.code + ' thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Phê duyệt chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleRejectDoc(StockDocumentItem doc) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối chứng từ kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lý do từ chối chứng từ ' + doc.code + ':', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Lý do từ chối (bắt buộc)...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Xác nhận từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final ok = await _service.rejectStockDocument(doc.id, reason: reasonController.text.trim());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã từ chối chứng từ ' + doc.code + '.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Từ chối chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

Future<void> _openCreateDocumentDialog() async {
    final items = await _service.getInventoryItems();
    if (!mounted) return;
    await InventoryDocumentCreateDialog.show(
      context,
      items: items,
      warehouses: _warehouses,
      onCreated: () => _loadData(),
    );
  }

  Future<void> _selectDateRange(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
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
      ),
      body: Column(
        children: [
          // Filter & Action Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title, Count hint, Buttons (Matching Web 1:1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isApprovalMode)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chứng từ chờ duyệt',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_documents.length} chứng từ đang chờ',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${_documents.length} chứng từ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loadData,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Tải lại', style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        if (!isApprovalMode) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openCreateDocumentDialog,
                            icon: const Icon(Icons.note_add_outlined, size: 15),
                            label: const Text('Lập chứng từ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF021E73),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filters (Matching Web: On approval mode, only Loại & Kho)
                if (isApprovalMode) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter Loại
                      Expanded(
                        child: SearchableDropdownField<Map<String, String>>(
                          value: _typeOptions.firstWhere(
                            (opt) => opt['value'] == _selectedType,
                            orElse: () => _typeOptions.first,
                          ),
                          items: _typeOptions,
                          hintText: 'Mọi loại',
                          itemLabel: (opt) => opt['label'] ?? '',
                          showClear: _selectedType.isNotEmpty,
                          onClear: () {
                            setState(() => _selectedType = '');
                            _loadData();
                          },
                          onChanged: (opt) {
                            setState(() => _selectedType = opt['value'] ?? '');
                            _loadData();
                          },
                          maxHeight: 240,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Filter Kho
                      Expanded(
                        child: SearchableDropdownField<String>(
                          value: _selectedWarehouse,
                          items: ['', ..._warehouses.map((wh) => wh.code)],
                          hintText: 'Mọi kho',
                          itemLabel: (code) {
                            if (code.isEmpty) return 'Mọi kho';
                            final wh = _warehouses.firstWhere(
                              (w) => w.code == code,
                              orElse: () => WarehouseItem(id: '', code: code, name: code),
                            );
                            return '${wh.code} - ${wh.name}';
                          },
                          itemSubtitle: (code) {
                            if (code.isEmpty) return null;
                            final wh = _warehouses.firstWhere(
                              (w) => w.code == code,
                              orElse: () => WarehouseItem(id: '', code: code, name: code),
                            );
                            return wh.location;
                          },
                          showClear: _selectedWarehouse.isNotEmpty,
                          onClear: () {
                            setState(() => _selectedWarehouse = '');
                            _loadData();
                          },
                          onChanged: (code) {
                            setState(() => _selectedWarehouse = code);
                            _loadData();
                          },
                          maxHeight: 240,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Standard Filters Row 1: Loại & Trạng thái
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SearchableDropdownField<Map<String, String>>(
                          value: _typeOptions.firstWhere(
                            (opt) => opt['value'] == _selectedType,
                            orElse: () => _typeOptions.first,
                          ),
                          items: _typeOptions,
                          hintText: 'Mọi loại',
                          itemLabel: (opt) => opt['label'] ?? '',
                          showClear: _selectedType.isNotEmpty,
                          onClear: () {
                            setState(() => _selectedType = '');
                            _loadData();
                          },
                          onChanged: (opt) {
                            setState(() => _selectedType = opt['value'] ?? '');
                            _loadData();
                          },
                          maxHeight: 240,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SearchableDropdownField<Map<String, String>>(
                          value: _statusOptions.firstWhere(
                            (opt) => opt['value'] == _selectedStatus,
                            orElse: () => _statusOptions.first,
                          ),
                          items: _statusOptions,
                          hintText: 'Mọi trạng thái',
                          itemLabel: (opt) => opt['label'] ?? '',
                          showClear: _selectedStatus.isNotEmpty,
                          onClear: () {
                            setState(() => _selectedStatus = '');
                            _loadData();
                          },
                          onChanged: (opt) {
                            setState(() => _selectedStatus = opt['value'] ?? '');
                            _loadData();
                          },
                          maxHeight: 240,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Standard Filters Row 2: Kho & Khoảng ngày
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SearchableDropdownField<String>(
                          value: _selectedWarehouse,
                          items: ['', ..._warehouses.map((wh) => wh.code)],
                          hintText: 'Mọi kho',
                          itemLabel: (code) {
                            if (code.isEmpty) return 'Mọi kho';
                            final wh = _warehouses.firstWhere(
                              (w) => w.code == code,
                              orElse: () => WarehouseItem(id: '', code: code, name: code),
                            );
                            return '${wh.code} - ${wh.name}';
                          },
                          itemSubtitle: (code) {
                            if (code.isEmpty) return null;
                            final wh = _warehouses.firstWhere(
                              (w) => w.code == code,
                              orElse: () => WarehouseItem(id: '', code: code, name: code),
                            );
                            return wh.location;
                          },
                          showClear: _selectedWarehouse.isNotEmpty,
                          onClear: () {
                            setState(() => _selectedWarehouse = '');
                            _loadData();
                          },
                          onChanged: (code) {
                            setState(() => _selectedWarehouse = code);
                            _loadData();
                          },
                          maxHeight: 240,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDateRange(true),
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _fromDate != null ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}' : 'Từ ngày',
                                    style: TextStyle(fontSize: 11, color: _fromDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDateRange(false),
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _toDate != null ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}' : 'Đến ngày',
                                    style: TextStyle(fontSize: 11, color: _toDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ),
                            ),
                            if (_fromDate != null || _toDate != null) ...[
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _fromDate = null;
                                    _toDate = null;
                                  });
                                  _loadData();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
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
                      )
                    : _documents.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 10),
                                  Text(
                                    isApprovalMode
                                        ? 'Không có chứng từ nào chờ duyệt.'
                                        : 'Không có chứng từ nào phù hợp với bộ lọc.',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _documents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final doc = _documents[index];
                                return _buildDocumentCard(doc);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(StockDocumentItem doc) {
    Color badgeBg;
    Color badgeFg;
    Color badgeBorder;

    switch (doc.status) {
      case 'POSTED':
        badgeBg = const Color(0xFFF0FDF4);
        badgeFg = const Color(0xFF15803D);
        badgeBorder = const Color(0xFFBBF7D0);
        break;
      case 'PENDING':
        badgeBg = const Color(0xFFFFFBEB);
        badgeFg = const Color(0xFFB45309);
        badgeBorder = const Color(0xFFFDE68A);
        break;
      case 'DRAFT':
        badgeBg = const Color(0xFFF5F3FF);
        badgeFg = const Color(0xFF6D28D9);
        badgeBorder = const Color(0xFFDDD6FE);
        break;
      case 'APPROVED':
        badgeBg = const Color(0xFFEFF6FF);
        badgeFg = const Color(0xFF1D4ED8);
        badgeBorder = const Color(0xFFBFDBFE);
        break;
      case 'REJECTED':
        badgeBg = const Color(0xFFFEF2F2);
        badgeFg = const Color(0xFFB91C1C);
        badgeBorder = const Color(0xFFFECACA);
        break;
      default:
        badgeBg = const Color(0xFFF8FAFC);
        badgeFg = const Color(0xFF64748B);
        badgeBorder = const Color(0xFFE2E8F0);
    }

    return InkWell(
      onTap: () => InventoryDocumentDetailSheet.show(context, doc, allDocuments: _documents, onChanged: _loadData),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
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
          children: [
            // Row 1: Code & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  doc.code,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    '• ${doc.statusLabel}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeFg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Type & Warehouse
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  doc.docTypeLabel,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    doc.warehouseDisplay,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Date, Lines & Source
            Row(
              children: [
                Text(
                  Formatters.formatDate(doc.documentDate),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                Text(
                  '${doc.lines.length} dòng / ${Formatters.formatCurrency(doc.totalQuantity, showSymbol: false)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Text(
                  doc.sourceLabel,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            if (doc.note != null && doc.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: ${doc.note}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isApprovalMode) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _handleRejectDoc(doc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Từ chối', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleApproveDoc(doc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: const Text('Phê duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

