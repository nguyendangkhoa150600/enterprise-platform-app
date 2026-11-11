import 'package:flutter/material.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

class InventoryAssetCreateDialog extends StatefulWidget {
  final AssetItem? parentAsset;
  final VoidCallback? onCreated;

  const InventoryAssetCreateDialog({
    super.key,
    this.parentAsset,
    this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    AssetItem? parentAsset,
    VoidCallback? onCreated,
  }) {
    return showDialog(
      context: context,
      builder: (_) => InventoryAssetCreateDialog(
        parentAsset: parentAsset,
        onCreated: onCreated,
      ),
    );
  }

  @override
  State<InventoryAssetCreateDialog> createState() => _InventoryAssetCreateDialogState();
}

class _InventoryAssetCreateDialogState extends State<InventoryAssetCreateDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();

  String _selectedType = 'MACHINE';
  String _selectedCriticality = 'MEDIUM';
  bool _isSubmitting = false;

  static const List<Map<String, String>> _typeOptions = [
    {'value': 'PRODUCTION_LINE', 'label': 'Dây chuyền sản xuất'},
    {'value': 'MACHINE', 'label': 'Máy móc / Thiết bị chính'},
    {'value': 'DEVICE', 'label': 'Cụm thiết bị / Modun con'},
    {'value': 'TOOL', 'label': 'Công cụ / Dụng cụ'},
    {'value': 'LOCATION', 'label': 'Vị trí / Khu vực lắp đặt'},
    {'value': 'OTHER', 'label': 'Khác'},
  ];

  static const List<Map<String, String>> _criticalityOptions = [
    {'value': 'LOW', 'label': 'Thấp (Low)'},
    {'value': 'MEDIUM', 'label': 'Trung bình (Medium)'},
    {'value': 'HIGH', 'label': 'Cao (High)'},
    {'value': 'CRITICAL', 'label': 'Rất nghiêm trọng (Critical)'},
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'code': _codeController.text.trim(),
      'name': _nameController.text.trim(),
      'type': _selectedType,
      'criticality': _selectedCriticality,
    };

    if (widget.parentAsset != null) {
      payload['parentId'] = widget.parentAsset!.id;
    }

    if (_serialController.text.trim().isNotEmpty) {
      payload['serialNumber'] = _serialController.text.trim();
    }

    final ok = await _service.createAsset(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo thiết bị ${_codeController.text.trim()} thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onCreated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_service.lastInventoryError ?? 'Tạo thiết bị thất bại. Vui lòng kiểm tra lại mã.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChild = widget.parentAsset != null;
    final title = isChild ? 'Thêm thiết bị con' : 'Khai báo thiết bị gốc';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (isChild) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        'Thuộc cha: ${widget.parentAsset!.code} - ${widget.parentAsset!.name}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Mã thiết bị
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã thiết bị *',
                  hintText: 'VD: TB-001, DC-01...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập mã thiết bị' : null,
              ),
              const SizedBox(height: 12),

              // Tên thiết bị
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thiết bị *',
                  hintText: 'VD: Máy nén khí trục vít...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên thiết bị' : null,
              ),
              const SizedBox(height: 12),

              // Loại thiết bị
              SearchableDropdownField<Map<String, String>>(
                value: _typeOptions.firstWhere((o) => o['value'] == _selectedType),
                items: _typeOptions,
                hintText: 'Chọn phân loại',
                itemLabel: (o) => o['label'] ?? '',
                onChanged: (o) => setState(() => _selectedType = o['value']!),
                maxHeight: 240,
              ),
              const SizedBox(height: 12),

              // Mức độ quan trọng & Serial
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField<Map<String, String>>(
                      value: _criticalityOptions.firstWhere((o) => o['value'] == _selectedCriticality),
                      items: _criticalityOptions,
                      hintText: 'Độ quan trọng',
                      itemLabel: (o) => o['label'] ?? '',
                      onChanged: (o) => setState(() => _selectedCriticality = o['value']!),
                      maxHeight: 200,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Số sê-ri',
                        hintText: 'SN...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isChild ? 'Tạo thiết bị con' : 'Tạo thiết bị gốc', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

