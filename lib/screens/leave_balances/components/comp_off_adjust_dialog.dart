import 'package:flutter/material.dart';
import '../../../../models/hrm_leave_balance_models.dart';
import '../../../../models/hrm_models.dart';
import '../../../../services/hrm_service.dart';

/// Hộp thoại/BottomSheet điều chỉnh tay quỹ nghỉ bù (đồng bộ 1:1 với Web CompOffAdjustDialog)
class CompOffAdjustSheet extends StatefulWidget {
  final HrmCompOffBalanceItem? initialEmployee;
  final HrmService hrmService;
  final VoidCallback onDone;

  const CompOffAdjustSheet({
    super.key,
    this.initialEmployee,
    required this.hrmService,
    required this.onDone,
  });

  @override
  State<CompOffAdjustSheet> createState() => _CompOffAdjustSheetState();
}

class _CompOffAdjustSheetState extends State<CompOffAdjustSheet> {
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedEmployeeCode;
  List<HrmEmployeeItem> _employees = [];
  bool _isLoadingEmployees = false;

  final TextEditingController _daysCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _searchEmpCtrl = TextEditingController();
  DateTime? _expiresOn;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmployee != null) {
      _selectedEmployeeId = widget.initialEmployee!.employeeId;
      _selectedEmployeeName = widget.initialEmployee!.employeeName;
      _selectedEmployeeCode = widget.initialEmployee!.employeeCode;
    } else {
      _loadEmployees();
    }
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _reasonCtrl.dispose();
    _searchEmpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final list = await widget.hrmService.getEmployees();
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEmployees = false);
    }
  }

  double? get _parsedDays {
    final t = _daysCtrl.text.trim().replaceAll(',', '.');
    return double.tryParse(t);
  }

  String? get _validationProblem {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      return 'Vui lòng chọn nhân viên';
    }
    final d = _parsedDays;
    if (d == null || d == 0) {
      return 'Nhập số ngày khác 0 (dương để cộng, âm để trừ)';
    }
    if ((d * 10 - (d * 10).round()).abs() > 1e-6) {
      return 'Số ngày chỉ có tối đa 1 chữ số thập phân';
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      return 'Cần nhập lý do điều chỉnh';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validationProblem;
    if (problem != null) {
      setState(() => _errorMessage = problem);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final expStr = _expiresOn != null
        ? '${_expiresOn!.year}-${_expiresOn!.month.toString().padLeft(2, '0')}-${_expiresOn!.day.toString().padLeft(2, '0')}'
        : null;

    final res = await widget.hrmService.adjustCompOff(
      employeeId: _selectedEmployeeId!,
      days: _parsedDays!,
      reason: _reasonCtrl.text.trim(),
      expiresOn: expStr,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res != null) {
      widget.onDone();
      Navigator.pop(context);
      final avail = res['available'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            avail != null
                ? 'Đã điều chỉnh. Số dư khả dụng còn $avail ngày.'
                : 'Đã lưu điều chỉnh quỹ nghỉ bù.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      setState(() => _errorMessage = 'Không điều chỉnh được quỹ nghỉ bù. Vui lòng thử lại.');
    }
  }

  void _showEmployeePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = _searchEmpCtrl.text.trim().toLowerCase();
            final filtered = _employees.where((e) {
              if (q.isEmpty) return true;
              return (e.fullName.toLowerCase().contains(q)) ||
                  (e.code.toLowerCase().contains(q)) ||
                  (e.department.toLowerCase().contains(q));
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chọn nhân viên',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchEmpCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên, mã hoặc phòng ban...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: _isLoadingEmployees
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không tìm thấy nhân viên',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (c, i) {
                                  final emp = filtered[i];
                                  final isSel = _selectedEmployeeId == emp.id;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      emp.fullName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${emp.code} · ${emp.department.isNotEmpty ? emp.department : '—'}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    trailing: isSel
                                        ? const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF2563EB))
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedEmployeeId = emp.id;
                                        _selectedEmployeeName = emp.fullName;
                                        _selectedEmployeeCode = emp.code;
                                      });
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điều chỉnh quỹ nghỉ bù',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Số dương mở lô mới; số âm trừ lô gần hết hạn trước.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Employee Picker Field
            const Text('Nhân viên *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            InkWell(
              onTap: widget.initialEmployee == null ? _showEmployeePicker : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.initialEmployee == null ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedEmployeeName != null
                            ? '$_selectedEmployeeName ($_selectedEmployeeCode)'
                            : 'Chọn nhân viên cần điều chỉnh...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedEmployeeName != null ? FontWeight.w600 : FontWeight.normal,
                          color: _selectedEmployeeName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (widget.initialEmployee == null)
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Days Input
            const Text('Số ngày (+ cộng, - trừ) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _daysCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Ví dụ: 1 hoặc -0.5',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                suffixText: 'ngày',
                suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            // Quick preset chips
            Wrap(
              spacing: 6,
              children: [
                _buildQuickDayChip('+0.5'),
                _buildQuickDayChip('+1.0'),
                _buildQuickDayChip('+2.0'),
                _buildQuickDayChip('-0.5'),
                _buildQuickDayChip('-1.0'),
              ],
            ),
            const SizedBox(height: 14),

            // Expiry Date (Optional, for positive adjustments)
            if ((_parsedDays ?? 0) > 0) ...[
              const Text('Hạn dùng lô mới (không bắt buộc)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiresOn ?? now.add(const Duration(days: 90)),
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    setState(() => _expiresOn = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _expiresOn != null
                              ? '${_expiresOn!.day.toString().padLeft(2, '0')}/${_expiresOn!.month.toString().padLeft(2, '0')}/${_expiresOn!.year}'
                              : 'Theo quy định công ty (mặc định)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _expiresOn != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (_expiresOn != null)
                        GestureDetector(
                          onTap: () => setState(() => _expiresOn = null),
                          child: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Reason Input
            const Text('Lý do điều chỉnh *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Nhập lý do điều chỉnh quỹ (bắt buộc)...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                        : const Text('Lưu điều chỉnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDayChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: () {
        _daysCtrl.text = label.replaceAll('+', '');
        setState(() {});
      },
    );
  }
}

void showCompOffAdjustSheet(
  BuildContext context, {
  HrmCompOffBalanceItem? initialEmployee,
  required HrmService hrmService,
  required VoidCallback onDone,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CompOffAdjustSheet(
      initialEmployee: initialEmployee,
      hrmService: hrmService,
      onDone: onDone,
    ),
  );
}
