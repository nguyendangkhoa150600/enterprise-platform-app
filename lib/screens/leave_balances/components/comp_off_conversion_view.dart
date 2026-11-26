import 'package:flutter/material.dart';
import '../../../../models/hrm_leave_balance_models.dart';
import '../../../../services/hrm_service.dart';

/// Màn hình/Tab Chuyển đổi tháng quỹ nghỉ bù (đồng bộ 1:1 với Web CompOffConversionPanel)
class CompOffConversionView extends StatefulWidget {
  final HrmService hrmService;
  final VoidCallback onDataChanged;

  const CompOffConversionView({
    super.key,
    required this.hrmService,
    required this.onDataChanged,
  });

  @override
  State<CompOffConversionView> createState() => _CompOffConversionViewState();
}

class _CompOffConversionViewState extends State<CompOffConversionView> {
  late String _month;
  HrmCompOffConversionPreview? _preview;
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _selectedEmpIds = {};
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    // Default to previous month matching Web: shiftMonth(currentMonthKey(), -1)
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    _month = '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';
    _loadPreview();
  }

  void _shiftMonth(int delta) {
    final parts = _month.split('-');
    if (parts.length != 2) return;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final shifted = DateTime(y, m + delta);
    setState(() {
      _month = '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}';
    });
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedEmpIds.clear();
    });
    try {
      final res = await widget.hrmService.getCompOffConversionPreview(_month);
      if (mounted) {
        setState(() {
          _preview = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không tải được dữ liệu chuyển đổi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _convertSelected() async {
    if (_preview == null || _selectedEmpIds.isEmpty || _isConverting) return;

    setState(() => _isConverting = true);
    final payloadRows = _selectedEmpIds.map((id) => {'employeeId': id}).toList();

    try {
      final res = await widget.hrmService.confirmCompOffConversion(
        month: _month,
        rows: payloadRows,
      );

      if (!mounted) return;
      setState(() => _isConverting = false);

      if (res != null) {
        final created = res['created'] ?? _selectedEmpIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển đổi thành công cho $created nhân viên.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadPreview();
        widget.onDataChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không chuyển đổi được. Vui lòng kiểm tra lại.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chuyển đổi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _preview?.rows ?? [];
    final convertible = rows.where((r) => r.isConvertible).toList();
    final canConfirm = (_preview?.locked == true) && (_preview?.enabled == true);
    final allSelected = convertible.isNotEmpty && convertible.every((r) => _selectedEmpIds.contains(r.employeeId));

    return RefreshIndicator(
      onRefresh: _loadPreview,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Month Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  onPressed: () => _shiftMonth(-1),
                ),
                Text(
                  'Tháng $_month',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Warnings if any
          if (_preview != null && !_preview!.enabled)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quy tắc làm thêm và nghỉ bù chưa được bật cho tháng này nên không có giờ dư để chuyển đổi.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),

          if (_preview != null && _preview!.enabled && !_preview!.locked)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tháng này chưa chốt công. Số liệu dưới đây chỉ để xem; chuyển đổi sau khi chốt công.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),

          // Action Toolbar: Select all & Convert Button
          if (convertible.isNotEmpty && canConfirm)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedEmpIds.addAll(convertible.map((r) => r.employeeId));
                        } else {
                          _selectedEmpIds.clear();
                        }
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Chọn tất cả', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _selectedEmpIds.isEmpty || _isConverting ? null : _convertSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isConverting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Chuyển đổi (${_selectedEmpIds.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
              ),
            )
          else if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'Không có nhân viên nào có giờ làm thêm trong tháng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ...rows.map((r) {
              final isSel = _selectedEmpIds.contains(r.employeeId);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                ),
                child: InkWell(
                  onTap: r.isConvertible && canConfirm
                      ? () {
                          setState(() {
                            if (isSel) {
                              _selectedEmpIds.remove(r.employeeId);
                            } else {
                              _selectedEmpIds.add(r.employeeId);
                            }
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (canConfirm && r.isConvertible)
                              Checkbox(
                                value: isSel,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedEmpIds.add(r.employeeId);
                                    } else {
                                      _selectedEmpIds.remove(r.employeeId);
                                    }
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.employeeName ?? r.employeeId,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  if (r.employeeCode != null)
                                    Text(
                                      r.employeeCode!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(r),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 4 metrics grid
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricCol('Làm thêm', '${_formatNumber(r.actualOtHours)}h'),
                              _buildMetricCol('Tính lương', '${_formatNumber(r.countedOtHours)}h'),
                              _buildMetricCol('Giờ dư', '${_formatNumber(r.excessOtHours)}h'),
                              _buildMetricCol(
                                'Nghỉ bù',
                                '${_formatNumber(r.compDays)} ngày',
                                isHighlight: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(HrmCompOffConversionRow r) {
    Color bg;
    Color fg;
    switch (r.status) {
      case 'READY':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'CONVERTED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      case 'CAP_REACHED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        r.statusLabel,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
