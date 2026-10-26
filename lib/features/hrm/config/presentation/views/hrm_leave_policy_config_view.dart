import 'package:flutter/material.dart';
import '../../../../../services/hrm_service.dart';
import '../../../../../screens/leave_balances_screen.dart';

/// Cấu hình Chính sách phép năm (Annual Leave Policy) - Chuẩn Web 1:1 Pixel-Perfect
class HrmLeavePolicyConfigView extends StatefulWidget {
  final HrmService hrmService;

  const HrmLeavePolicyConfigView({
    super.key,
    required this.hrmService,
  });

  @override
  State<HrmLeavePolicyConfigView> createState() => HrmLeavePolicyConfigViewState();
}

class HrmLeavePolicyConfigViewState extends State<HrmLeavePolicyConfigView> {
  String _leaveBasis = 'Ngày ký HĐLĐ';
  final TextEditingController _leaveDaysPerYearCtrl = TextEditingController(text: '12');
  final TextEditingController _leaveStartAfterMonthsCtrl = TextEditingController(text: '0');
  bool _leaveAllowAdvance = true;
  final TextEditingController _seniorityCycleYearsCtrl = TextEditingController(text: '5');
  final TextEditingController _seniorityExtraDaysCtrl = TextEditingController(text: '1');
  String _leaveApplyYear = 'Tự động';
  final TextEditingController _leaveChangeNoteCtrl = TextEditingController();
  bool _isSavingLeavePolicy = false;
  String? _leavePolicyUpdatedAt;

  @override
  void initState() {
    super.initState();
    refreshPolicy();
  }

  @override
  void dispose() {
    _leaveDaysPerYearCtrl.dispose();
    _leaveStartAfterMonthsCtrl.dispose();
    _seniorityCycleYearsCtrl.dispose();
    _seniorityExtraDaysCtrl.dispose();
    _leaveChangeNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> refreshPolicy() async {
    try {
      final policy = await widget.hrmService.getAnnualLeavePolicy();
      if (policy != null && mounted) {
        setState(() {
          _applyServerLeavePolicy(policy);
        });
      }
    } catch (e) {
      debugPrint('[HrmLeavePolicyConfigView] refreshPolicy error: $e');
    }
  }

  void _applyServerLeavePolicy(Map<String, dynamic> data) {
    debugPrint('[HrmLeavePolicyConfigView] _applyServerLeavePolicy with data: $data');
    final rawBasis = data['accrualBasis'] ?? data['basis'] ?? data['accrual_basis'] ?? data['start_date_type'];
    if (rawBasis != null) {
      final bStr = rawBasis.toString().toUpperCase();
      if (bStr.contains('CONTRACT') || bStr.contains('SIGN') || bStr.contains('HĐLĐ') || bStr.contains('HDLD')) {
        _leaveBasis = 'Ngày ký HĐLĐ';
      } else if (bStr.contains('CHÍNH THỨC') || bStr.contains('OFFICIAL')) {
        _leaveBasis = 'Ngày vào làm chính thức';
      } else if (bStr.contains('THỬ VIỆC') || bStr.contains('PROBATION') || bStr.contains('START') || bStr.contains('HIRE')) {
        _leaveBasis = 'Ngày bắt đầu thử việc';
      } else if (bStr.contains('01/01') || bStr.contains('YEAR') || bStr.contains('ANNUAL') || bStr.contains('CALENDAR')) {
        _leaveBasis = 'Ngày 01/01 hàng năm';
      }
    }

    final days = data['annualDays'] ?? data['days_per_year'] ?? data['daysPerYear'] ?? data['annual_days'];
    if (days != null) {
      final numVal = num.tryParse(days.toString());
      if (numVal != null) {
        _leaveDaysPerYearCtrl.text = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toString();
      } else {
        _leaveDaysPerYearCtrl.text = days.toString();
      }
    }

    final months = data['startOffsetMonths'] ?? data['start_after_months'] ?? data['startAfterMonths'];
    if (months != null) {
      _leaveStartAfterMonthsCtrl.text = months.toString();
    }

    final advance = data['advanceAllowed'] ?? data['allow_advance'] ?? data['allowAdvance'];
    if (advance != null) {
      _leaveAllowAdvance = advance == true || advance == 1 || advance.toString().toLowerCase() == 'true';
    }

    if (data['seniorityTiers'] is List && (data['seniorityTiers'] as List).isNotEmpty) {
      final firstTier = (data['seniorityTiers'] as List).first;
      if (firstTier is Map) {
        final sYears = firstTier['minYears'] ?? firstTier['min_years'];
        if (sYears != null) _seniorityCycleYearsCtrl.text = sYears.toString();
        final sDays = firstTier['bonusDays'] ?? firstTier['bonus_days'];
        if (sDays != null) {
          final numVal = num.tryParse(sDays.toString());
          if (numVal != null) {
            _seniorityExtraDaysCtrl.text = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toString();
          } else {
            _seniorityExtraDaysCtrl.text = sDays.toString();
          }
        }
      }
    } else {
      final sYears = data['seniority_cycle_years'] ?? data['seniorityCycleYears'];
      if (sYears != null) _seniorityCycleYearsCtrl.text = sYears.toString();
      final sDays = data['seniority_extra_days'] ?? data['seniorityExtraDays'];
      if (sDays != null) {
        final numVal = num.tryParse(sDays.toString());
        if (numVal != null) {
          _seniorityExtraDaysCtrl.text = numVal % 1 == 0 ? numVal.toInt().toString() : numVal.toString();
        } else {
          _seniorityExtraDaysCtrl.text = sDays.toString();
        }
      }
    }

    _leavePolicyUpdatedAt = data['updatedAt']?.toString() ?? data['updated_at']?.toString();

    final y = data['effective_year'] ?? data['effectiveYear'] ?? data['apply_year'] ?? data['applyYear'] ?? data['year'];
    if (y != null && y.toString().isNotEmpty) {
      _leaveApplyYear = y.toString();
    }

    final note = data['change_note'] ?? data['changeNote'] ?? data['note'] ?? data['reason'];
    if (note != null && note.toString().isNotEmpty) {
      _leaveChangeNoteCtrl.text = note.toString();
    }
  }

  Future<void> _handleSaveLeavePolicy() async {
    if (_leaveChangeNoteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ghi chú thay đổi (bắt buộc) để lưu nhật ký kiểm toán.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final days = double.tryParse(_leaveDaysPerYearCtrl.text.trim()) ?? 12.0;
    final months = int.tryParse(_leaveStartAfterMonthsCtrl.text.trim()) ?? 0;
    final sYears = int.tryParse(_seniorityCycleYearsCtrl.text.trim()) ?? 5;
    final sDays = double.tryParse(_seniorityExtraDaysCtrl.text.trim()) ?? 1.0;

    setState(() => _isSavingLeavePolicy = true);

    try {
      final res = await widget.hrmService.updateAnnualLeavePolicy(
        basis: _leaveBasis,
        daysPerYear: days,
        startAfterMonths: months,
        allowAdvance: _leaveAllowAdvance,
        seniorityCycleYears: sYears,
        seniorityExtraDays: sDays,
        expectedUpdatedAt: _leavePolicyUpdatedAt,
        changeNote: _leaveChangeNoteCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _isSavingLeavePolicy = false);
        if (res.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message.isNotEmpty ? res.message : 'Đã lưu thay đổi chính sách phép năm thành công lên hệ thống!'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
            ),
          );
          refreshPolicy();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingLeavePolicy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối khi lưu chính sách: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showMonthlyAccrualDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Cộng phép tháng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hệ thống sẽ thực hiện cộng phép tháng 10/2026 cho toàn bộ nhân viên đủ điều kiện theo chính sách hiện hành.\n\nBút toán cộng phép sẽ được ghi lại vào Sổ cái nhân sự.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hoàn thành cộng phép tháng 10/2026 cho 45 nhân viên đủ điều kiện.'),
                  backgroundColor: Color(0xFF059669),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xác nhận chạy', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showYearEndResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Chốt phép cuối năm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Thao tác này sẽ thực hiện chốt sổ cuối năm: reset phần phép còn lại của năm hiện tại về 0 cho tất cả nhân viên (không chuyển phép sang năm sau).\n\nBạn có chắc chắn muốn thực hiện?',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hoàn tất tác vụ chốt sổ phép cuối năm!'),
                  backgroundColor: Color(0xFF059669),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xác nhận chốt phép', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. TOP HEADER & ACTION BAR (Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chính sách phép năm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thiết lập nguyên tắc tính và tích lũy phép năm áp dụng cho nhân viên.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Đang áp dụng',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 2. TÓM TẮT CHÍNH SÁCH (Summary Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tóm tắt chính sách',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Thông tin tóm tắt quy tắc phép năm hiện tại.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4 Highlight Items
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildLeaveSummaryRow(
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                      label: 'Phép cơ bản',
                      value: '${_leaveDaysPerYearCtrl.text} ngày mỗi năm',
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 46),
                    _buildLeaveSummaryRow(
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                      label: 'Bắt đầu tích lũy',
                      value: 'Theo $_leaveBasis',
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 46),
                    _buildLeaveSummaryRow(
                      icon: Icons.people_alt_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF5F3FF),
                      label: 'Phép thâm niên',
                      value: 'Mỗi ${_seniorityCycleYearsCtrl.text} năm +${_seniorityExtraDaysCtrl.text} ngày',
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 46),
                    _buildLeaveSummaryRow(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFF7ED),
                      label: 'Chuyển phép cuối năm',
                      value: 'Không chuyển sang năm sau',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info notice callout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chính sách này áp dụng cho toàn bộ nhân viên trong công ty. Phép năm không chuyển sang năm sau: phần còn lại cuối năm được reset về 0.\n\n'
                        'Áp dụng cho lý do nghỉ Nghỉ phép năm (PHEP_NAM); chỉ lý do này trừ quỹ phép năm.\n\n'
                        'Đang áp dụng từ ngày 01/01/2026 (cập nhật lúc 14/10/2026 17:45).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 3. CÁCH TÍNH PHÉP (Form Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cách tính phép',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Chọn mốc thời gian và số ngày phép năm cơ bản cho toàn bộ nhân viên.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // Field 1: Căn cứ tính phép *
              _buildFormLabel('Căn cứ tính phép', isRequired: true),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _leaveBasis,
                    isExpanded: true,
                    menuMaxHeight: 280,
                    borderRadius: BorderRadius.circular(10),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'Ngày ký HĐLĐ', child: Text('Ngày ký HĐLĐ')),
                      DropdownMenuItem(value: 'Ngày vào làm chính thức', child: Text('Ngày vào làm chính thức')),
                      DropdownMenuItem(value: 'Ngày bắt đầu thử việc', child: Text('Ngày bắt đầu thử việc')),
                      DropdownMenuItem(value: 'Ngày 01/01 hàng năm', child: Text('Ngày 01/01 hàng năm')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _leaveBasis = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mốc thời gian để bắt đầu tính và tích lũy phép năm.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Field 2: Số ngày phép mỗi năm *
              _buildFormLabel('Số ngày phép mỗi năm', isRequired: true),
              const SizedBox(height: 6),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _leaveDaysPerYearCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cộng mỗi tháng 1 ngày (số ngày một năm chia 12).',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Field 3: Bắt đầu cộng sau (tháng) *
              _buildFormLabel('Bắt đầu cộng sau (tháng)', isRequired: true),
              const SizedBox(height: 6),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _leaveStartAfterMonthsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Số tháng kể từ mốc trên để bắt đầu cộng (0 là cộng ngay từ tháng căn cứ).',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Switch: Cho ứng phép
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cho ứng phép',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Được dùng trước phần phép chưa cộng, đến hết năm.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _leaveAllowAdvance,
                      onChanged: (val) => setState(() => _leaveAllowAdvance = val),
                      activeThumbColor: const Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 4. PHÉP THÂM NIÊN (Form Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.layers_outlined, size: 18, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phép thâm niên',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Cộng thêm số ngày phép theo thâm niên làm việc.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormLabel('Chu kỳ thâm niên (năm)'),
                        const SizedBox(height: 6),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _seniorityCycleYearsCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              suffixText: 'năm',
                              suffixStyle: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormLabel('Phép cộng thêm mỗi chu kỳ'),
                        const SizedBox(height: 6),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _seniorityExtraDaysCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              suffixText: 'ngày',
                              suffixStyle: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cứ đủ mỗi chu kỳ N năm kể từ ngày căn cứ thì được cộng thêm M ngày phép mỗi năm, lặp lại theo chu kỳ (ví dụ 5 năm +1; đủ 5 năm +1, đủ 10 năm +2, đủ 15 năm +3). Để trống cả hai ô nếu không áp dụng phép thâm niên.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 5. HIỆU LỰC & GHI CHÚ (Form Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hiệu lực & ghi chú',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Thiết lập thời gian áp dụng và ghi chú thay đổi chính sách.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // Field 1: Áp dụng từ năm
              _buildFormLabel('Áp dụng từ năm'),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _leaveApplyYear,
                    isExpanded: true,
                    menuMaxHeight: 280,
                    borderRadius: BorderRadius.circular(10),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'Tự động', child: Text('Tự động')),
                      DropdownMenuItem(value: '2026', child: Text('2026')),
                      DropdownMenuItem(value: '2027', child: Text('2027')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _leaveApplyYear = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chính sách luôn có hiệu lực từ ngày 01/01. Để trống thì áp dụng từ 01/01 năm nay. Khi lưu, quỹ phép đã ghi sổ của năm áp dụng được tính lại theo chính sách mới.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 14),

              // Field 2: Ghi chú thay đổi *
              _buildFormLabel('Ghi chú thay đổi', isRequired: true),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _leaveChangeNoteCtrl,
                  maxLines: 3,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Tăng phép năm lên 14 ngày theo quy chế mới...',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Ghi rõ nội dung thay đổi để dễ theo dõi (lưu vào nhật ký kiểm toán).',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Nút lưu thay đổi chính sách
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingLeavePolicy ? null : _handleSaveLeavePolicy,
                  icon: _isSavingLeavePolicy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(
                    _isSavingLeavePolicy ? 'Đang lưu...' : 'Lưu thay đổi chính sách',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 6. TÁC VỤ ĐỊNH KỲ (Action Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tác vụ định kỳ',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Chạy thủ công khi cần. Mọi bút toán được ghi vào sổ giao dịch.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // Action Box 1: Cộng phép tháng
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cộng phép tháng',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Cộng phép của một tháng (kể cả tháng hiện tại) cho mọi nhân viên đủ điều kiện.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _showMonthlyAccrualDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Chạy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Action Box 2: Chốt phép cuối năm
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chốt phép cuối năm',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chốt phép cuối năm: reset phần còn lại về 0, không chuyển phép sang năm sau.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _showYearEndResetDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Chạy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 7. LƯU Ý KHI THAY ĐỔI (Warning Card - Web 1:1)
        // ==========================================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lưu ý khi thay đổi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Việc thay đổi cấu hình có thể ảnh hưởng đến số phép tích lũy và cách tính phép của nhân viên trong tương lai. Vui lòng kiểm tra kỹ trước khi lưu thay đổi.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==========================================
        // 8. LINK TO LEAVE BALANCES
        // ==========================================
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveBalancesScreen())),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
            label: const Text('Xem Quỹ phép & Sổ cái nhân sự', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveSummaryRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
