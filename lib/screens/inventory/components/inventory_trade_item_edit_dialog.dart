import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

/// Modal Chỉnh sửa Hàng hóa / Dịch vụ (Đồng bộ 1:1 với Web TradeItemDrawer Sửa)
class InventoryTradeItemEditDialog extends StatefulWidget {
  final MaterialItem item;
  final ValueChanged<MaterialItem>? onSaved;

  const InventoryTradeItemEditDialog({
    super.key,
    required this.item,
    this.onSaved,
  });

  @override
  State<InventoryTradeItemEditDialog> createState() => _InventoryTradeItemEditDialogState();
}

class _InventoryTradeItemEditDialogState extends State<InventoryTradeItemEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final ModuleBusinessService _service = ModuleBusinessService();

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _categoryController;
  late TextEditingController _unitController;
  late TextEditingController _usageController;
  late TextEditingController _priceController;
  late TextEditingController _descController;

  late String _selectedGroup;
  bool _isSubmitting = false;

  // Catalog loaded from /api/inventory/v1/settings
  List<String> _goodsCategories = [];
  List<String> _serviceCategories = [];
  List<String> _usageModes = [];
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.name);
    _barcodeController = TextEditingController(text: item.barcode ?? '');
    final currentCat = item.tradeCategory ?? (item.category.isNotEmpty ? item.category : '');
    _categoryController = TextEditingController(text: currentCat);
    _unitController = TextEditingController(text: item.unit);
    _usageController = TextEditingController(text: item.tradeMode ?? '');
    _priceController = TextEditingController(
      text: item.salePrice != null && item.salePrice! > 0
          ? NumberFormat('#,###', 'vi_VN').format(item.salePrice)
          : '',
    );
    _descController = TextEditingController(text: item.description ?? '');

    _selectedGroup = item.isService ? 'SERVICE' : 'GOODS';
    _loadCatalogSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _usageController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogSettings() async {
    try {
      final settings = await _service.getInventorySettings();
      if (settings != null) {
        final tradeCat = settings['catalog.trade'];
        if (tradeCat is Map) {
          final val = tradeCat['value'] ?? tradeCat;
          if (val is Map) {
            final gc = val['goodsCategories'];
            if (gc is List) _goodsCategories = gc.map((e) => e.toString()).toList();
            final sc = val['serviceCategories'];
            if (sc is List) _serviceCategories = sc.map((e) => e.toString()).toList();
            final um = val['usageModes'];
            if (um is List) _usageModes = um.map((e) => e.toString()).toList();
          }
        }

        final unitCat = settings['catalog.unit'];
        if (unitCat is Map) {
          final val = unitCat['value'] ?? unitCat;
          if (val is Map) {
            final uList = val['units'];
            if (uList is List) _units = uList.map((e) => e.toString()).toList();
          }
        }
      }
    } catch (_) {}

    // Fallbacks if server returns empty list
    if (_goodsCategories.isEmpty) {
      _goodsCategories = ['HH_test', 'Vật tư tiêu hao', 'Thiết bị điện', 'Phụ tùng thay thế', 'Công cụ - Dụng cụ', 'Bảo hộ lao động'];
    }
    if (_serviceCategories.isEmpty) {
      _serviceCategories = ['DD_test', 'Dịch vụ kỹ thuật', 'Bảo dưỡng định kỳ', 'Lắp đặt & Đo kiểm'];
    }
    if (_usageModes.isEmpty) {
      _usageModes = ['Có thể bán và quà tặng', 'Chỉ bán', 'Chỉ tặng', 'Chỉ dùng nội bộ', 'Nhiều hình thức'];
    }
    if (_units.isEmpty) {
      _units = ['Cái', 'Bộ', 'Chiếc', 'Mét', 'Cuộn', 'Kg', 'Lít', 'Hộp', 'Thùng', 'Gói'];
    }

    // Đảm bảo dữ liệu hiện tại của item luôn có mặt trong danh sách lựa chọn
    final currentCat = _categoryController.text.trim();
    if (currentCat.isNotEmpty) {
      if (_selectedGroup == 'SERVICE' && !_serviceCategories.contains(currentCat)) {
        _serviceCategories.insert(0, currentCat);
      } else if (_selectedGroup == 'GOODS' && !_goodsCategories.contains(currentCat)) {
        _goodsCategories.insert(0, currentCat);
      }
    }

    final currentUnit = _unitController.text.trim();
    if (currentUnit.isNotEmpty && !_units.contains(currentUnit)) {
      _units.insert(0, currentUnit);
    }

    final currentUsage = _usageController.text.trim();
    if (currentUsage.isNotEmpty && !_usageModes.contains(currentUsage)) {
      _usageModes.insert(0, currentUsage);
    }

    if (mounted) setState(() {});
  }

  List<String> get _currentCategoryOptions =>
      _selectedGroup == 'SERVICE' ? _serviceCategories : _goodsCategories;

  double? _parsePrice(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final price = _parsePrice(_priceController.text);
    final barcode = _barcodeController.text.trim();
    final desc = _descController.text.trim();
    final cat = _categoryController.text.trim();
    final usage = _usageController.text.trim();

    setState(() => _isSubmitting = true);

    final payload = {
      'name': name,
      'unit': unit,
      'tradeCategory': cat.isEmpty ? null : cat,
      'tradeMode': usage.isEmpty ? null : usage,
      'salePrice': price,
      'currency': price != null ? 'VND' : null,
      'barcode': barcode.isEmpty ? null : barcode,
      'description': desc.isEmpty ? null : desc,
    };

    final ok = await _service.updateMaterial(widget.item.code, payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      final updated = widget.item.copyWith(
        name: name,
        unit: unit,
        tradeCategory: cat.isEmpty ? null : cat,
        tradeMode: usage.isEmpty ? null : usage,
        salePrice: price,
        barcode: barcode.isEmpty ? null : barcode,
        description: desc.isEmpty ? null : desc,
      );
      widget.onSaved?.call(updated);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật hàng hóa ${widget.item.code} thành công.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } else {
      final err = _service.lastInventoryError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err != null ? 'Lỗi: $err' : 'Không thể cập nhật hàng hóa. Vui lòng thử lại.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showSelectBottomSheet({
    required String title,
    required List<String> options,
    required TextEditingController targetController,
    bool allowClear = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = options
                .where((opt) => opt.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm hoặc nhập mới...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (allowClear && targetController.text.isNotEmpty)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.clear, color: Color(0xFFEF4444), size: 18),
                      title: const Text('Bỏ chọn (Để trống)', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                      onTap: () {
                        setState(() => targetController.clear());
                        Navigator.pop(ctx);
                      },
                    ),
                  if (query.trim().isNotEmpty && !options.contains(query.trim()))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                      title: Text('Sử dụng "$query"', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      onTap: () {
                        setState(() => targetController.text = query.trim());
                        Navigator.pop(ctx);
                      },
                    ),
                  Expanded(
                    child: filtered.isEmpty && query.trim().isNotEmpty
                        ? const Center(
                            child: Text(
                              'Bấm "Sử dụng..." ở trên để tạo mục mới.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, idx) {
                              final item = filtered[idx];
                              final isSelected = targetController.text == item;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB))
                                    : null,
                                onTap: () {
                                  setState(() => targetController.text = item);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectorField({
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = controller.text.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hasValue ? controller.text : placeholder,
                style: TextStyle(
                  fontSize: 13.5,
                  color: hasValue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sửa hàng hóa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mã: ${widget.item.code}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Body Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên
                      _buildLabel('Tên', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration('Tên hàng hóa hoặc dịch vụ'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                      ),
                      const SizedBox(height: 14),

                      // Nhóm (Readonly) & Barcode
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Nhóm'),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    _selectedGroup == 'SERVICE' ? 'Dịch vụ' : 'Hàng hóa',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Barcode'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _barcodeController,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDecoration('Mã vạch'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Phân loại & Đơn vị tính
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Phân loại'),
                                const SizedBox(height: 6),
                                _buildSelectorField(
                                  controller: _categoryController,
                                  placeholder: 'Chọn phân loại',
                                  onTap: () => _showSelectBottomSheet(
                                    title: 'Chọn phân loại',
                                    options: _currentCategoryOptions,
                                    targetController: _categoryController,
                                    allowClear: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Đơn vị', required: true),
                                const SizedBox(height: 6),
                                _buildSelectorField(
                                  controller: _unitController,
                                  placeholder: 'Chọn đơn vị',
                                  onTap: () => _showSelectBottomSheet(
                                    title: 'Chọn đơn vị tính',
                                    options: _units,
                                    targetController: _unitController,
                                    allowClear: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Sử dụng & Giá bán
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Sử dụng'),
                                const SizedBox(height: 6),
                                _buildSelectorField(
                                  controller: _usageController,
                                  placeholder: 'Chọn cách dùng',
                                  onTap: () => _showSelectBottomSheet(
                                    title: 'Chọn cách sử dụng',
                                    options: _usageModes,
                                    targetController: _usageController,
                                    allowClear: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Giá bán (VND)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDecoration('Giá bán'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Mô tả
                      _buildLabel('Mô tả'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration('Thông tin thêm về hàng hóa hoặc dịch vụ'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ', style: TextStyle(color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                )
              ]
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}
