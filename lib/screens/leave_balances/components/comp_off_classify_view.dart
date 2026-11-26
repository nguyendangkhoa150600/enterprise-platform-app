import 'package:flutter/material.dart';
import '../../../../models/hrm_leave_balance_models.dart';
import '../../../../services/hrm_service.dart';

/// Màn hình/Tab Phân loại làm thêm quỹ nghỉ bù (đồng bộ 1:1 với Web OvertimeClassifyPanel)
class CompOffClassifyView extends StatefulWidget {
  final HrmService hrmService;

  const CompOffClassifyView({
    super.key,
    required this.hrmService,
  });

  @override
  State<CompOffClassifyView> createState() => _CompOffClassifyViewState();
}

class _CompOffClassifyViewState extends State<CompOffClassifyView> {
  late String _month;
  List<HrmOvertimeMonthSummary> _rows = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadData();
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.hrmService.getOvertimeMonthSummary(_month);
      if (mounted) {
        setState(() {
          _rows = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không tải được dữ liệu làm thêm: $e';
          _isLoading = false;
        });
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
    return RefreshIndicator(
      onRefresh: _loadData,
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
          const SizedBox(height: 12),

          // Summary header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng hợp làm thêm (${_rows.length} nhân viên)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
          const SizedBox(height: 10),

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
          else if (_rows.isEmpty)
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
                  Icon(Icons.nights_stay_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có dữ liệu làm thêm của tháng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ..._rows.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                        Column(
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${r.blockCount} ca làm thêm',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Metrics 2x3 grid
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem('Làm thêm thực tế', '${_formatNumber(r.actualOtHours)}h'),
                              _buildMetricItem('Tính lương', '${_formatNumber(r.countedOtHours)}h'),
                              _buildMetricItem('Ca đêm', '${_formatNumber(r.nightHours)}h'),
                            ],
                          ),
                          const Divider(height: 12, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem('Giờ dư', '${_formatNumber(r.excessOtHours)}h'),
                              _buildMetricItem('Nghỉ bù đề xuất', '${_formatNumber(r.compDays)} ngày', isHighlight: true),
                              _buildMetricItem('Nghỉ sau đêm', '${_formatNumber(r.nightRestDays)} ngày'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, {bool isHighlight = false}) {
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
}
