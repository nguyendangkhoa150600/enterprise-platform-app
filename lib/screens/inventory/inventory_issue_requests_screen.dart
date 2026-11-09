import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../models/inventory_models.dart';
import '../../services/module_business_service.dart';
import '../../theme/colors.dart';
import 'components/inventory_document_create_dialog.dart';
import 'components/inventory_document_detail_sheet.dart';

class InventoryIssueRequestsScreen extends StatefulWidget {
  const InventoryIssueRequestsScreen({super.key});

  @override
  State<InventoryIssueRequestsScreen> createState() => _InventoryIssueRequestsScreenState();
}

class _InventoryIssueRequestsScreenState extends State<InventoryIssueRequestsScreen> {
  final ModuleBusinessService _service = ModuleBusinessService();

  List<StockDocumentItem> _documents = [];
  List<WarehouseItem> _warehouses = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedType = '';
  String _selectedSource = '';
  String _selectedWarehouse = '';

  static const List<Map<String, String>> _typeOptions = [
    {'value': '', 'label': 'Xuất bán và xuất bảo hành'},
    {'value': 'ISSUE_SALES', 'label': 'Xuất bán hàng'},
    {'value': 'ISSUE_WARRANTY', 'label': 'Xuất bảo hành'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final whs = await _service.getWarehouses();
      if (mounted) {
        _warehouses = whs;
      }
    } catch (_) {}

    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Yêu cầu xuất từ đơn bán: lọc status DRAFT, docTypes ISSUE_SALES,ISSUE_WARRANTY
      final docs = await _service.getStockDocuments(
        docType: _selectedType.isNotEmpty ? _selectedType : null,
        docTypes: _selectedType.isEmpty ? 'ISSUE_SALES,ISSUE_WARRANTY' : null,
        status: 'DRAFT',
        warehouseCode: _selectedWarehouse.isNotEmpty ? _selectedWarehouse : null,
        sourceType: _selectedSource.isNotEmpty ? _selectedSource : null,
        limit: 200,
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
          _errorMessage = 'Không tải được danh sách yêu cầu xuất: $e';
        });
      }
    }
  }

  List<StockDocumentItem> get _filteredDocuments {
    if (_selectedSource.isEmpty) return _documents;
    return _documents.where((d) => (d.sourceType ?? '') == _selectedSource).toList();
  }

  List<Map<String, String>> get _sourceOptions {
    final values = _documents
        .map((d) => d.sourceType ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    return [
      {'value': '', 'label': 'Mọi nguồn'},
      ...values.map((v) {
        String label = v;
        switch (v) {
          case 'crm_order':
          case 'crm_sales_order':
            label = 'Đơn bán';
            break;
          case 'crm_delivery':
            label = 'Đợt giao hàng';
            break;
          case 'crm_warranty':
            label = 'Bảo hành';
            break;
          case 'crm_return':
            label = 'Trả hàng';
            break;
        }
        return {'value': v, 'label': label};
      }),
    ];
  }

  Future<void> _handlePost(StockDocumentItem doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi sổ yêu cầu xuất kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Xác nhận ghi sổ chứng từ xuất kho ${doc.code}? Hệ thống CRM sẽ ghi nhận số lượng đã giao và serial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận ghi sổ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.postStockDocument(doc.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ghi sổ chứng từ ${doc.code} thành công; CRM đã nhận số đã giao.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadDocuments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Ghi sổ chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleCancel(StockDocumentItem doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ yêu cầu xuất kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn huỷ chứng từ ${doc.code}? Sau khi huỷ, chứng từ này sẽ chuyển sang trạng thái Đã huỷ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận huỷ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.cancelStockDocument(doc.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã huỷ chứng từ ${doc.code} thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadDocuments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Huỷ chứng từ thất bại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleEdit(StockDocumentItem doc) async {
    final items = await _service.getInventoryItems();
    if (!mounted) return;
    await InventoryDocumentCreateDialog.show(
      context,
      items: items,
      warehouses: _warehouses,
      documentToEdit: doc,
      onCreated: () => _loadDocuments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredDocuments;

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
              'Yêu cầu xuất từ đơn bán',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Đơn bán hàng cần xuất kho và giao hàng',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Header Card (Matching Web 1:1)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: Title, Hint count, Tải lại button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yêu cầu xuất từ đơn bán',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${visible.length} chứng từ nháp chờ xuất',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loadDocuments,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Tải lại', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filters Row 1: Loại (SearchableDropdownField)
                SearchableDropdownField<Map<String, String>>(
                  value: _typeOptions.firstWhere(
                    (opt) => opt['value'] == _selectedType,
                    orElse: () => _typeOptions.first,
                  ),
                  items: _typeOptions,
                  hintText: 'Xuất bán và xuất bảo hành',
                  itemLabel: (opt) => opt['label'] ?? '',
                  showClear: _selectedType.isNotEmpty,
                  onClear: () {
                    setState(() => _selectedType = '');
                    _loadDocuments();
                  },
                  onChanged: (opt) {
                    setState(() => _selectedType = opt['value'] ?? '');
                    _loadDocuments();
                  },
                  maxHeight: 240,
                ),
                const SizedBox(height: 8),

                // Filters Row 2: Nguồn & Kho (SearchableDropdownField)
                Row(
                  children: [
                    // Nguồn
                    Expanded(
                      child: SearchableDropdownField<Map<String, String>>(
                        value: _sourceOptions.firstWhere(
                          (opt) => opt['value'] == _selectedSource,
                          orElse: () => _sourceOptions.first,
                        ),
                        items: _sourceOptions,
                        hintText: 'Mọi nguồn',
                        itemLabel: (opt) => opt['label'] ?? '',
                        showClear: _selectedSource.isNotEmpty,
                        onClear: () {
                          setState(() => _selectedSource = '');
                        },
                        onChanged: (opt) {
                          setState(() => _selectedSource = opt['value'] ?? '');
                        },
                        maxHeight: 240,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Kho
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
                          _loadDocuments();
                        },
                        onChanged: (code) {
                          setState(() => _selectedWarehouse = code);
                          _loadDocuments();
                        },
                        maxHeight: 240,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body List
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
                                onPressed: _loadDocuments,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.outbox_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 10),
                                  Text(
                                    'Không có yêu cầu xuất nào đang chờ.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDocuments,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final doc = visible[index];
                                return _buildIssueRequestCard(doc);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueRequestCard(StockDocumentItem doc) {
    return InkWell(
      onTap: () => InventoryDocumentDetailSheet.show(
        context,
        doc,
        allDocuments: _documents,
        onChanged: _loadDocuments,
      ),
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
            // Row 1: Code & Status Badge (• Nháp)
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
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: const Text(
                    '• Nháp',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: DocType & Warehouse
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
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                if (doc.sourceId != null && doc.sourceId!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${doc.sourceId!.length > 8 ? doc.sourceId!.substring(0, 8) : doc.sourceId!})',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                  ),
                ],
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

            // Action Buttons: Sửa, Ghi sổ, Huỷ chứng từ (Matching Web 1:1)
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _handleEdit(doc),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Sửa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handlePost(doc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: const Text('Ghi sổ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handleCancel(doc),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Huỷ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

