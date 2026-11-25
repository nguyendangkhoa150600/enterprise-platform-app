import 'package:flutter/material.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/goods/goods_repository.dart';

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

  String _selectedUnit = '';
  bool _isSubmitting = false;

  // Đơn vị tính lấy từ danh mục Cài đặt (`catalog.unit`), như web `unitOptions`.
  List<String> _units = const [];

  @override
  void initState() {
    super.initState();
    GoodsRepository.instance.loadCatalog().then((c) {
      if (!mounted) return;
      setState(() {
        _units = c.units;
        if (_selectedUnit.isEmpty && _units.isNotEmpty) _selectedUnit = _units.first;
      });
    }).catchError((_) {});
  }

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
        SnackBar(
          content: Text('inventory.goods.qm_required'.tr()),
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
                  ? 'inventory.goods.qm_created'.tr(args: {'name': name, 'code': code})
                  : 'inventory.goods.qm_added'.tr(args: {'code': code}),
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
            content: Text('inventory.goods.qm_error'.tr(args: {'error': e})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _codeController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty &&
        _selectedUnit.trim().isNotEmpty;

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
                      children: [
                        Text(
                          'inventory.goods.qm_title'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'inventory.goods.qm_subtitle'.tr(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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
                        _buildFieldLabel('inventory.goods.qm_code'.tr(), isRequired: true),
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
                        _buildFieldLabel('inventory.goods.qm_unit'.tr(), isRequired: true),
                        const SizedBox(height: 6),
                        if (_units.isEmpty)
                          TextField(
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                            decoration: _inputDecoration('inventory.goods.ph_unit_free'.tr()),
                            onChanged: (v) => setState(() => _selectedUnit = v.trim()),
                          )
                        else
                        SearchableDropdownField<String>(
                          value: _selectedUnit.isEmpty ? null : _selectedUnit,
                          items: _units,
                          hintText: 'inventory.goods.qm_unit_ph'.tr(),
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
              _buildFieldLabel('inventory.goods.qm_name'.tr(), isRequired: true),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: _inputDecoration('inventory.goods.qm_name_ph'.tr()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Row 3: Mức tồn kho an toàn tối thiểu
              _buildFieldLabel('inventory.goods.qm_min_stock'.tr()),
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
                    child: Text('inventory.goods.cancel'.tr()),
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
                        : Text('inventory.goods.qm_submit'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
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

