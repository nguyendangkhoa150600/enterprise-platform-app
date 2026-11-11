import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../services/module_business_service.dart';

class InventoryTradeItemCreateDialog extends StatefulWidget {
  final Future<void> Function()? onCreated;

  const InventoryTradeItemCreateDialog({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {Future<void> Function()? onCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTradeItemCreateDialog(onCreated: onCreated),
    );
  }

  @override
  State<InventoryTradeItemCreateDialog> createState() => _InventoryTradeItemCreateDialogState();
}

class _InventoryTradeItemCreateDialogState extends State<InventoryTradeItemCreateDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedGroup = 'GOODS'; // 'GOODS' (Hàng hóa) hoặc 'SERVICE' (Dịch vụ)
  bool _isSubmitting = false;
  bool _isLoadingSettings = true;

  // Catalog loaded from /api/inventory/v1/settings
  List<String> _goodsCategories = [];
  List<String> _serviceCategories = [];
  List<String> _usageModes = [];
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    _loadCatalogSettings();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _usageController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
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
      _goodsCategories = ['Vật tư tiêu chuẩn', 'Phụ tùng thay thế', 'Thiết bị điện', 'Dụng cụ thi công'];
    }
    if (_serviceCategories.isEmpty) {
      _serviceCategories = ['Dịch vụ lắp đặt', 'Dịch vụ bảo trì', 'Dịch vụ kiểm định'];
    }
    if (_usageModes.isEmpty) {
      _usageModes = ['Bán buôn', 'Bán lẻ', 'Dùng nội bộ', 'Tặng kèm'];
    }
    if (_units.isEmpty) {
      _units = ['Cái', 'Bộ', 'Chiếc', 'Mét', 'Kg', 'Lít', 'Hộp', 'Thùng', 'Cuộn', 'Gói'];
    }

    if (mounted) {
      setState(() {
        _isLoadingSettings = false;
        if (_units.isNotEmpty && _unitController.text.isEmpty) {
          _unitController.text = _units.first;
        }
      });
    }
  }

  List<String> get _currentCategoryOptions =>
      _selectedGroup == 'SERVICE' ? _serviceCategories : _goodsCategories;

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ Mã và Tên hàng hóa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc nhập Đơn vị tính.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    double? priceValue;
    final priceRaw = _priceController.text.trim().replaceAll(',', '').replaceAll('.', '');
    if (priceRaw.isNotEmpty) {
      priceValue = double.tryParse(priceRaw);
    }

    // Payload chuẩn 1:1 đồng bộ với Web trade-item-form-dialog.tsx
    final payload = <String, dynamic>{
      'code': code,
      'name': name,
      'unit': unit,
      'category': 'CONSUMABLE',
      'kind': _selectedGroup == 'SERVICE' ? 'SERVICE' : 'STOCK',
      if (_barcodeController.text.trim().isNotEmpty) 'barcode': _barcodeController.text.trim(),
      if (_categoryController.text.trim().isNotEmpty) 'tradeCategory': _categoryController.text.trim(),
      if (_usageController.text.trim().isNotEmpty) 'tradeMode': _usageController.text.trim(),
      if (priceValue != null) 'salePrice': priceValue,
      if (priceValue != null) 'currency': 'VND',
      if (_descriptionController.text.trim().isNotEmpty) 'description': _descriptionController.text.trim(),
    };

    final ok = await _service.createMaterial(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo hàng hóa $code thành công.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      widget.onCreated?.call();
    } else {
      final err = _service.lastInventoryError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err != null && err.isNotEmpty
              ? err
              : 'Không thể tạo hàng hóa. Mã có thể đã tồn tại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSelectorSheet({
    required String title,
    required List<String> options,
    required TextEditingController targetController,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
        child: Column(
          children: [
            // Header: Tiêu đề "Tạo hàng hóa" & Nút đóng X (Khớp 1:1 với Web)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tạo hàng hóa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Form Body
            Expanded(
              child: _isLoadingSettings
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Mã & Tên
                            _buildLabel('Mã', isRequired: true),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _codeController,
                              hintText: 'VD: VT-001',
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 14),

                            _buildLabel('Tên', isRequired: true),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _nameController,
                              hintText: 'Tên hàng hóa hoặc dịch vụ',
                            ),
                            const SizedBox(height: 14),

                            // 2. Barcode & Nhóm
                            _buildLabel('Barcode'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _barcodeController,
                              hintText: 'Mã vạch',
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 14),

                            _buildLabel('Nhóm'),
                            const SizedBox(height: 6),
                            _buildGroupSelector(),
                            const SizedBox(height: 14),

                            // 3. Phân loại & Đơn vị
                            _buildLabel('Phân loại'),
                            const SizedBox(height: 6),
                            _buildSelectField(
                              controller: _categoryController,
                              placeholder: '— Chọn phân loại —',
                              onTap: () => _showSelectorSheet(
                                title: 'Chọn phân loại (${_selectedGroup == 'SERVICE' ? 'Dịch vụ' : 'Hàng hóa'})',
                                options: _currentCategoryOptions,
                                targetController: _categoryController,
                              ),
                            ),
                            const SizedBox(height: 14),

                            _buildLabel('Đơn vị', isRequired: true),
                            const SizedBox(height: 6),
                            _buildSelectField(
                              controller: _unitController,
                              placeholder: '— Chọn đơn vị —',
                              onTap: () => _showSelectorSheet(
                                title: 'Chọn đơn vị tính',
                                options: _units,
                                targetController: _unitController,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 4. Sử dụng & Giá bán
                            _buildLabel('Sử dụng'),
                            const SizedBox(height: 6),
                            _buildSelectField(
                              controller: _usageController,
                              placeholder: '— Chọn cách sử dụng —',
                              onTap: () => _showSelectorSheet(
                                title: 'Chọn hình thức sử dụng',
                                options: _usageModes,
                                targetController: _usageController,
                              ),
                            ),
                            const SizedBox(height: 14),

                            _buildLabel('Giá bán (VND)'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _priceController,
                              hintText: 'Bỏ trống nếu chưa khai báo',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 14),

                            // 5. Mô tả
                            _buildLabel('Mô tả'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _descriptionController,
                              hintText: 'Thông tin thêm về hàng hóa hoặc dịch vụ',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
            ),

            // Footer: Nút Huỷ & Tạo mới (Khớp 1:1 với Web)
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Tạo mới', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      ),
    );
  }

  Widget _buildSelectField({
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

  Widget _buildGroupSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _buildGroupTab(
              label: 'Hàng hóa',
              value: 'GOODS',
              isSelected: _selectedGroup == 'GOODS',
            ),
          ),
          Expanded(
            child: _buildGroupTab(
              label: 'Dịch vụ',
              value: 'SERVICE',
              isSelected: _selectedGroup == 'SERVICE',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTab({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        if (_selectedGroup != value) {
          setState(() {
            _selectedGroup = value;
            // Clear category when group changes
            _categoryController.clear();
          });
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

