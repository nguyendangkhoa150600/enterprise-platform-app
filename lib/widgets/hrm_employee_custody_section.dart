import 'package:flutter/material.dart';
import '../services/hrm_service.dart';

class HrmEmployeeCustodySection extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const HrmEmployeeCustodySection({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<HrmEmployeeCustodySection> createState() => _HrmEmployeeCustodySectionState();
}

class _HrmEmployeeCustodySectionState extends State<HrmEmployeeCustodySection> {
  final HrmService _service = HrmService();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustody();
  }

  Future<void> _loadCustody() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _service.getEmployeeCustody(widget.employeeId);
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Không tải được danh sách vật tư cấp phát: $e';
        });
      }
    }
  }

  Future<void> _revokeAsset(String materialCode, String assetName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận thu hồi tài sản', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn thu hồi tài sản $materialCode ($assetName) từ nhân viên ${widget.employeeName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.revokeEmployeeCustody(widget.employeeId, materialCode);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thu hồi tài sản $materialCode thành công.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadCustody();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thu hồi tài sản thất bại. Vui lòng thử lại.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _showAssignModal() async {
    final assignable = await _service.getAssignableCustodyAssets();
    if (!mounted) return;

    if (assignable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không còn tài sản khả dụng trong kho để cấp phát.'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
      return;
    }

    String? selectedCode = assignable.first['code']?.toString();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cấp phát tài sản cho nhân sự', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cấp tài sản công ty cho ${widget.employeeName}:', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCode,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    items: assignable.map((a) {
                      final code = a['code']?.toString() ?? '';
                      final name = a['name']?.toString() ?? '';
                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - $name', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCode = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: selectedCode != null ? () => Navigator.pop(ctx, selectedCode) : null,
              child: const Text('Cấp tài sản', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final ok = await _service.assignEmployeeCustody(widget.employeeId, result);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cấp phát tài sản $result cho ${widget.employeeName}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _loadCustody();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cấp phát tài sản thất bại.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Vật tư & Tài sản cấp phát',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_items.length}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tài sản, thiết bị công ty đang bàn giao cho nhân sự chịu trách nhiệm.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAssignModal,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Cấp tài sản', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
            )
          else if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Center(
                child: Text(
                  'Chưa được cấp phát vật tư, tài sản nào.',
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = _items[idx];
                final code = item['code']?.toString() ?? '';
                final name = item['name']?.toString() ?? '';
                final category = item['assetCategory']?.toString() ?? item['category']?.toString() ?? '';
                final serial = item['serialNumber']?.toString() ?? '';
                final assignedAt = item['assignedAt']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.devices_other_outlined, size: 16, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mã: $code${serial.isNotEmpty ? " • S/N: $serial" : ""}${category.isNotEmpty ? " • $category" : ""}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            if (assignedAt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Ngày cấp: ${assignedAt.split("T").first}',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.undo_outlined, size: 18, color: Color(0xFFDC2626)),
                        tooltip: 'Thu hồi',
                        onPressed: () => _revokeAsset(code, name),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

