import 'package:flutter/material.dart';
import '../../../models/inventory_models.dart';
import '../../../services/module_business_service.dart';

class InventoryItemEditDialog extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback? onUpdated;

  const InventoryItemEditDialog({
    super.key,
    required this.item,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required InventoryItem item,
    VoidCallback? onUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => InventoryItemEditDialog(
        item: item,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<InventoryItemEditDialog> createState() => _InventoryItemEditDialogState();
}

class _InventoryItemEditDialogState extends State<InventoryItemEditDialog> {
  final ModuleBusinessService _service = ModuleBusinessService();

  late TextEditingController _codeController;
  late TextEditingController _nameController;

  String? _selectedType;
  String? _selectedStatus;
  String? _selectedUsageState;

  bool _isSaving = false;
  bool _isLoadingOptions = true;

  List<String> _typeOptions = [];
  List<String> _statusOptions = [];
  List<String> _whereOptions = [];

  static const Map<String, String> _statusLabels = {
    'OPERATING': 'Đang vận hành',
    'STOPPED': 'Đang dừng',
    'MAINTENANCE': 'Đang bảo trì',
    'DISPOSED': 'Đã thanh lý',
  };

  static String? _normalizeStatus(String? status, List<String> availableStatuses) {
    if (status == null || status.isEmpty) return null;
    if (availableStatuses.contains(status)) return status;
    final label = _statusLabels[status];
    if (label != null && availableStatuses.contains(label)) return label;
    for (final entry in _statusLabels.entries) {
      if (entry.value == status && availableStatuses.contains(entry.key)) return entry.key;
    }
    return status;
  }

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.item.code);
    _nameController = TextEditingController(text: widget.item.name);

    _selectedType = widget.item.type;

    // Loại bỏ các giá trị tồn kho tạm tính (OUT_OF_STOCK, LOW_STOCK, NORMAL)
    final rawStatus = widget.item.status;
    if (rawStatus == null ||
        rawStatus.isEmpty ||
        rawStatus == 'OUT_OF_STOCK' ||
        rawStatus == 'LOW_STOCK' ||
        rawStatus == 'NORMAL') {
      _selectedStatus = null;
    } else {
      _selectedStatus = rawStatus;
    }

    _selectedUsageState = widget.item.usageState;

    _loadFormOptions();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<String> _withCurrent(List<String> options, String? current) {
    final list = List<String>.from(options);
    if (current != null && current.isNotEmpty && !list.contains(current)) {
      list.add(current);
    }
    return list;
  }

  Future<void> _loadFormOptions() async {
    try {
      final results = await Future.wait([
        _service.getInventorySettings(),
        _service.getInventoryOverview(),
      ]);

      final settings = results[0] as Map<String, dynamic>?;
      final overview = results[1] as InventoryOverviewData?;

      // 1. Loại danh mục (types)
      List<String> types = [];
      if (settings != null && settings['catalog.asset'] != null) {
        final val = settings['catalog.asset']['value'];
        if (val != null && val['types'] is List) {
          types = (val['types'] as List).map((e) => e.toString()).toList();
        }
      }
      if (types.isEmpty) {
        types = ['SPARE_PART', 'Thiết bị', 'Vật tư tiêu hao', 'Công cụ dụng cụ'];
      }
      if (overview != null) {
        for (final it in overview.items) {
          if (it.type != null && it.type!.isNotEmpty && !types.contains(it.type)) {
            types.add(it.type!);
          }
        }
      }

      // 2. Tình trạng vận hành (statuses) - Đồng bộ chuẩn 3 trạng thái mặc định như Web
      List<String> statuses = [];
      if (settings != null && settings['catalog.asset'] != null) {
        final val = settings['catalog.asset']['value'];
        if (val != null && val['enabledStatuses'] is List) {
          statuses = (val['enabledStatuses'] as List)
              .map((e) => _statusLabels[e.toString()] ?? e.toString())
              .toList();
        }
      }
      if (statuses.isEmpty) {
        statuses = ['Đang vận hành', 'Đang dừng', 'Đang bảo trì'];
      }
      // Lọc bỏ triệt để các trạng thái tồn kho giả lập
      statuses.removeWhere((s) => s == 'OUT_OF_STOCK' || s == 'LOW_STOCK' || s == 'NORMAL');

      // 3. Vị trí / Trạng thái kho (whereOptions)
      // Khớp 1:1 với Web (item-catalog.tsx lines 168-174):
      // Nếu đã khai usageStates trong Cài đặt thì đó là nguồn DUY NHẤT, KHÔNG nối thêm kho!
      List<String> whOptions = [];
      if (settings != null && settings['catalog.asset'] != null) {
        final val = settings['catalog.asset']['value'];
        if (val != null && val['usageStates'] is List) {
          whOptions = (val['usageStates'] as List).map((e) => e.toString()).toList();
        }
      }

      if (whOptions.isEmpty) {
        if (overview != null && overview.warehouses.isNotEmpty) {
          whOptions = overview.warehouses.map((w) => w.name).toList();
        } else {
          whOptions = ['Mượn thí nghiệm', 'Bảo trì', 'Đang vận hành', 'Dự phòng'];
        }
      }

      final normalizedStatus = _normalizeStatus(_selectedStatus, statuses);

      if (mounted) {
        setState(() {
          _selectedStatus = normalizedStatus;
          _typeOptions = _withCurrent(types, _selectedType);
          _statusOptions = _withCurrent(statuses, _selectedStatus);
          _whereOptions = _withCurrent(whOptions, _selectedUsageState);
          _isLoadingOptions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _typeOptions = _withCurrent(['SPARE_PART', 'Thiết bị', 'Vật tư tiêu hao'], _selectedType);
          _statusOptions = _withCurrent(['Đang vận hành', 'Đang dừng', 'Đang bảo trì'], _selectedStatus);
          _whereOptions = _withCurrent(['Mượn thí nghiệm', 'Bảo trì', 'Đang vận hành', 'Dự phòng'], _selectedUsageState);
          _isLoadingOptions = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Tên vật tư'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final patch = <String, dynamic>{
        'name': name,
        if (_selectedType != null && _selectedType!.isNotEmpty) 'type': _selectedType,
        if (_selectedStatus != null && _selectedStatus!.isNotEmpty) 'status': _selectedStatus,
        if (_selectedUsageState != null && _selectedUsageState!.isNotEmpty) 'usageState': _selectedUsageState,
      };

      final success = await _service.updateInventoryItem(widget.item, patch);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ${widget.item.code} thành công.'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
        widget.onUpdated?.call();
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu thay đổi. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
    final isSerialized = widget.item.isSerialized == true;

    return Dialog(
      backgroundColor: const Color(0xFFFAFAFA),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Khớp 1:1 Typography & Subtitle trên Web)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cập nhật vật tư',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Điều chỉnh mã SKU, tên hiển thị, loại danh mục và trạng thái kho bãi.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Mã vật tư *
              _buildFieldLabel('Mã vật tư', isRequired: true),
              const SizedBox(height: 6),
              TextField(
                controller: _codeController,
                enabled: false,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                decoration: _buildInputDecoration(hintText: 'VD: VT-001, MBA-01…').copyWith(
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mã định danh duy nhất của vật tư trong hệ thống (Không thể thay đổi).',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // 3. Tên vật tư *
              _buildFieldLabel('Tên vật tư', isRequired: true),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: _buildInputDecoration(hintText: 'VD: Dầu biến áp, Máy cắt không khí…'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tên gọi hiển thị trên danh mục và các biểu mẫu tác nghiệp.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // 4. Loại danh mục
              _buildFieldLabel('Loại danh mục'),
              const SizedBox(height: 6),
              _buildSelectField<String>(
                value: _selectedType,
                hintText: '— Chưa phân loại —',
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('— Chưa phân loại —', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)),
                  ),
                  ..._typeOptions.map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B))),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedType = (val == null || val.isEmpty) ? null : val;
                  });
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Phân nhóm nghiệp vụ theo cấu hình danh mục của hệ thống.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // 5. Tình trạng vận hành & Vị trí / Trạng thái kho
              if (!isSerialized) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusSelector(),
                          const SizedBox(height: 14),
                          _buildUsageStateSelector(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildStatusSelector()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildUsageStateSelector()),
                      ],
                    );
                  },
                ),
              ] else ...[
                // Banner sê-ri cá thể (Khớp 1:1 với Web)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'Vật tư này được quản lý theo số sê-ri cá thể. Tình trạng và vị trí được cập nhật trực tiếp theo từng số sê-ri trong chi tiết dòng.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1E40AF),
                      height: 1.45,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // 6. Footer Actions (Nút Huỷ & Lưu thay đổi)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Huỷ',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (_isSaving || _codeController.text.trim().isEmpty || _nameController.text.trim().isEmpty)
                        ? null
                        : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Tình trạng vận hành'),
        const SizedBox(height: 6),
        _buildSelectField<String>(
          value: _selectedStatus,
          hintText: '— Chưa xác định —',
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('— Chưa xác định —', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
            ..._statusOptions.map(
              (st) {
                final display = _statusLabels[st] ?? st;
                return DropdownMenuItem<String>(
                  value: st,
                  child: Text(
                    display,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedStatus = (val == null || val.isEmpty) ? null : val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildUsageStateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Vị trí / Trạng thái kho'),
        const SizedBox(height: 6),
        _buildSelectField<String>(
          value: _selectedUsageState,
          hintText: '— Chưa xác định —',
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('— Chưa xác định —', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
            ..._whereOptions.map(
              (wh) => DropdownMenuItem<String>(
                value: wh,
                child: Text(
                  wh,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedUsageState = (val == null || val.isEmpty) ? null : val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
        children: isRequired
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                ),
              ]
            : null,
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  Widget _buildSelectField<T>({
    required T? value,
    required String hintText,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    // Ensure value exists in items or fall back to empty
    final hasVal = items.any((it) => it.value == value);
    final effectiveValue = hasVal ? value : (items.first.value);

    return DropdownButtonFormField<T>(
      value: effectiveValue,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

