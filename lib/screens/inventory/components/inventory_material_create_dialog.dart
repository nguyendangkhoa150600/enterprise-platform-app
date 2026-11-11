import 'package:flutter/material.dart';
import '../../../services/module_business_service.dart';

class InventoryMaterialCreateDialog extends StatefulWidget {
  final Future<void> Function()? onCreated;

  const InventoryMaterialCreateDialog({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {Future<void> Function()? onCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryMaterialCreateDialog(onCreated: onCreated),
    );
  }

  @override
  State<InventoryMaterialCreateDialog> createState() => _InventoryMaterialCreateDialogState();
}

class _InventoryMaterialCreateDialogState extends State<InventoryMaterialCreateDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _warrantyController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController(text: '0');
  final TextEditingController _maxStockController = TextEditingController(text: '100');
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = 'SPARE_PART';
  String _selectedUnit = 'Cái';
  String _selectedKind = 'STOCK';
  String _trackingMethod = 'NONE'; // 'SERIAL', 'LOT', 'NONE'
  bool _isSubmitting = false;

  final List<({String label, String value})> _categoryOptions = [
    (label: 'Phụ tùng', value: 'SPARE_PART'),
    (label: 'Thiết bị', value: 'EQUIPMENT'),
    (label: 'Vật tư tiêu hao', value: 'CONSUMABLE'),
    (label: 'Công cụ dụng cụ', value: 'TOOL'),
  ];

  final List<String> _unitOptions = [
    'Cái',
    'Bộ',
    'Chiếc',
    'Mét',
    'Kg',
    'Lít',
    'Hộp',
    'Thùng',
    'Cuộn',
    'Đôi',
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _warrantyController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ Mã vật tư và Tên vật tư.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0.0;
    final maxStock = double.tryParse(_maxStockController.text.trim());
    final warrantyMonths = int.tryParse(_warrantyController.text.trim());
    final price = double.tryParse(_priceController.text.trim().replaceAll(',', '').replaceAll('.', ''));

    final payload = <String, dynamic>{
      'code': code,
      'name': name,
      'unit': _selectedUnit,
      'category': _selectedCategory,
      'kind': _selectedKind,
      'isSerialized': _trackingMethod == 'SERIAL',
      'minStock': minStock,
      if (maxStock != null) 'maxStock': maxStock,
      if (warrantyMonths != null) 'warrantyMonths': warrantyMonths,
      if (price != null) 'purchasePrice': price,
    };

    final ok = await _service.createMaterial(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm vật tư $code thành công.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      widget.onCreated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thêm vật tư. Có thể mã đã tồn tại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
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
                      children: const [
                        Text(
                          'Thêm vật tư mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Khai báo mã SKU, định mức tồn và phương thức quản lý định danh (Sê-ri hoặc Lô).',
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

            // Body Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Mã SKU & Tên vật tư
                      _buildFieldLabel('Mã SKU / Mã vật tư', isRequired: true),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _codeController,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration('VD: VT-RO-LE-01, VT-DAU-02…'),
                      ),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Tên vật tư', isRequired: true),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration('VD: Rơ-le bảo vệ so lệch, Dầu biến áp…'),
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Nhóm vật tư & Đơn vị tính
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Nhóm vật tư', isRequired: true),
                                const SizedBox(height: 6),
                                _buildDropdown<String>(
                                  value: _selectedCategory,
                                  items: _categoryOptions.map((c) => DropdownMenuItem(value: c.value, child: Text(c.label))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCategory = val);
                                  },
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
                                _buildDropdown<String>(
                                  value: _selectedUnit,
                                  items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedUnit = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Loại mặt hàng & Bảo hành
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Loại mặt hàng', isRequired: true),
                                const SizedBox(height: 6),
                                _buildDropdown<String>(
                                  value: _selectedKind,
                                  items: const [
                                    DropdownMenuItem(value: 'STOCK', child: Text('Hàng hoá (tồn kho)')),
                                    DropdownMenuItem(value: 'SERVICE', child: Text('Dịch vụ')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedKind = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Bảo hành (tháng)'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _warrantyController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration('Bỏ trống nếu chưa khai'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Tồn tối thiểu & Tồn tối đa
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Tồn tối thiểu (Min stock)'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _minStockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration('0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Tồn tối đa (Max stock)'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _maxStockController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                                  decoration: _inputDecoration('100'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Đơn giá
                      _buildFieldLabel('Đơn giá (đ)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration('Chưa khai báo'),
                      ),
                      const SizedBox(height: 18),

                      // Row 6: Phương thức quản lý định danh vật tư *
                      _buildFieldLabel('Phương thức quản lý định danh vật tư', isRequired: true),
                      const SizedBox(height: 8),
                      _buildTrackingCard(
                        id: 'SERIAL',
                        icon: Icons.qr_code_2_rounded,
                        title: 'Theo Sê-ri (SN)',
                        subtitle: 'Mỗi chiếc có số SN riêng biệt (thiết bị, rơ-le, máy biến áp, motor…).',
                      ),
                      const SizedBox(height: 8),
                      _buildTrackingCard(
                        id: 'LOT',
                        icon: Icons.layers_outlined,
                        title: 'Theo Lô (Lot/Batch)',
                        subtitle: 'Quản lý mẻ/kiện, hạn dùng FEFO, kiểm định (dầu, cáp, hoá chất…).',
                      ),
                      const SizedBox(height: 8),
                      _buildTrackingCard(
                        id: 'NONE',
                        icon: Icons.inventory_2_outlined,
                        title: 'Thông thường',
                        subtitle: 'Quản lý tồn thuần túy theo số lượng, không cần định danh chi tiết.',
                      ),
                      const SizedBox(height: 16),

                      // Information Note Banner (Matching Web)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Số lượng nhập, kho lưu trữ và giá trị sẽ được ghi nhận qua các Phiếu Nhập kho thông thường.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 10),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Thêm vật tư', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTrackingCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _trackingMethod == id;
    return InkWell(
      onTap: () => setState(() => _trackingMethod = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

