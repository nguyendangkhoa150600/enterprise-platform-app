import 'package:flutter/material.dart';
import '../../../services/module_business_service.dart';
import '../../../theme/colors.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';

class InventoryCustodyDeclareDialog extends StatefulWidget {
  final VoidCallback? onDeclared;

  const InventoryCustodyDeclareDialog({
    super.key,
    this.onDeclared,
  });

  @override
  State<InventoryCustodyDeclareDialog> createState() => _InventoryCustodyDeclareDialogState();
}

class _InventoryCustodyDeclareDialogState extends State<InventoryCustodyDeclareDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _unitController = TextEditingController(text: 'Cái');
  final _priceController = TextEditingController();

  String _selectedCategory = 'IT_OFFICE';
  bool _isSubmitting = false;

  static const Map<String, String> _categories = {
    'IT_OFFICE': 'Thiết bị CNTT, văn phòng',
    'INDUSTRIAL': 'Thiết bị công nghiệp',
    'TOOL_PPE': 'Dụng cụ, bảo hộ',
    'VEHICLE': 'Phương tiện',
  };

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _serialController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ Mã tài sản và Tên tài sản.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    double? priceValue;
    if (_priceController.text.trim().isNotEmpty) {
      priceValue = double.tryParse(_priceController.text.trim().replaceAll(',', ''));
      if (priceValue == null || priceValue < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn giá mua không hợp lệ.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final success = await _service.createAsset({
        'code': code,
        'name': name,
        'type': 'EQUIPMENT',
        'status': 'OPERATING',
        'assetCategory': _selectedCategory,
        'serialNumber': _serialController.text.trim().isNotEmpty ? _serialController.text.trim() : null,
        'unit': _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : 'Cái',
        'purchasePrice': priceValue,
        'currency': priceValue != null ? 'VND' : null,
      });

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã khai báo tài sản mới: $code - $name'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        widget.onDeclared?.call();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo tài sản. Vui lòng kiểm tra lại mã tài sản.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khai báo tài sản mới',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Khai báo thiết bị, dụng cụ hoặc phương tiện vào sổ tài sản.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Form fields
              // 1. Mã SKU & Tên
              _buildFieldLabel('Mã tài sản / SKU', isRequired: true),
              const SizedBox(height: 5),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'VD: TS-LAPTOP-01, TS-OTO-02...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              _buildFieldLabel('Tên tài sản', isRequired: true),
              const SizedBox(height: 5),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'VD: Máy tính xách tay Dell XPS 15, Xe bán tải Ranger...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Nhóm tài sản & Đơn vị tính
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Nhóm tài sản', isRequired: true),
                        const SizedBox(height: 5),
                        SearchableDropdownField<String>(
                          value: _selectedCategory,
                          items: _categories.keys.toList(),
                          hintText: 'Chọn nhóm tài sản...',
                          itemLabel: (key) => _categories[key] ?? key,
                          showClear: false,
                          onChanged: (val) => setState(() => _selectedCategory = val),
                          maxHeight: 200,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Đơn vị tính'),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _unitController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cái, Bộ...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Số sê-ri & Giá mua
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Số sê-ri'),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _serialController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'S/N nếu có...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Đơn giá mua (VNĐ)'),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Giá nguyên tệ...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Lưu tài sản', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
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
}

