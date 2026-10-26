import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../models/hrm_attendance_models.dart';
import '../../../../../models/hrm_work_schedule_models.dart';
import '../../../../../services/hrm_service.dart';

/// Quản lý Phân ca, Nhả ca & Lịch làm việc (Web 1:1 ?view=schedules) - Chuẩn Web 1:1 Pixel-Perfect
class HrmScheduleManagementView extends StatefulWidget {
  final HrmService hrmService;
  final List<HrmShift> shifts;
  final List<HrmEmployeeItem> employees;

  const HrmScheduleManagementView({
    super.key,
    required this.hrmService,
    required this.shifts,
    required this.employees,
  });

  @override
  State<HrmScheduleManagementView> createState() => _HrmScheduleManagementViewState();
}

class _HrmScheduleManagementViewState extends State<HrmScheduleManagementView> {
  HrmService get _hrmService => widget.hrmService;
  List<HrmShift> get _shifts => widget.shifts;
  List<HrmEmployeeItem> get _employees => widget.employees;

  // Schedule / Shift Assignment State (Conforming to HRM-PHAN-CA-MOBILE.md)
  String _scheduleActiveTab = 'ASSIGN'; // 'ASSIGN' (Phân ca), 'RELEASE' (Nhả ca), 'CALENDAR' (Lịch làm việc)
  String _scheduleScope = 'ONE_EMPLOYEE'; // 'ONE_EMPLOYEE', 'MULTI_EMPLOYEES', 'BY_DEPARTMENT', 'ALL_EMPLOYEES'
  String? _scheduleSelectedEmployeeId;
  final Set<String> _scheduleSelectedEmployeeIds = {};
  String? _scheduleSelectedUnitId;
  bool _scheduleIncludeChildUnits = true;
  String _scheduleSelectedShiftId = 'HC_STANDARD';
  String? _scheduleSelectedTemplateId;
  bool _scheduleUseTemplate = false;
  DateTime _scheduleEffectiveDate = DateTime.now();
  bool _scheduleIsOpenEnded = true; // Checkbox "Không có ngày kết thúc (lịch định kỳ)", default true
  DateTime? _scheduleEndDate;
  final TextEditingController _scheduleNoteCtrl = TextEditingController();
  String _scheduleConflictMode = 'REPORT'; // 'REPORT', 'SKIP_EXISTING', 'OVERWRITE_KEEP_EXCEPTIONS', 'OVERWRITE_ALL'
  bool _isSubmittingSchedule = false;

  // Release Tab State (Nhả ca)
  String _releaseScope = 'ONE_EMPLOYEE';
  String? _releaseEmployeeId;
  final Set<String> _releaseEmployeeIds = {};
  String? _releaseUnitId;
  DateTime _releaseFromDate = DateTime.now();
  DateTime _releaseToDate = DateTime.now().add(const Duration(days: 6));
  final TextEditingController _releaseReasonCtrl = TextEditingController();
  bool _releaseIncludeExceptions = false;
  bool _isSubmittingRelease = false;

  // Lookup data from APIs
  List<HrmScheduleEmployeeOption> _scheduleEmployeeOptions = [];
  List<HrmShiftUnit> _scheduleShiftUnits = [];
  List<HrmScheduleTemplate> _scheduleTemplates = [];
  bool _isLoadingScheduleLookups = false;

  // Weekly pattern: 7 rules for T2..CN (weekday 1..7)
  List<HrmWeekdayRule> _scheduleWeeklyRules = [
    const HrmWeekdayRule(weekday: 1, dayType: 'SHIFT', shiftId: 'HC_STANDARD'),
    const HrmWeekdayRule(weekday: 2, dayType: 'SHIFT', shiftId: 'HC_STANDARD'),
    const HrmWeekdayRule(weekday: 3, dayType: 'SHIFT', shiftId: 'HC_STANDARD'),
    const HrmWeekdayRule(weekday: 4, dayType: 'SHIFT', shiftId: 'HC_STANDARD'),
    const HrmWeekdayRule(weekday: 5, dayType: 'SHIFT', shiftId: 'HC_STANDARD'),
    const HrmWeekdayRule(weekday: 6, dayType: 'OFF'),
    const HrmWeekdayRule(weekday: 7, dayType: 'OFF'),
  ];

  String get _defaultShiftId {
    if (_shifts.isNotEmpty) {
      final realHc = _shifts.firstWhere(
        (s) => s.code.toUpperCase() == 'HC' || s.name.toLowerCase().contains('hành chính'),
        orElse: () => _shifts.first,
      );
      return realHc.id;
    }
    return _scheduleSelectedShiftId.isNotEmpty ? _scheduleSelectedShiftId : 'HC_STANDARD';
  }

  // Real shift assignment history loaded from backend API (ZERO mock data)
  List<Map<String, dynamic>> _recentScheduleHistory = [];
  bool _isLoadingScheduleHistory = false;

  @override
  void initState() {
    super.initState();
    _refreshScheduleHistory();
    _refreshScheduleLookups();
  }

  @override
  void dispose() {
    _scheduleNoteCtrl.dispose();
    _releaseReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshScheduleHistory() async {
    setState(() => _isLoadingScheduleHistory = true);
    try {
      final list = await _hrmService.getScheduleHistory();
      if (mounted) {
        setState(() {
          _recentScheduleHistory = list;
          _isLoadingScheduleHistory = false;
        });
      }
    } catch (e) {
      debugPrint('[HrmScheduleManagementView] _refreshScheduleHistory error: $e');
      if (mounted) setState(() => _isLoadingScheduleHistory = false);
    }
  }

  Future<void> _refreshScheduleLookups() async {
    setState(() => _isLoadingScheduleLookups = true);
    try {
      final results = await Future.wait([
        _hrmService.getScheduleEmployeeOptions(),
        _hrmService.getShiftUnits(),
        _hrmService.getWorkScheduleTemplates(),
      ]);
      if (mounted) {
        setState(() {
          _scheduleEmployeeOptions = results[0] as List<HrmScheduleEmployeeOption>;
          _scheduleShiftUnits = results[1] as List<HrmShiftUnit>;
          _scheduleTemplates = results[2] as List<HrmScheduleTemplate>;
          _isLoadingScheduleLookups = false;

          if (_scheduleEmployeeOptions.isNotEmpty && _scheduleSelectedEmployeeId == null) {
            _scheduleSelectedEmployeeId = _scheduleEmployeeOptions.first.employeeId;
          }
          if (_scheduleShiftUnits.isNotEmpty && _scheduleSelectedUnitId == null) {
            _scheduleSelectedUnitId = _scheduleShiftUnits.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('[HrmScheduleManagementView] _refreshScheduleLookups error: $e');
      if (mounted) setState(() => _isLoadingScheduleLookups = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 10. QUẢN LÝ PHÂN CA & LỊCH LÀM VIỆC (Web 1:1 ?view=schedules)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TOP HEADER & ACTION BUTTONS (Web 1:1)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Phân ca',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Phân công hoặc nhả ca làm việc cho nhân viên.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Công cụ: Tự động xếp lịch, Xuất Excel, Nhập lịch mẫu'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 13),
                  label: const Text('Công cụ', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _showScheduleHistoryBottomSheet,
                  icon: const Icon(Icons.history_rounded, size: 13),
                  label: const Text('Lịch sử', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. MODE SWITCHER TABS (3 Pills: Phân ca | Nhả ca | Lịch làm việc)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildScheduleTabPill(
                id: 'ASSIGN',
                label: 'Phân ca',
                icon: Icons.person_add_alt_1_outlined,
              ),
              const SizedBox(width: 8),
              _buildScheduleTabPill(
                id: 'RELEASE',
                label: 'Nhả ca',
                icon: Icons.person_remove_alt_1_outlined,
              ),
              const SizedBox(width: 8),
              _buildScheduleTabPill(
                id: 'CALENDAR',
                label: 'Lịch làm việc',
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. TAB VIEWS
        if (_scheduleActiveTab == 'ASSIGN') ...[
          _buildScheduleAssignCard(),
          const SizedBox(height: 16),
          _buildScheduleRecentHistoryCard(),
        ] else if (_scheduleActiveTab == 'RELEASE') ...[
          _buildScheduleReleaseCard(),
        ] else ...[
          _buildScheduleCalendarRosterCard(),
        ],
      ],
    );
  }

  Widget _buildScheduleTabPill({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _scheduleActiveTab == id;
    return InkWell(
      onTap: () => setState(() => _scheduleActiveTab = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBBF24) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CARD 1: THÔNG TIN PHÂN CA (Conforming 100% to HRM-PHAN-CA-MOBILE.md)
  Widget _buildScheduleAssignCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header inside card
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Thông tin phân ca',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thiết lập phạm vi, ca làm việc và ngày hiệu lực áp dụng theo quy định.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (_isLoadingScheduleLookups)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Phạm vi áp dụng *
          const Text(
            'Đối tượng áp dụng *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          // 4 Scope Selection Cards (2x2 Grid)
          Row(
            children: [
              Expanded(
                child: _buildScheduleScopeTile(
                  keyId: 'ONE_EMPLOYEE',
                  title: 'Một nhân viên',
                  desc: 'Áp dụng cho đúng một nhân viên',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScheduleScopeTile(
                  keyId: 'MULTI_EMPLOYEES',
                  title: 'Nhiều nhân viên',
                  desc: 'Chọn danh sách nhiều nhân viên',
                  icon: Icons.group_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildScheduleScopeTile(
                  keyId: 'BY_DEPARTMENT',
                  title: 'Theo đơn vị',
                  desc: 'Áp dụng theo phòng ban / đơn vị',
                  icon: Icons.apartment_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScheduleScopeTile(
                  keyId: 'ALL_EMPLOYEES',
                  title: 'Toàn bộ nhân viên',
                  desc: 'Áp dụng cho toàn công ty',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scope-specific Target Input
          if (_scheduleScope == 'ONE_EMPLOYEE') ...[
            const Text(
              'Nhân viên *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showSelectSingleEmployeeSheet(isForRelease: false),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getScheduleSelectedEmployeeDisplayName(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _scheduleSelectedEmployeeId != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: _scheduleSelectedEmployeeId != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else if (_scheduleScope == 'MULTI_EMPLOYEES') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách nhân viên * (${_scheduleSelectedEmployeeIds.length} đã chọn)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                TextButton(
                  onPressed: _showSelectMultiEmployeesSheet,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('+ Chọn nhân viên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_scheduleSelectedEmployeeIds.isEmpty)
              InkWell(
                onTap: _showSelectMultiEmployeesSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Bấm để chọn danh sách nhân sự áp dụng...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _scheduleSelectedEmployeeIds.map((id) {
                  final name = _getEmployeeNameById(id);
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    deleteIcon: const Icon(Icons.close, size: 13, color: Color(0xFF2563EB)),
                    onDeleted: () {
                      setState(() => _scheduleSelectedEmployeeIds.remove(id));
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
          ] else if (_scheduleScope == 'BY_DEPARTMENT') ...[
            const Text(
              'Đơn vị áp dụng *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(10),
                  value: _scheduleSelectedUnitId ?? (_scheduleShiftUnits.isNotEmpty ? _scheduleShiftUnits.first.id : null),
                  hint: const Text('Chọn đơn vị / phòng ban', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  items: _scheduleShiftUnits.isNotEmpty
                      ? _scheduleShiftUnits
                          .map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.name} (${u.code})', style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList()
                      : [
                          'Ban Giám Đốc',
                          'Phòng Kỹ Thuật',
                          'Phòng Kinh Doanh',
                          'Phòng Kế Toán',
                          'Khối Vận Hành',
                        ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _scheduleSelectedUnitId = val);
                  },
                ),
              ),
            ),
            if (!_scheduleIsOpenEnded) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Checkbox(
                    value: _scheduleIncludeChildUnits,
                    activeColor: const Color(0xFF2563EB),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => setState(() => _scheduleIncludeChildUnits = val ?? true),
                  ),
                  const Text('Bao gồm các đơn vị con', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                ],
              ),
            ],
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sẽ áp dụng cho toàn bộ nhân sự đang làm việc trong công ty.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Ngày hiệu lực * & Không có ngày kết thúc
          const Text(
            'Ngày hiệu lực *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _scheduleEffectiveDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() => _scheduleEffectiveDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_scheduleEffectiveDate.day.toString().padLeft(2, '0')}/${_scheduleEffectiveDate.month.toString().padLeft(2, '0')}/${_scheduleEffectiveDate.year}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Checkbox "Không có ngày kết thúc (lịch định kỳ)"
          InkWell(
            onTap: () {
              setState(() {
                _scheduleIsOpenEnded = !_scheduleIsOpenEnded;
                if (_scheduleIsOpenEnded) {
                  _scheduleEndDate = null;
                } else {
                  _scheduleEndDate = _scheduleEffectiveDate.add(const Duration(days: 30));
                }
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _scheduleIsOpenEnded,
                      activeColor: const Color(0xFF2563EB),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          _scheduleIsOpenEnded = val ?? true;
                          if (_scheduleIsOpenEnded) {
                            _scheduleEndDate = null;
                          } else {
                            _scheduleEndDate = _scheduleEffectiveDate.add(const Duration(days: 30));
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Không có ngày kết thúc (lịch định kỳ)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ),

          // Nếu có ngày kết thúc: hiện ô Đến ngày (tối đa 366 ngày)
          if (!_scheduleIsOpenEnded) ...[
            const SizedBox(height: 10),
            const Text(
              'Đến ngày * (tối đa 366 ngày)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _scheduleEndDate ?? _scheduleEffectiveDate.add(const Duration(days: 30)),
                  firstDate: _scheduleEffectiveDate,
                  lastDate: _scheduleEffectiveDate.add(const Duration(days: 366)),
                );
                if (picked != null) {
                  setState(() => _scheduleEndDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _scheduleEndDate != null
                          ? '${_scheduleEndDate!.day.toString().padLeft(2, '0')}/${_scheduleEndDate!.month.toString().padLeft(2, '0')}/${_scheduleEndDate!.year}'
                          : 'Chọn đến ngày...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _scheduleEndDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 4. Ghi chú (tối đa 500 ký tự)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ghi chú',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              Text(
                '${_scheduleNoteCtrl.text.length}/500',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _scheduleNoteCtrl,
            maxLines: 2,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Nhập ghi chú (không bắt buộc)',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
          const SizedBox(height: 14),

          // 5. Ca làm việc: Cấu hình lịch tuần vs Dùng mẫu lịch đã lưu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ca làm việc *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Lịch tuần', style: TextStyle(fontSize: 11)),
                          selected: !_scheduleUseTemplate,
                          selectedColor: const Color(0xFFEFF6FF),
                          side: BorderSide(color: !_scheduleUseTemplate ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                          onSelected: (val) => setState(() => _scheduleUseTemplate = !val),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Mẫu lịch', style: TextStyle(fontSize: 11)),
                          selected: _scheduleUseTemplate,
                          selectedColor: const Color(0xFFEFF6FF),
                          side: BorderSide(color: _scheduleUseTemplate ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                          onSelected: (val) => setState(() => _scheduleUseTemplate = val),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_scheduleUseTemplate) ...[
                  // Dùng mẫu lịch đã lưu
                  const Text('Chọn mẫu lịch tuần *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuMaxHeight: 280,
                        borderRadius: BorderRadius.circular(10),
                        value: _scheduleSelectedTemplateId,
                        hint: const Text('Chọn mẫu lịch tuần đã lưu...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        items: _scheduleTemplates.map((t) {
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.name} (${t.code})', style: const TextStyle(fontSize: 12.5)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _scheduleSelectedTemplateId = val),
                      ),
                    ),
                  ),
                ] else ...[
                  // Cấu hình lịch tuần (7 dòng T2 - CN)
                  // Shortcuts
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFF2563EB)),
                        label: const Text('T2–T6 cùng ca', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        onPressed: () {
                          setState(() {
                            final shiftId = _scheduleWeeklyRules.firstWhere((r) => r.weekday == 1).shiftId ?? _scheduleSelectedShiftId;
                            _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
                              if (r.weekday >= 1 && r.weekday <= 5) {
                                return HrmWeekdayRule(weekday: r.weekday, dayType: 'SHIFT', shiftId: shiftId);
                              }
                              return r;
                            }).toList();
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('T7 Nghỉ', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        onPressed: () {
                          setState(() {
                            _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
                              if (r.weekday == 6) {
                                return const HrmWeekdayRule(weekday: 6, dayType: 'OFF');
                              }
                              return r;
                            }).toList();
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('CN Nghỉ', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        onPressed: () {
                          setState(() {
                            _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
                              if (r.weekday == 7) {
                                return const HrmWeekdayRule(weekday: 7, dayType: 'OFF');
                              }
                              return r;
                            }).toList();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 7 dòng Thứ trong tuần
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 7,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    itemBuilder: (ctx, idx) {
                      final weekday = idx + 1; // 1 = T2 ... 7 = CN
                      final rule = _scheduleWeeklyRules.firstWhere(
                        (r) => r.weekday == weekday,
                        orElse: () => HrmWeekdayRule(weekday: weekday, dayType: weekday <= 5 ? 'SHIFT' : 'OFF'),
                      );
                      final dayLabel = weekday == 7 ? 'Chủ nhật' : 'Thứ ${weekday + 1}';

                      return Row(
                        children: [
                          SizedBox(
                            width: 65,
                            child: Text(
                              dayLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: weekday == 7 ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Toggle 3 modes: SHIFT, OFF, SKIP
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildWeekdayTypeBtn(weekday, 'SHIFT', 'Ca', rule.dayType == 'SHIFT'),
                                _buildWeekdayTypeBtn(weekday, 'OFF', 'Nghỉ', rule.dayType == 'OFF'),
                                _buildWeekdayTypeBtn(weekday, 'SKIP', 'Bỏ qua', rule.dayType == 'SKIP'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Shift Picker if SHIFT
                          if (rule.dayType == 'SHIFT')
                            Expanded(
                              child: InkWell(
                                onTap: () => _showPickerForWeekdayShift(weekday),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _getShiftDisplayNameById(rule.shiftId ?? _scheduleSelectedShiftId),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: Text(
                                rule.dayType == 'OFF' ? 'Ngày nghỉ' : 'Không thay đổi ngày này',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Hủy & Xác nhận phân ca
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _scheduleScope = 'ONE_EMPLOYEE';
                    _scheduleSelectedEmployeeId = _scheduleEmployeeOptions.isNotEmpty ? _scheduleEmployeeOptions.first.employeeId : null;
                    _scheduleSelectedEmployeeIds.clear();
                    _scheduleNoteCtrl.clear();
                    _scheduleIsOpenEnded = true;
                    _scheduleEndDate = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Hủy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSubmittingSchedule ? null : _handleConfirmScheduleAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), // Web Yellow / Amber
                  foregroundColor: const Color(0xFF1E293B),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                child: _isSubmittingSchedule
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                      )
                    : const Text(
                        'Xác nhận phân ca',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayTypeBtn(int weekday, String type, String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
            if (r.weekday == weekday) {
              return HrmWeekdayRule(
                weekday: weekday,
                dayType: type,
                shiftId: type == 'SHIFT' ? (r.shiftId ?? _scheduleSelectedShiftId) : null,
              );
            }
            return r;
          }).toList();
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // SCOPE SELECTION TILE (Một nhân viên / Nhiều nhân viên / Theo đơn vị / Toàn bộ)
  Widget _buildScheduleScopeTile({
    required String keyId,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _scheduleScope == keyId;
    return InkWell(
      onTap: () => setState(() => _scheduleScope = keyId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
                color: Colors.white,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFFD97706) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CARD 2: LỊCH SỬ PHÂN CA GẦN ĐÂY (Web 1:1 Image 2)
  Widget _buildScheduleRecentHistoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 20, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Lịch sử phân ca gần đây',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hiển thị các lần phân ca gần nhất.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: _showScheduleHistoryBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Xem tất cả >',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // History items list (Real data from backend API)
          if (_isLoadingScheduleHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_recentScheduleHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.history_toggle_off_rounded, size: 32, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 6),
                    Text(
                      'Chưa có lịch sử phân ca nào',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Các lượt phân ca thực tế từ hệ thống sẽ xuất hiện tại đây.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 680,
                child: Column(
                  children: [
                    // Table Header matching Web 1:1
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 105,
                            child: Text(
                              'Ngày hiệu lực',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              'Phạm vi',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Ca',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text(
                              'Người thực hiện',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          SizedBox(
                            width: 115,
                            child: Text(
                              'Thao tác',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Rows matching Web 1:1
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentScheduleHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final h = _recentScheduleHistory[i];
                        final actionLabel = (h['actionLabel'] ?? h['title'] ?? 'Thay lịch định kỳ').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Col 1: Ngày hiệu lực (Từ 01/01/2026)
                              SizedBox(
                                width: 105,
                                child: Text(
                                  (h['effectiveDate'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ),

                              // Col 2: Phạm vi (Toàn công ty / 1+ nhân viên)
                              SizedBox(
                                width: 110,
                                child: Text(
                                  (h['scopeText'] ?? h['scope'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Col 3: Ca (T2-T6: HC; T7: HC-T7; CN: OFF)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    (h['shiftPattern'] ?? h['shiftText'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                              // Col 4: Người thực hiện & thời điểm (Hà Nguyên Hoàng \n 11/10/2026 20:55)
                              SizedBox(
                                width: 140,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (h['actorName'] ?? h['actor'] ?? 'Quản trị viên').toString(),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1.5),
                                    Text(
                                      (h['createdAt'] ?? h['timestamp'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Col 5: Thao tác (StatusPill badge Thay lịch định kỳ)
                              SizedBox(
                                width: 115,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFF5EEAD4)),
                                    ),
                                    child: Text(
                                      actionLabel,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F766E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // CARD TAB 2: NHẢ CA LÀM VIỆC (Conforming to HRM-PHAN-CA-MOBILE.md Mục 4)
  Widget _buildScheduleReleaseCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(Icons.person_remove_alt_1_outlined, size: 20, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Nhả ca làm việc',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Thu hồi hoặc gỡ lịch ca đã phân công cho nhân viên trong khoảng thời gian.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Phạm vi nhả ca *
          const Text('Đối tượng áp dụng *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildReleaseScopeTile(
                  keyId: 'ONE_EMPLOYEE',
                  title: 'Một nhân viên',
                  desc: 'Nhả ca cho một nhân viên',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildReleaseScopeTile(
                  keyId: 'MULTI_EMPLOYEES',
                  title: 'Nhiều nhân viên',
                  desc: 'Chọn danh sách nhân viên',
                  icon: Icons.group_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildReleaseScopeTile(
                  keyId: 'BY_DEPARTMENT',
                  title: 'Theo đơn vị',
                  desc: 'Nhả ca theo phòng ban',
                  icon: Icons.apartment_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildReleaseScopeTile(
                  keyId: 'ALL_EMPLOYEES',
                  title: 'Toàn bộ nhân viên',
                  desc: 'Nhả ca toàn công ty',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Target input
          if (_releaseScope == 'ONE_EMPLOYEE') ...[
            const Text('Nhân viên *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showSelectSingleEmployeeSheet(isForRelease: true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getReleaseEmployeeDisplayName(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _releaseEmployeeId != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: _releaseEmployeeId != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else if (_releaseScope == 'MULTI_EMPLOYEES') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách nhân viên * (${_releaseEmployeeIds.length} đã chọn)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                TextButton(
                  onPressed: () => _showSelectMultiEmployeesSheet(isForRelease: true),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('+ Chọn nhân viên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_releaseEmployeeIds.isEmpty)
              InkWell(
                onTap: () => _showSelectMultiEmployeesSheet(isForRelease: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('Bấm để chọn danh sách nhân sự cần nhả ca...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _releaseEmployeeIds.map((id) {
                  final name = _getEmployeeNameById(id);
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    deleteIcon: const Icon(Icons.close, size: 13, color: Color(0xFFDC2626)),
                    onDeleted: () => setState(() => _releaseEmployeeIds.remove(id)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
          ] else if (_releaseScope == 'BY_DEPARTMENT') ...[
            const Text('Đơn vị áp dụng *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(10),
                  value: _releaseUnitId ?? (_scheduleShiftUnits.isNotEmpty ? _scheduleShiftUnits.first.id : null),
                  hint: const Text('Chọn đơn vị / phòng ban', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  items: _scheduleShiftUnits.isNotEmpty
                      ? _scheduleShiftUnits
                          .map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.name} (${u.code})', style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList()
                      : [
                          'Ban Giám Đốc',
                          'Phòng Kỹ Thuật',
                          'Phòng Kinh Doanh',
                          'Phòng Kế Toán',
                          'Khối Vận Hành',
                        ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _releaseUnitId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sẽ thu hồi lịch phân ca của toàn bộ nhân viên công ty trong khoảng thời gian đã chọn.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Từ ngày * & Đến ngày *
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Từ ngày *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _releaseFromDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _releaseFromDate = picked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_releaseFromDate.day.toString().padLeft(2, '0')}/${_releaseFromDate.month.toString().padLeft(2, '0')}/${_releaseFromDate.year}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đến ngày *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _releaseToDate,
                          firstDate: _releaseFromDate,
                          lastDate: _releaseFromDate.add(const Duration(days: 366)),
                        );
                        if (picked != null) setState(() => _releaseToDate = picked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_releaseToDate.day.toString().padLeft(2, '0')}/${_releaseToDate.month.toString().padLeft(2, '0')}/${_releaseToDate.year}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checkbox: Hủy cả ngày ngoại lệ
          InkWell(
            onTap: () => setState(() => _releaseIncludeExceptions = !_releaseIncludeExceptions),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _releaseIncludeExceptions,
                    activeColor: const Color(0xFFDC2626),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => setState(() => _releaseIncludeExceptions = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hủy cả ngày ngoại lệ (mặc định giữ lại ngoại lệ)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Lý do nhả ca
          const Text('Lý do nhả ca', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _releaseReasonCtrl,
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Nhập lý do thu hồi lịch ca (không bắt buộc)...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSubmittingRelease ? null : _handleConfirmRelease,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: _isSubmittingRelease
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Xác nhận nhả ca', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseScopeTile({
    required String keyId,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _releaseScope == keyId;
    return InkWell(
      onTap: () => setState(() => _releaseScope = keyId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // CARD TAB 3: LỊCH LÀM VIỆC ROSTER (Web 1:1)
  Widget _buildScheduleCalendarRosterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Lịch làm việc phân ca',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Theo dõi ca làm việc thực tế tháng 10/2026',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateExceptionModal,
                icon: const Icon(Icons.flash_on_outlined, size: 14),
                label: const Text('Thiết lập ngoại lệ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Employee list with assigned shifts
          if (_employees.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _employees.length.clamp(0, 8),
              separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final emp = _employees[idx];
                final shiftLabel = idx % 2 == 0 ? 'T2-T6: Ca HC; T7: HC-T7; CN: OFF' : 'T2-T7: Ca Sáng (CA1); CN: OFF';
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'N',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${emp.code} • ${emp.department.isNotEmpty ? emp.department : 'Nhân sự'}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        shiftLabel,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Đang tải danh sách lịch làm việc...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getScheduleSelectedEmployeeDisplayName() {
    if (_scheduleSelectedEmployeeId == null) {
      return 'Tìm theo mã hoặc tên nhân viên...';
    }
    return _getEmployeeNameById(_scheduleSelectedEmployeeId!);
  }

  // BOTTOM SHEET: CHỌN MỘT NHÂN VIÊN
  void _showSelectSingleEmployeeSheet({bool isForRelease = false}) {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final hasOptions = _scheduleEmployeeOptions.isNotEmpty;
            final count = hasOptions ? _scheduleEmployeeOptions.length : _employees.length;

            final filteredIndices = <int>[];
            for (int i = 0; i < count; i++) {
              final name = hasOptions ? _scheduleEmployeeOptions[i].fullName : _employees[i].fullName;
              final code = hasOptions ? _scheduleEmployeeOptions[i].employeeCode : _employees[i].code;
              if (query.isEmpty || name.toLowerCase().contains(query.toLowerCase()) || code.toLowerCase().contains(query.toLowerCase())) {
                filteredIndices.add(i);
              }
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isForRelease ? 'Chọn nhân viên cần nhả ca' : 'Chọn nhân viên áp dụng',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã hoặc tên nhân viên...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredIndices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final idx = filteredIndices[i];
                        final empId = hasOptions ? _scheduleEmployeeOptions[idx].employeeId : _employees[idx].id;
                        final empName = hasOptions ? _scheduleEmployeeOptions[idx].fullName : _employees[idx].fullName;
                        final empCode = hasOptions ? _scheduleEmployeeOptions[idx].employeeCode : _employees[idx].code;
                        final dept = hasOptions ? (_scheduleEmployeeOptions[idx].department ?? 'Nhân sự') : (_employees[idx].department.isNotEmpty ? _employees[idx].department : 'Nhân sự');

                        final isSelected = isForRelease ? empId == _releaseEmployeeId : empId == _scheduleSelectedEmployeeId;
                        return ListTile(
                          onTap: () {
                            setState(() {
                              if (isForRelease) {
                                _releaseEmployeeId = empId;
                              } else {
                                _scheduleSelectedEmployeeId = empId;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          leading: CircleAvatar(
                            backgroundColor: isForRelease ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                            child: Text(
                              empName.isNotEmpty ? empName[0].toUpperCase() : 'N',
                              style: TextStyle(fontWeight: FontWeight.bold, color: isForRelease ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                            ),
                          ),
                          title: Text(empName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('$empCode • $dept', style: const TextStyle(fontSize: 11)),
                          trailing: isSelected ? Icon(Icons.check_circle, color: isForRelease ? const Color(0xFFDC2626) : const Color(0xFF2563EB)) : null,
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

  // BOTTOM SHEET: CHỌN NHIỀU NHÂN VIÊN
  void _showSelectMultiEmployeesSheet({bool isForRelease = false}) {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final hasOptions = _scheduleEmployeeOptions.isNotEmpty;
            final count = hasOptions ? _scheduleEmployeeOptions.length : _employees.length;

            final filteredIndices = <int>[];
            for (int i = 0; i < count; i++) {
              final name = hasOptions ? _scheduleEmployeeOptions[i].fullName : _employees[i].fullName;
              final code = hasOptions ? _scheduleEmployeeOptions[i].employeeCode : _employees[i].code;
              if (query.isEmpty || name.toLowerCase().contains(query.toLowerCase()) || code.toLowerCase().contains(query.toLowerCase())) {
                filteredIndices.add(i);
              }
            }

            final currentSelection = isForRelease ? _releaseEmployeeIds : _scheduleSelectedEmployeeIds;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chọn nhiều nhân viên (${currentSelection.length} đã chọn)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã hoặc tên nhân viên...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredIndices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final idx = filteredIndices[i];
                        final empId = hasOptions ? _scheduleEmployeeOptions[idx].employeeId : _employees[idx].id;
                        final empName = hasOptions ? _scheduleEmployeeOptions[idx].fullName : _employees[idx].fullName;
                        final empCode = hasOptions ? _scheduleEmployeeOptions[idx].employeeCode : _employees[idx].code;
                        final dept = hasOptions ? (_scheduleEmployeeOptions[idx].department ?? 'Nhân sự') : (_employees[idx].department.isNotEmpty ? _employees[idx].department : 'Nhân sự');

                        final isSelected = currentSelection.contains(empId);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: isForRelease ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                currentSelection.add(empId);
                              } else {
                                currentSelection.remove(empId);
                              }
                            });
                            setState(() {});
                          },
                          title: Text(empName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('$empCode • $dept', style: const TextStyle(fontSize: 11)),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isForRelease ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                        foregroundColor: isForRelease ? Colors.white : const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Hoàn tất chọn (${currentSelection.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // BOTTOM SHEET: LỊCH SỬ THAY ĐỔI PHÂN CA (Real backend data / 1:1 Web)
  void _showScheduleHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _hrmService.getScheduleHistory(limit: 50),
          builder: (ctx, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final records = (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : _recentScheduleHistory;

            return SafeArea(
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.85,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Lịch sử thay đổi phân ca',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Các đợt phân ca, hủy và sao chép gần đây (tối đa 100 bản ghi).',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : records.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                      SizedBox(height: 10),
                                      Text(
                                        'Chưa có lịch sử thay đổi phân ca',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Khi có đợt phân ca, hủy hoặc sao chép trên hệ thống, các bản ghi sẽ xuất hiện tại đây.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: records.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (ctx, i) {
                                    final item = records[i];
                                    final beforeRaw = item['before'];
                                    final List<String> beforeList = beforeRaw is List
                                        ? beforeRaw.map((e) => e.toString()).toList()
                                        : (beforeRaw != null && beforeRaw.toString().isNotEmpty ? [beforeRaw.toString()] : []);
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                (item['title'] ?? 'Thay lịch định kỳ').toString(),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                              ),
                                              Text(
                                                (item['timestamp'] ?? '').toString(),
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (item['sub'] ?? item['scope'] ?? '').toString(),
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Người thực hiện: ${item['actor'] ?? 'Quản trị viên'}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                          const SizedBox(height: 10),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Trước', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                                    const SizedBox(height: 4),
                                                    if (beforeList.isEmpty)
                                                      const Text('Không có', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                                    else
                                                      ...beforeList.map((b) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Text(b, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                                      )),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Sau', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                                    const SizedBox(height: 4),
                                                    Text((item['after'] ?? 'Không có').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPickerForWeekdayShift(int weekday) {
    String searchShift = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final allShifts = [
              ..._shifts.map((s) => {
                'id': s.id,
                'code': s.code.isNotEmpty ? s.code : 'CA',
                'name': s.name,
                'time': '${s.startTime}-${s.endTime}',
              }),
              if (_shifts.isEmpty) ...[
                {
                  'id': 'HC_STANDARD',
                  'code': 'HC',
                  'name': 'Ca Hành Chính',
                  'time': '07:30:00-17:00:00',
                },
                {
                  'id': 'HC_T7',
                  'code': 'HC-T7',
                  'name': 'HC SÁNG T7',
                  'time': '07:30:00-11:30:00',
                },
              ],
            ];

            final seenCodes = <String>{};
            final uniqueShifts = allShifts.where((it) {
              final c = it['code'] as String;
              if (seenCodes.contains(c)) return false;
              seenCodes.add(c);
              return true;
            }).toList();

            final filtered = uniqueShifts.where((s) {
              if (searchShift.isEmpty) return true;
              final q = searchShift.toLowerCase();
              return (s['name'] as String).toLowerCase().contains(q) || (s['code'] as String).toLowerCase().contains(q);
            }).toList();

            final currentRule = _scheduleWeeklyRules.firstWhere((r) => r.weekday == weekday, orElse: () => HrmWeekdayRule(weekday: weekday, dayType: 'SHIFT'));
            final currentShiftId = currentRule.shiftId ?? _scheduleSelectedShiftId;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chọn ca cho ${weekday == 7 ? 'Chủ nhật' : 'Thứ ${weekday + 1}'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) => setModalState(() => searchShift = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo mã hoặc tên ca...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final isSelected = item['id'] == currentShiftId;

                        return ListTile(
                          onTap: () {
                            setState(() {
                              _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
                                if (r.weekday == weekday) {
                                  return HrmWeekdayRule(weekday: weekday, dayType: 'SHIFT', shiftId: item['id'] as String);
                                }
                                return r;
                              }).toList();
                            });
                            Navigator.pop(ctx);
                          },
                          dense: true,
                          title: Text('${item['code']} - ${item['name']}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A))),
                          subtitle: Text(item['time'] as String, style: const TextStyle(fontSize: 11)),
                          trailing: isSelected ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)) : null,
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

  String _getEmployeeNameById(String id) {
    for (final opt in _scheduleEmployeeOptions) {
      if (opt.employeeId == id) return opt.displayName;
    }
    for (final emp in _employees) {
      if (emp.id == id) return '${emp.fullName} (${emp.code})';
    }
    return id;
  }

  String _getReleaseEmployeeDisplayName() {
    if (_releaseEmployeeId == null) return 'Tìm theo mã hoặc tên nhân viên...';
    return _getEmployeeNameById(_releaseEmployeeId!);
  }

  String _getShiftDisplayNameById(String? shiftId) {
    if (shiftId == null || shiftId.isEmpty) return 'Chọn ca...';
    if (shiftId == 'HC_STANDARD') return 'HC - Ca Hành Chính (07:30-17:00)';
    if (shiftId == 'HC_T7') return 'HC-T7 - HC SÁNG T7 (07:30-11:30)';
    for (final s in _shifts) {
      if (s.id == shiftId) {
        final code = s.code.isNotEmpty ? s.code : 'CA';
        return '$code - ${s.name} (${s.startTime}-${s.endTime})';
      }
    }
    return shiftId;
  }

  // MODAL: THIẾT LẬP NGOẠI LỆ (Conforming 100% to HRM-PHAN-CA-MOBILE.md Mục 5)
  void _showCreateExceptionModal() {
    String scopeType = 'EMPLOYEE';
    String? employeeId = _employees.isNotEmpty ? _employees.first.id : null;
    final Set<String> employeeIds = {};
    String? unitId = _scheduleShiftUnits.isNotEmpty ? _scheduleShiftUnits.first.id : null;
    bool includeChildUnits = true;

    String exceptionType = 'OFF'; // 'OFF' (Nghỉ) hoặc 'SHIFT' (Làm theo ca)
    String? shiftId = _shifts.isNotEmpty ? _shifts.first.id : null;

    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now().add(const Duration(days: 29));
    final reasonCtrl = TextEditingController(text: 'Nghỉ theo yêu cầu');
    String conflictMode = 'OVERWRITE_KEEP_EXCEPTIONS'; // Mặc định Mục 5.2
    bool isPreviewing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.88,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.flash_on_outlined, size: 20, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Thiết lập ngoại lệ ca', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                SizedBox(height: 2),
                                Text('Gán ngày nghỉ hoặc đổi ca đột xuất theo khoảng ngày', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Body scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BƯỚC 1: PHẠM VI ÁP DỤNG
                            const Text('1. Đối tượng áp dụng *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildScopeOptionChip(
                                    label: 'Một NV',
                                    isSelected: scopeType == 'EMPLOYEE',
                                    onTap: () => setModalState(() => scopeType = 'EMPLOYEE'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildScopeOptionChip(
                                    label: 'Nhiều NV',
                                    isSelected: scopeType == 'EMPLOYEES',
                                    onTap: () => setModalState(() => scopeType = 'EMPLOYEES'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildScopeOptionChip(
                                    label: 'Đơn vị',
                                    isSelected: scopeType == 'UNIT',
                                    onTap: () => setModalState(() => scopeType = 'UNIT'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildScopeOptionChip(
                                    label: 'Toàn cty',
                                    isSelected: scopeType == 'COMPANY',
                                    onTap: () => setModalState(() => scopeType = 'COMPANY'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Employee / Unit Picker
                            if (scopeType == 'EMPLOYEE') ...[
                              InkWell(
                                onTap: () {
                                  _showSelectSingleEmployeeSheet();
                                  setModalState(() {
                                    employeeId = _scheduleSelectedEmployeeId;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_search_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          employeeId != null ? _getEmployeeNameById(employeeId!) : 'Chọn nhân viên áp dụng...',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: employeeId != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                            fontWeight: employeeId != null ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (scopeType == 'EMPLOYEES') ...[
                              InkWell(
                                onTap: () {
                                  _showSelectMultiEmployeesSheet();
                                  setModalState(() {
                                    employeeIds.clear();
                                    employeeIds.addAll(_scheduleSelectedEmployeeIds);
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.groups_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _scheduleSelectedEmployeeIds.isNotEmpty
                                              ? 'Đã chọn ${_scheduleSelectedEmployeeIds.length} nhân viên'
                                              : 'Bấm để chọn danh sách nhân viên...',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: _scheduleSelectedEmployeeIds.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                            fontWeight: _scheduleSelectedEmployeeIds.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (scopeType == 'UNIT') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: unitId,
                                    isExpanded: true,
                                    menuMaxHeight: 280,
                                    borderRadius: BorderRadius.circular(10),
                                    items: _scheduleShiftUnits.map((u) {
                                      return DropdownMenuItem(
                                        value: u.id,
                                        child: Text(u.name, style: const TextStyle(fontSize: 12.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setModalState(() => unitId = val),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: includeChildUnits,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged: (v) => setModalState(() => includeChildUnits = v ?? true),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Bao gồm các đơn vị trực thuộc', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                                ],
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Text('Áp dụng ngoại lệ cho tất cả ${_employees.length} nhân viên.', style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // BƯỚC 2: CA NGOẠI LỆ (Nghỉ / Làm theo ca)
                            const Text('2. Ca ngoại lệ *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => exceptionType = 'OFF'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: exceptionType == 'OFF' ? const Color(0xFFFEF2F2) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: exceptionType == 'OFF' ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                          width: exceptionType == 'OFF' ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.beach_access_outlined, size: 16, color: exceptionType == 'OFF' ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                                              const SizedBox(width: 6),
                                              Text('Nghỉ (OFF)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: exceptionType == 'OFF' ? const Color(0xFF991B1B) : const Color(0xFF0F172A))),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          const Text('Các ngày trong khoảng thành ngày nghỉ', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => exceptionType = 'SHIFT'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: exceptionType == 'SHIFT' ? const Color(0xFFEFF6FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: exceptionType == 'SHIFT' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                          width: exceptionType == 'SHIFT' ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.schedule_outlined, size: 16, color: exceptionType == 'SHIFT' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                              const SizedBox(width: 6),
                                              Text('Làm theo ca', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: exceptionType == 'SHIFT' ? const Color(0xFF1E40AF) : const Color(0xFF0F172A))),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          const Text('Gán một ca làm việc cụ thể', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (exceptionType == 'SHIFT') ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: shiftId,
                                    isExpanded: true,
                                    menuMaxHeight: 280,
                                    borderRadius: BorderRadius.circular(10),
                                    hint: const Text('Chọn ca cho ngoại lệ...', style: TextStyle(fontSize: 12)),
                                    items: _shifts.map((s) {
                                      final code = s.code.isNotEmpty ? s.code : 'CA';
                                      return DropdownMenuItem(
                                        value: s.id,
                                        child: Text('$code - ${s.name} (${s.startTime}-${s.endTime})', style: const TextStyle(fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setModalState(() => shiftId = val),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // BƯỚC 3: THỜI GIAN VÀ XỬ LÝ XUNG ĐỘT
                            const Text('3. Thời gian & Xung đột *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: fromDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (p != null) setModalState(() => fromDate = p);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Từ: ${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                          ),
                                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: toDate,
                                        firstDate: fromDate,
                                        lastDate: fromDate.add(const Duration(days: 366)),
                                      );
                                      if (p != null) setModalState(() => toDate = p);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Đến: ${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                          ),
                                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            TextField(
                              controller: reasonCtrl,
                              maxLines: 2,
                              maxLength: 500,
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Lý do thiết lập ngoại lệ (ví dụ: Nghỉ theo yêu cầu, đổi ca trực)...',
                                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Chế độ xung đột (mặc định OVERWRITE_KEEP_EXCEPTIONS)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('Chế độ xử lý xung đột', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                        Text('Ghi đè lịch thường, giữ lại ngoại lệ khác và ngày lễ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Action button: Xem trước
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPreviewing
                            ? null
                            : () async {
                                if (exceptionType == 'SHIFT' && (shiftId == null || shiftId!.isEmpty)) {
                                  _showErrorSnackBar('Chọn ca cho ngoại lệ.');
                                  return;
                                }
                                if (scopeType == 'EMPLOYEE' && employeeId == null) {
                                  _showErrorSnackBar('Vui lòng chọn nhân viên áp dụng.');
                                  return;
                                }
                                if (scopeType == 'EMPLOYEES' && employeeIds.isEmpty && _scheduleSelectedEmployeeIds.isEmpty) {
                                  _showErrorSnackBar('Vui lòng chọn ít nhất 1 nhân viên.');
                                  return;
                                }

                                final actualEmployeeIds = scopeType == 'EMPLOYEE'
                                    ? [employeeId!]
                                    : (employeeIds.isNotEmpty ? employeeIds.toList() : _scheduleSelectedEmployeeIds.toList());

                                final scope = HrmScheduleScope(
                                  type: scopeType,
                                  employeeIds: (scopeType == 'EMPLOYEE' || scopeType == 'EMPLOYEES') ? actualEmployeeIds : const [],
                                  unitIds: scopeType == 'UNIT' && unitId != null ? [unitId!] : const [],
                                  includeChildUnits: scopeType == 'UNIT' ? includeChildUnits : false,
                                );

                                // Tạo pattern đủ 7 ngày giống hệt nhau (Mục 5.3)
                                final pattern = List.generate(
                                  7,
                                  (i) => HrmWeekdayRule(
                                    weekday: i + 1,
                                    dayType: exceptionType == 'OFF' ? 'OFF' : 'SHIFT',
                                    shiftId: exceptionType == 'SHIFT' ? shiftId : null,
                                  ),
                                );

                                final fromStr = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                                final toStr = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

                                final req = HrmApplyScheduleRequest(
                                  kind: 'EXCEPTION',
                                  scope: scope,
                                  fromDate: fromStr,
                                  toDate: toStr,
                                  pattern: pattern,
                                  conflictMode: conflictMode,
                                  reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                                );

                                setModalState(() => isPreviewing = true);
                                try {
                                  final preview = await _hrmService.previewSchedule(req);
                                  if (ctx.mounted) {
                                    setModalState(() => isPreviewing = false);
                                    Navigator.pop(ctx);
                                    _showSchedulePreviewModal(preview: preview, initialRequest: req);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setModalState(() => isPreviewing = false);
                                    _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: isPreviewing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Xem trước ngoại lệ & Lưu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScopeOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // MODAL: XEM TRƯỚC KẾT QUẢ & XỬ LÝ XUNG ĐỘT (Conforming 100% to HRM-PHAN-CA-MOBILE.md Mục 3.4 & 3.5)
  void _showSchedulePreviewModal({
    required HrmSchedulePreviewResult preview,
    required HrmApplyScheduleRequest initialRequest,
  }) {
    HrmSchedulePreviewResult currentPreview = preview;
    HrmApplyScheduleRequest currentRequest = initialRequest;
    bool isRePreviewing = false;
    bool isAgreed = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isOpenEnded = currentRequest.toDate == null;

            // Re-preview helper
            Future<void> triggerRePreview(String newConflictMode) async {
              setModalState(() {
                isRePreviewing = true;
                _scheduleConflictMode = newConflictMode;
                currentRequest = HrmApplyScheduleRequest(
                  kind: currentRequest.kind,
                  scope: currentRequest.scope,
                  fromDate: currentRequest.fromDate,
                  toDate: currentRequest.toDate,
                  templateId: currentRequest.templateId,
                  pattern: currentRequest.pattern,
                  conflictMode: newConflictMode,
                  reason: currentRequest.reason,
                );
                isAgreed = false; // Reset agreement on conflict mode change per web spec
              });

              try {
                final newPrev = await _hrmService.previewSchedule(currentRequest);
                if (ctx.mounted) {
                  setModalState(() {
                    currentPreview = newPrev;
                    isRePreviewing = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setModalState(() => isRePreviewing = false);
                  _showErrorSnackBar('Lỗi xem trước: $e');
                }
              }
            }

            // Save apply helper
            Future<void> triggerSave() async {
              setModalState(() => isSaving = true);
              try {
                final reqToSave = HrmApplyScheduleRequest(
                  kind: currentRequest.kind,
                  scope: currentRequest.scope,
                  fromDate: currentRequest.fromDate,
                  toDate: currentRequest.toDate,
                  templateId: currentRequest.templateId,
                  pattern: currentRequest.pattern,
                  conflictMode: currentRequest.conflictMode,
                  reason: currentRequest.reason,
                  confirm: currentPreview.requiresConfirmation || currentRequest.scope.type == 'COMPANY',
                );

                final res = await _hrmService.applySchedule(reqToSave);
                if (ctx.mounted) {
                  setModalState(() => isSaving = false);
                  if (res.isSuccess) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message.isNotEmpty ? res.message : 'Lưu phân ca thành công!'),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _refreshScheduleHistory();
                  } else {
                    _showErrorSnackBar(res.message);
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  setModalState(() => isSaving = false);
                  final err = e.toString().replaceFirst('Exception: ', '');
                  _showErrorSnackBar(err);
                }
              }
            }

            final canSave = currentPreview.canSave && isAgreed && !isSaving && !isRePreviewing;

            return SafeArea(
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.9,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Xem trước kết quả',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Kiểm tra phạm vi ảnh hưởng, xung đột và xác nhận trước khi lưu.',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: isRePreviewing ? null : () => triggerRePreview(currentRequest.conflictMode),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: isRePreviewing
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Xem trước lại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pill Banner: Lịch tuần sẽ lưu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        currentRequest.kind == 'EXCEPTION'
                            ? 'Ngoại lệ: ${currentRequest.pattern != null && currentRequest.pattern!.isNotEmpty && currentRequest.pattern!.first.dayType == 'OFF' ? 'Nghỉ (OFF)' : 'Làm theo ca (${_getShiftDisplayNameById(currentRequest.pattern?.isNotEmpty == true ? currentRequest.pattern!.first.shiftId : null)})'} • Từ ${currentRequest.fromDate} đến ${currentRequest.toDate}'
                            : 'Lịch tuần sẽ lưu: T2–T6 (${_getShiftDisplayNameById(_scheduleSelectedShiftId)}) • Áp dụng từ ${currentRequest.fromDate}${currentRequest.toDate != null ? ' đến ${currentRequest.toDate}' : ' (Lịch định kỳ)'}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 6 KPI Metric Cards
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: isOpenEnded
                            ? [
                                _buildPreviewMetricCard(currentPreview.ruleCount.toString(), 'Quy tắc áp dụng'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.changedRules.toString(), 'Quy tắc thay đổi'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.employeeCount.toString(), 'Nhân viên'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.conflictTotal.toString(), 'Xung đột'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.skippedTargets.toString(), 'Bỏ qua'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.dayCount.toString(), 'Tổng số ngày'),
                              ]
                            : [
                                _buildPreviewMetricCard(currentPreview.insertCount.toString(), 'Ngày thêm mới'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.replaceCount.toString(), 'Ngày thay thế'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.sameCount.toString(), 'Ngày trùng khớp'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.conflicts.length.toString(), 'Xung đột'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.employeeCount.toString(), 'Nhân viên'),
                                const SizedBox(width: 8),
                                _buildPreviewMetricCard(currentPreview.dayCount.toString(), 'Tổng số ngày'),
                              ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scrollable section for Conflict Options & Details
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cách xử lý khi trùng hoặc xung đột lịch *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),

                            // Option 1: REPORT
                            _buildPreviewConflictOption(
                              title: 'Chỉ báo xung đột, không ghi',
                              value: 'REPORT',
                              groupValue: currentRequest.conflictMode,
                              onChanged: (val) => triggerRePreview(val),
                            ),
                            const SizedBox(height: 6),

                            // Option 2: SKIP_EXISTING
                            _buildPreviewConflictOption(
                              title: isOpenEnded ? 'Bỏ qua phạm vi đã có lịch định kỳ' : 'Chỉ gán ngày chưa có lịch',
                              value: 'SKIP_EXISTING',
                              groupValue: currentRequest.conflictMode,
                              onChanged: (val) => triggerRePreview(val),
                            ),
                            const SizedBox(height: 6),

                            // Option 3: OVERWRITE_KEEP_EXCEPTIONS
                            _buildPreviewConflictOption(
                              title: isOpenEnded
                                  ? 'Ghi đè theo thời gian: lịch mới thay lịch định kỳ và lịch từng ngày cũ'
                                  : 'Thay lịch thường bằng lịch mới, giữ ngoại lệ và ngày lễ',
                              value: 'OVERWRITE_KEEP_EXCEPTIONS',
                              groupValue: currentRequest.conflictMode,
                              onChanged: (val) => triggerRePreview(val),
                            ),

                            // Option 4: OVERWRITE_ALL (chỉ khi có ngày kết thúc)
                            if (!isOpenEnded) ...[
                              const SizedBox(height: 6),
                              _buildPreviewConflictOption(
                                title: 'Ghi đè tất cả, kể cả ngoại lệ',
                                value: 'OVERWRITE_ALL',
                                groupValue: currentRequest.conflictMode,
                                onChanged: (val) => triggerRePreview(val),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Conflict Warnings if any
                            if (currentPreview.conflicts.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Phát hiện ${currentPreview.conflicts.length} xung đột lịch:',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ...currentPreview.conflicts.take(5).map((c) => Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            '• ${(c['employeeName'] ?? c['employeeId'] ?? 'Nhân viên')}: ${(c['message'] ?? c['reason'] ?? 'Xung đột lịch')}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFB91C1C)),
                                          ),
                                        )),
                                    if (currentPreview.conflicts.length > 5)
                                      Text(
                                        '... và ${currentPreview.conflicts.length - 5} xung đột khác.',
                                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFFB91C1C)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Agreement Checkbox
                            InkWell(
                              onTap: () => setModalState(() => isAgreed = !isAgreed),
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: isAgreed,
                                      activeColor: const Color(0xFFF59E0B),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) => setModalState(() => isAgreed = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Tôi đã xem lại phạm vi và đồng ý áp dụng',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Buttons: Hủy & Lưu phân ca
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Hủy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: canSave ? triggerSave : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF1E293B),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)))
                              : Text(
                                  !currentPreview.canSave ? 'Không thể lưu (có xung đột)' : 'Lưu phân ca',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewMetricCard(String count, String label) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPreviewConflictOption({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SUBMIT PHÂN CA (Gửi Preview payload chuẩn theo HRM-PHAN-CA-MOBILE.md Mục 3.2 & 3.3)
  Future<void> _handleConfirmScheduleAssignment() async {
    // 1. Validation (Mục 3.2)
    if (_scheduleScope == 'ONE_EMPLOYEE' && _scheduleSelectedEmployeeId == null) {
      _showErrorSnackBar('Chọn một nhân viên.');
      return;
    }
    if (_scheduleScope == 'MULTI_EMPLOYEES' && _scheduleSelectedEmployeeIds.isEmpty) {
      _showErrorSnackBar('Chọn ít nhất một nhân viên.');
      return;
    }
    if (_scheduleScope == 'BY_DEPARTMENT' && _scheduleSelectedUnitId == null) {
      _showErrorSnackBar('Chọn ít nhất một đơn vị.');
      return;
    }
    if (!_scheduleIsOpenEnded) {
      if (_scheduleEndDate == null) {
        _showErrorSnackBar('Nhập đầy đủ từ ngày và đến ngày.');
        return;
      }
      if (_scheduleEffectiveDate.isAfter(_scheduleEndDate!)) {
        _showErrorSnackBar('Từ ngày phải trước hoặc bằng đến ngày.');
        return;
      }
      if (_scheduleEndDate!.difference(_scheduleEffectiveDate).inDays > 366) {
        _showErrorSnackBar('Khoảng ngày tối đa 366 ngày.');
        return;
      }
    }
    if (_scheduleUseTemplate) {
      if (_scheduleSelectedTemplateId == null || _scheduleSelectedTemplateId!.isEmpty) {
        _showErrorSnackBar('Chọn một mẫu lịch tuần.');
        return;
      }
    } else {
      final defShift = _defaultShiftId;
      _scheduleWeeklyRules = _scheduleWeeklyRules.map((r) {
        if (r.dayType == 'SHIFT' && (r.shiftId == null || r.shiftId!.isEmpty)) {
          return HrmWeekdayRule(weekday: r.weekday, dayType: 'SHIFT', shiftId: defShift);
        }
        return r;
      }).toList();

      final allSkip = _scheduleWeeklyRules.every((r) => r.dayType == 'SKIP');
      if (allSkip) {
        _showErrorSnackBar('Cần cấu hình ít nhất một ngày trong tuần (ca hoặc nghỉ).');
        return;
      }
      for (final r in _scheduleWeeklyRules) {
        if (r.dayType == 'SHIFT' && (r.shiftId == null || r.shiftId!.isEmpty)) {
          final wName = r.weekday == 7 ? 'Chủ nhật' : 'Thứ ${r.weekday + 1}';
          _showErrorSnackBar('Chọn ca cho $wName.');
          return;
        }
      }
    }

    // 2. Build HrmScheduleScope
    HrmScheduleScope scope;
    if (_scheduleScope == 'ONE_EMPLOYEE') {
      scope = HrmScheduleScope(type: 'EMPLOYEE', employeeIds: [_scheduleSelectedEmployeeId!]);
    } else if (_scheduleScope == 'MULTI_EMPLOYEES') {
      scope = HrmScheduleScope(type: 'EMPLOYEES', employeeIds: _scheduleSelectedEmployeeIds.toList());
    } else if (_scheduleScope == 'BY_DEPARTMENT') {
      scope = HrmScheduleScope(
        type: 'UNIT',
        unitIds: [_scheduleSelectedUnitId!],
        includeChildUnits: _scheduleIsOpenEnded ? false : _scheduleIncludeChildUnits,
      );
    } else {
      scope = const HrmScheduleScope(type: 'COMPANY');
    }

    final fromDateStr = '${_scheduleEffectiveDate.year}-${_scheduleEffectiveDate.month.toString().padLeft(2, '0')}-${_scheduleEffectiveDate.day.toString().padLeft(2, '0')}';
    final toDateStr = (!_scheduleIsOpenEnded && _scheduleEndDate != null)
        ? '${_scheduleEndDate!.year}-${_scheduleEndDate!.month.toString().padLeft(2, '0')}-${_scheduleEndDate!.day.toString().padLeft(2, '0')}'
        : null;

    final req = HrmApplyScheduleRequest(
      kind: 'ASSIGN',
      scope: scope,
      fromDate: fromDateStr,
      toDate: toDateStr,
      templateId: _scheduleUseTemplate ? _scheduleSelectedTemplateId : null,
      pattern: !_scheduleUseTemplate ? _scheduleWeeklyRules : null,
      conflictMode: _scheduleConflictMode,
      reason: _scheduleNoteCtrl.text.trim().isNotEmpty ? _scheduleNoteCtrl.text.trim() : null,
    );

    // 3. Call Preview API
    setState(() => _isSubmittingSchedule = true);
    try {
      final preview = await _hrmService.previewSchedule(req);
      if (mounted) {
        setState(() => _isSubmittingSchedule = false);
        _showSchedulePreviewModal(preview: preview, initialRequest: req);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingSchedule = false);
        final errText = e.toString().replaceFirst('Exception: ', '');
        _showErrorSnackBar(errText);
      }
    }
  }

  // MODAL: TỔNG QUAN NHẢ CA (Conforming to HRM-PHAN-CA-MOBILE.md Mục 4.2)
  void _showReleaseOverviewModal({
    required HrmCancelScheduleResult dryRun,
    required HrmCancelScheduleRequest req,
  }) {
    bool isAgreed = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng quan nhả ca', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Danger callout with impact summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sẽ hủy ${dryRun.dayCount} ngày lịch của ${dryRun.employeeCount} nhân viên trong khoảng ${req.fromDate} đến ${req.toDate}.',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                          if (dryRun.keptProtected > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${dryRun.keptProtected} ngày ngoại lệ hoặc ngày lễ được giữ lại.',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Checkbox agreement
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isAgreed,
                            activeColor: const Color(0xFFDC2626),
                            onChanged: (val) => setModalState(() => isAgreed = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tôi đã xem lại phạm vi và đồng ý nhả ca',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (!isAgreed || isSubmitting || dryRun.dayCount == 0)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final finalReq = HrmCancelScheduleRequest(
                                      scope: req.scope,
                                      fromDate: req.fromDate,
                                      toDate: req.toDate,
                                      includeExceptions: req.includeExceptions,
                                      reason: req.reason,
                                      dryRun: false,
                                      confirm: true,
                                    );
                                    final finalResult = await _hrmService.cancelSchedule(finalReq);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã hủy ${finalResult.dayCount} ngày lịch của ${finalResult.employeeCount} nhân viên.'),
                                          backgroundColor: const Color(0xFF059669),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      _refreshScheduleHistory();
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setModalState(() => isSubmitting = false);
                                      final err = e.toString().replaceFirst('Exception: ', '');
                                      _showErrorSnackBar(err);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Nhả ca', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // SUBMIT NHẢ CA (Gửi dryRun=true theo HRM-PHAN-CA-MOBILE.md Mục 4.1)
  Future<void> _handleConfirmRelease() async {
    // 1. Validation
    if (_releaseScope == 'ONE_EMPLOYEE' && _releaseEmployeeId == null) {
      _showErrorSnackBar('Chọn một nhân viên.');
      return;
    }
    if (_releaseScope == 'MULTI_EMPLOYEES' && _releaseEmployeeIds.isEmpty) {
      _showErrorSnackBar('Chọn ít nhất một nhân viên.');
      return;
    }
    if (_releaseScope == 'BY_DEPARTMENT' && _releaseUnitId == null) {
      _showErrorSnackBar('Chọn ít nhất một đơn vị.');
      return;
    }
    if (_releaseFromDate.isAfter(_releaseToDate)) {
      _showErrorSnackBar('Từ ngày phải trước hoặc bằng đến ngày.');
      return;
    }
    if (_releaseToDate.difference(_releaseFromDate).inDays > 366) {
      _showErrorSnackBar('Khoảng ngày tối đa 366 ngày.');
      return;
    }

    // 2. Build HrmScheduleScope
    HrmScheduleScope scope;
    if (_releaseScope == 'ONE_EMPLOYEE') {
      scope = HrmScheduleScope(type: 'EMPLOYEE', employeeIds: [_releaseEmployeeId!]);
    } else if (_releaseScope == 'MULTI_EMPLOYEES') {
      scope = HrmScheduleScope(type: 'EMPLOYEES', employeeIds: _releaseEmployeeIds.toList());
    } else if (_releaseScope == 'BY_DEPARTMENT') {
      scope = HrmScheduleScope(type: 'UNIT', unitIds: [_releaseUnitId!]);
    } else {
      scope = const HrmScheduleScope(type: 'COMPANY');
    }

    final fromStr = '${_releaseFromDate.year}-${_releaseFromDate.month.toString().padLeft(2, '0')}-${_releaseFromDate.day.toString().padLeft(2, '0')}';
    final toStr = '${_releaseToDate.year}-${_releaseToDate.month.toString().padLeft(2, '0')}-${_releaseToDate.day.toString().padLeft(2, '0')}';

    final req = HrmCancelScheduleRequest(
      scope: scope,
      fromDate: fromStr,
      toDate: toStr,
      includeExceptions: _releaseIncludeExceptions,
      reason: _releaseReasonCtrl.text.trim().isNotEmpty ? _releaseReasonCtrl.text.trim() : null,
      dryRun: true,
    );

    setState(() => _isSubmittingRelease = true);
    try {
      final dryRunResult = await _hrmService.cancelSchedule(req);
      if (mounted) {
        setState(() => _isSubmittingRelease = false);
        _showReleaseOverviewModal(dryRun: dryRunResult, req: req);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRelease = false);
        final errText = e.toString().replaceFirst('Exception: ', '');
        _showErrorSnackBar(errText);
      }
    }
  }

  // ==========================================
}
