import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

class _DocumentLineDraft {
  InventoryItem? selectedItem;
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();
  final TextEditingController lotController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    lotController.dispose();
    serialController.dispose();
    noteController.dispose();
  }
}

class InventoryDocumentCreateDialog extends StatefulWidget {
  final List<InventoryItem> items;
  final List<WarehouseItem> warehouses;
  final StockDocumentItem? documentToEdit;
  final VoidCallback? onCreated;

  const InventoryDocumentCreateDialog({
    super.key,
    required this.items,
    required this.warehouses,
    this.documentToEdit,
    this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required List<InventoryItem> items,
    required List<WarehouseItem> warehouses,
    StockDocumentItem? documentToEdit,
    VoidCallback? onCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryDocumentCreateDialog(
        items: items,
        warehouses: warehouses,
        documentToEdit: documentToEdit,
        onCreated: onCreated,
      ),
    );
  }

  @override
  State<InventoryDocumentCreateDialog> createState() => _InventoryDocumentCreateDialogState();
}

class _InventoryDocumentCreateDialogState extends State<InventoryDocumentCreateDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();
  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, String>> _typeOptions = [
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

  late String _selectedType;
  late String _selectedWarehouse;
  String _selectedTargetWarehouse = '';
  DateTime _documentDate = DateTime.now();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<_DocumentLineDraft> _lines = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.documentToEdit != null) {
      final doc = widget.documentToEdit!;
      _selectedType = doc.docType;
      _selectedWarehouse = doc.warehouseCode;
      _selectedTargetWarehouse = doc.targetWarehouseCode ?? '';
      _documentDate = DateTime.tryParse(doc.documentDate) ?? DateTime.now();
      _sourceController.text = doc.sourceType ?? '';
      _noteController.text = doc.note ?? '';

      for (final line in doc.lines) {
        final draft = _DocumentLineDraft();
        draft.selectedItem = widget.items.firstWhere(
          (it) => it.code == line.materialCode,
          orElse: () => InventoryItem(
            code: line.materialCode,
            name: line.materialName,
            unit: line.unit,
            available: 0.0,
          ),
        );
        draft.quantityController.text = line.quantity.toString();
        if (line.unitPrice != null && line.unitPrice! > 0) {
          draft.priceController.text = line.unitPrice.toString();
        }
        if (line.lotNumber != null && line.lotNumber!.isNotEmpty) {
          draft.lotController.text = line.lotNumber!;
        }
        _lines.add(draft);
      }
      if (_lines.isEmpty) {
        _addNewLine();
      }
    } else {
      _selectedType = _typeOptions.first['value']!;
      _selectedWarehouse = widget.warehouses.isNotEmpty ? widget.warehouses.first.code : 'KHO-1';
      if (widget.warehouses.length > 1) {
        _selectedTargetWarehouse = widget.warehouses[1].code;
      }
      _addNewLine();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sourceController.dispose();
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addNewLine() {
    setState(() {
      _lines.add(_DocumentLineDraft());
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      final removed = _lines.removeAt(index);
      removed.dispose();
    });
  }

  double get _totalQuantity {
    double total = 0.0;
    for (final l in _lines) {
      total += double.tryParse(l.quantityController.text.trim()) ?? 0.0;
    }
    return total;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _documentDate = picked);
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSubmit({required bool postImmediately}) async {
    setState(() => _errorMessage = null);

    // 1. Validate warehouse
    if (_selectedWarehouse.isEmpty) {
      _showError('Vui lòng chọn kho lưu trữ.');
      return;
    }

    if (_selectedType == 'TRANSFER') {
      if (_selectedTargetWarehouse.isEmpty) {
        _showError('Chứng từ điều chuyển phải có kho đến.');
        return;
      }
      if (_selectedTargetWarehouse == _selectedWarehouse) {
        _showError('Kho xuất và kho đến phải khác nhau.');
        return;
      }
    }

    // 2. Validate lines
    final List<Map<String, dynamic>> payloadLines = [];
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final lineNo = i + 1;

      if (line.selectedItem == null) {
        _showError('Dòng $lineNo: Vui lòng chọn mặt hàng.');
        return;
      }

      final qty = double.tryParse(line.quantityController.text.trim()) ?? 0.0;
      if (qty <= 0) {
        _showError('Dòng $lineNo: Số lượng phải lớn hơn 0.');
        return;
      }

      final lotText = line.lotController.text.trim();

      double? unitCost;
      if (line.priceController.text.trim().isNotEmpty) {
        unitCost = double.tryParse(line.priceController.text.trim().replaceAll(',', ''));
        if (unitCost != null && unitCost < 0) {
          _showError('Dòng $lineNo: Đơn giá không được âm.');
          return;
        }
      }

      final Map<String, dynamic> lineMap = {
        'materialCode': line.selectedItem!.code,
        'quantity': qty,
      };

      if (unitCost != null) {
        lineMap['unitCost'] = unitCost;
      }

      if (lotText.isNotEmpty) {
        lineMap['lot'] = {'lotNo': lotText};
      }

      // Serial tạm ẩn không gửi

      final noteText = line.noteController.text.trim();
      if (noteText.isNotEmpty) {
        lineMap['note'] = noteText;
      }

      payloadLines.add(lineMap);
    }

    setState(() => _isSubmitting = true);

    final dateStr =
        '${_documentDate.year}-${_documentDate.month.toString().padLeft(2, '0')}-${_documentDate.day.toString().padLeft(2, '0')}';

    final StockDocumentItem? res;
    if (widget.documentToEdit != null) {
      res = await _service.updateStockDocument(
        widget.documentToEdit!.id,
        warehouseCode: _selectedWarehouse,
        targetWarehouseCode: _selectedType == 'TRANSFER' ? _selectedTargetWarehouse : null,
        documentDate: dateStr,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        lines: payloadLines,
      );
      if (res != null && postImmediately) {
        await _service.postStockDocument(widget.documentToEdit!.id);
      }
    } else {
      res = await _service.createStockDocument(
        docType: _selectedType,
        warehouseCode: _selectedWarehouse,
        targetWarehouseCode: _selectedType == 'TRANSFER' ? _selectedTargetWarehouse : null,
        documentDate: dateStr,
        sourceType: _sourceController.text.trim().isNotEmpty ? _sourceController.text.trim() : null,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        postImmediately: postImmediately,
        lines: payloadLines,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            postImmediately
                ? 'Đã lập và ghi sổ chứng từ ${res.code} thành công.'
                : 'Đã lưu nháp chứng từ ${res.code} thành công.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onCreated?.call();
    } else {
      _showError(_service.lastInventoryError ?? 'Không thể tạo chứng từ. Vui lòng kiểm tra lại thông tin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
          maxWidth: 680,
        ),
        child: Column(
          children: [
            // Header Bar matching Web: X  Lập chứng từ kho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.documentToEdit != null ? 'Sửa chứng từ \${widget.documentToEdit!.code}' : 'Lập chứng từ kho',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IN-DIALOG PROMINENT ERROR BANNER
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 20, color: Color(0xFFDC2626)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _errorMessage = null),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Loại chứng từ
                    _buildFieldLabel('Loại chứng từ', isRequired: true),
                    const SizedBox(height: 5),
                    SearchableDropdownField<Map<String, String>>(
                      value: _typeOptions.firstWhere(
                        (opt) => opt['value'] == _selectedType,
                        orElse: () => _typeOptions.first,
                      ),
                      items: _typeOptions,
                      hintText: 'Chọn loại chứng từ...',
                      itemLabel: (opt) => opt['label'] ?? '',
                      showClear: false,
                      onChanged: (opt) => setState(() => _selectedType = opt['value']!),
                      maxHeight: 240,
                    ),
                    const SizedBox(height: 12),

                    // 2. Kho & Ngày chứng từ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kho
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Kho', isRequired: true),
                              const SizedBox(height: 5),
                              SearchableDropdownField<String>(
                                value: _selectedWarehouse,
                                items: widget.warehouses.map((w) => w.code).toList(),
                                hintText: 'Chọn kho...',
                                itemLabel: (code) {
                                  final wh = widget.warehouses.firstWhere(
                                    (w) => w.code == code,
                                    orElse: () => WarehouseItem(id: '', code: code, name: code),
                                  );
                                  return '${wh.code} - ${wh.name}';
                                },
                                showClear: false,
                                onChanged: (code) => setState(() => _selectedWarehouse = code),
                                maxHeight: 220,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Ngày chứng từ
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Ngày chứng từ', isRequired: true),
                              const SizedBox(height: 5),
                              InkWell(
                                onTap: _selectDate,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          Formatters.formatDate(_documentDate),
                                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Nếu là điều chuyển kho, hiện thêm Kho đến
                    if (_selectedType == 'TRANSFER') ...[
                      _buildFieldLabel('Kho đến (kho tiếp nhận)', isRequired: true),
                      const SizedBox(height: 5),
                      SearchableDropdownField<String>(
                        value: _selectedTargetWarehouse,
                        items: widget.warehouses.map((w) => w.code).toList(),
                        hintText: 'Chọn kho đến...',
                        itemLabel: (code) {
                          final wh = widget.warehouses.firstWhere(
                            (w) => w.code == code,
                            orElse: () => WarehouseItem(id: '', code: code, name: code),
                          );
                          return '${wh.code} - ${wh.name}';
                        },
                        showClear: false,
                        onChanged: (code) => setState(() => _selectedTargetWarehouse = code),
                        maxHeight: 220,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 3. Nguồn (loại chứng từ gốc)
                    _buildFieldLabel('Nguồn (loại chứng từ gốc)'),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _sourceController,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _inputDecoration('Ví dụ: đơn mua PO-001, lệnh xuất PX-002...'),
                    ),
                    const SizedBox(height: 12),

                    // 4. Ghi chú
                    _buildFieldLabel('Ghi chú'),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _inputDecoration('Nhập ghi chú cho chứng từ này...'),
                    ),
                    const SizedBox(height: 20),

                    // 5. Dòng chứng từ Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dòng chứng từ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        TextButton.icon(
                          onPressed: _addNewLine,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm dòng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lines List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final line = _lines[idx];

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row Top: # Line & Delete Button
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dòng #${idx + 1}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  ),
                                  const Spacer(),
                                  if (_lines.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeLine(idx),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Item Selector (SearchableDropdownField matching Web)
                              _buildFieldLabel('Mặt hàng', isRequired: true),
                              const SizedBox(height: 5),
                              SearchableDropdownField<InventoryItem>(
                                value: line.selectedItem,
                                items: widget.items,
                                hintText: 'Chọn mặt hàng...',
                                itemLabel: (item) => '${item.code} - ${item.name}',
                                itemSubtitle: (item) => 'ĐVT: ${item.unit}',
                                showClear: false,
                                onChanged: (item) {
                                  setState(() {
                                    line.selectedItem = item;
                                  });
                                },
                                maxHeight: 220,
                              ),
                              const SizedBox(height: 10),

                              // Quantity & Unit Price Row
                              Row(
                                children: [
                                  // Số lượng
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Số lượng', isRequired: true),
                                        const SizedBox(height: 5),
                                        TextField(
                                          controller: line.quantityController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                          decoration: _inputDecoration('1').copyWith(
                                            suffixText: line.selectedItem?.unit ?? 'Đơn vị',
                                            suffixStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Đơn giá
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Đơn giá'),
                                        const SizedBox(height: 5),
                                        TextField(
                                          controller: line.priceController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                          decoration: _inputDecoration('Bình quân'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Lot & Serial Row (Serial tạm disable)
                              Row(
                                children: [
                                  // Lô
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Lô'),
                                        const SizedBox(height: 5),
                                        TextField(
                                          controller: line.lotController,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                          decoration: _inputDecoration('Mã lô (để trống nếu không dùng)'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Serial (Tạm disable)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Serial'),
                                        const SizedBox(height: 5),
                                        TextField(
                                          controller: line.serialController,
                                          enabled: false,
                                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                          decoration: _inputDecoration('Tạm khóa nhập serial').copyWith(
                                            fillColor: const Color(0xFFF1F5F9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Ghi chú dòng
                              _buildFieldLabel('Ghi chú dòng'),
                              const SizedBox(height: 5),
                              TextField(
                                controller: line.noteController,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: _inputDecoration('Ghi chú riêng cho mặt hàng này...'),
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
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Footer Matching Web: [N dòng - tổng số lượng X]   [Đóng] [Lưu nháp] [Lưu và ghi sổ]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_lines.length} dòng - tổng số lượng ${Formatters.formatCurrency(_totalQuantity, showSymbol: false)}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Đóng', style: TextStyle(fontSize: 12.5)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _handleSubmit(postImmediately: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Lưu nháp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _handleSubmit(postImmediately: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu và ghi sổ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
