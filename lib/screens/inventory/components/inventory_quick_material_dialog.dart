import 'package:flutter/material.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

/// Sub-dialog: Khai báo vật tư mới vào danh mục (Khớp 1:1 với Web MovementForm)
class InventoryQuickMaterialDialog extends StatefulWidget {
  final Future<void> Function(InventoryItem newItem) onCreated;

  const InventoryQuickMaterialDialog({
    super.key,
    required this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(InventoryItem newItem) onCreated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryQuickMaterialDialog(onCreated: onCreated),
    );
  }

  @override
  State<InventoryQuickMaterialDialog> createState() => _InventoryQuickMaterialDialogState();
}

class _InventoryQuickMaterialDialogState extends State<InventoryQuickMaterialDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController(text: '0');

  String _selectedUnit = 'Cái';
  bool _isSubmitting = false;

  static const List<String> _units = [
    'Cái',
    'Bộ',
    'Mét',
    'Cuộn',
    'Kg',
    'Lít',
    'Thùng',
    'Hộp',
    'Tấm',
    'Bao',
    'Chiếc',
    'Ống',
    'Cây',
    'Gói',
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0.0;

    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ Mã SKU và Tên vật tư.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _service.createMaterial({
        'code': code,
        'name': name,
        'category': 'SPARE_PART',
        'unit': _selectedUnit,
        'minStock': minStock,
        'kind': 'STOCK',
        'isSerialized': false,
      });

      final newItem = InventoryItem(
        code: code,
        name: name,
        unit: _selectedUnit,
        minStock: minStock,
        available: 0.0,
        kind: 'STOCK',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).pop();
      await widget.onCreated(newItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Đã tạo "$name" ($code) và thêm vào phiếu.'
                  : 'Vật tư ($code) đã được thêm vào phiếu.',
            ),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _codeController.text.trim().isNotEmpty && _nameController.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Khai báo vật tư mới vào danh mục',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vật tư này sẽ được tạo trong danh mục và tự động thêm vào phiếu hiện tại.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 1: Mã SKU & Đơn vị tính
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Mã SKU vật tư', isRequired: true),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                          decoration: _inputDecoration('VD: VT-BIEN-AP-01'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Đơn vị tính', isRequired: true),
                        const SizedBox(height: 6),
                        SearchableDropdownField<String>(
                          value: _selectedUnit,
                          items: _units,
                          hintText: 'Chọn ĐVT...',
                          itemLabel: (u) => u,
                          showClear: false,
                          onChanged: (u) => setState(() => _selectedUnit = u),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 2: Tên đầy đủ của vật tư
              _buildFieldLabel('Tên đầy đủ của vật tư', isRequired: true),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: _inputDecoration('VD: Dầu làm mát máy biến áp tiêu chuẩn IEC'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Row 3: Mức tồn kho an toàn tối thiểu
              _buildFieldLabel('Mức tồn kho an toàn tối thiểu'),
              const SizedBox(height: 6),
              TextField(
                controller: _minStockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: _inputDecoration('0'),
              ),
              const SizedBox(height: 20),

              // Footer Actions
              Row(
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
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (_isSubmitting || !canSubmit) ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('+ Thêm vào phiếu', style: TextStyle(fontWeight: FontWeight.w600)),
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

