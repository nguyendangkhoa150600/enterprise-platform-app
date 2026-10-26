import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../models/hrm_personnel_decision_model.dart';
import '../../../../../services/hrm_service.dart';
import 'dialog_parts/decision_dialog_helpers.dart';
import 'dialog_parts/decision_employee_picker.dart';
import 'dialog_parts/decision_position_picker.dart';
import 'dialog_parts/decision_basic_info_form.dart';
import 'dialog_parts/decision_compare_card.dart';
import 'dialog_parts/decision_salary_form.dart';

class PersonnelDecisionDialog extends StatefulWidget {
  final HrmPersonnelDecision? decision;
  final List<HrmEmployeeItem> employees;
  final List<HrmPositionItem> positions;
  final VoidCallback onSuccess;

  const PersonnelDecisionDialog({
    super.key,
    this.decision,
    required this.employees,
    required this.positions,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    HrmPersonnelDecision? decision,
    required List<HrmEmployeeItem> employees,
    required List<HrmPositionItem> positions,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PersonnelDecisionDialog(
        decision: decision,
        employees: employees,
        positions: positions,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PersonnelDecisionDialog> createState() => _PersonnelDecisionDialogState();
}

class _PersonnelDecisionDialogState extends State<PersonnelDecisionDialog> {
  final _formKey = GlobalKey<FormState>();

  String _decisionType = 'TRANSFER';
  String _mode = 'REPLACE'; // 'REPLACE' (Thay thế) | 'CONCURRENT' (Kiêm nhiệm)
  String? _selectedEmployeeId;
  DateTime _effectiveDate = DateTime.now();
  late TextEditingController _reasonCtrl;
  String? _selectedPositionNodeId;

  bool _salaryChanged = false;
  late TextEditingController _baseSalaryCtrl;
  String _salaryType = 'GROSS';

  String? _selectedSalaryGradeId;
  String? _selectedSalaryStepId;
  List<HrmSalaryGrade> _salaryGrades = [];
  List<HrmSalaryGradeStep> _salarySteps = [];
  bool _isLoadingGrades = false;
  bool _isLoadingSteps = false;

  Map<String, dynamic>? _appointmentContext;

  bool _isLoading = false;
  bool _employeeHasError = false;
  bool _positionHasError = false;

  final Map<String, String> _typeLabels = {
    'TRANSFER': 'Điều chuyển',
    'APPOINT': 'Bổ nhiệm',
    'PROMOTE': 'Thăng chức',
    'CONCURRENT': 'Kiêm nhiệm',
    'DISMISS': 'Miễn nhiệm',
    'REVOKE': 'Bãi nhiệm',
  };

  @override
  void initState() {
    super.initState();
    final d = widget.decision;
    _decisionType = d?.decisionType ?? 'TRANSFER';
    if (!_typeLabels.containsKey(_decisionType)) _decisionType = 'TRANSFER';
    _mode = _decisionType == 'CONCURRENT' ? 'CONCURRENT' : 'REPLACE';

    _selectedEmployeeId = d?.employeeId;
    if (_selectedEmployeeId == null && widget.employees.isNotEmpty) {
      _selectedEmployeeId = widget.employees.first.id;
    }
    _effectiveDate = d != null && d.effectiveDate.isNotEmpty
        ? DateTime.tryParse(d.effectiveDate) ?? DateTime.now()
        : DateTime.now();
    _reasonCtrl = TextEditingController(text: d?.reason ?? '');
    _selectedPositionNodeId = d?.toPositionNodeId;

    _salaryChanged = d?.salaryChanged ?? false;
    _baseSalaryCtrl = TextEditingController(
      text: d?.toBaseSalary != null ? d!.toBaseSalary!.toInt().toString() : '',
    );
    _salaryType = d?.toSalaryType ?? 'GROSS';

    _selectedSalaryGradeId = d?.toSalaryGradeId;
    _selectedSalaryStepId = d?.toSalaryStepId;

    _loadSalaryGrades();
    if (_selectedEmployeeId != null) {
      _loadAppointmentContext(_selectedEmployeeId!);
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _baseSalaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalaryGrades() async {
    setState(() => _isLoadingGrades = true);
    final grades = await HrmService().getSalaryGrades();
    if (mounted) {
      setState(() {
        _salaryGrades = grades;
        _isLoadingGrades = false;
        if (_selectedSalaryGradeId != null) {
          _loadSalarySteps(_selectedSalaryGradeId!);
        }
      });
    }
  }

  Future<void> _loadSalarySteps(String gradeId) async {
    setState(() => _isLoadingSteps = true);
    final steps = await HrmService().getSalaryGradeSteps(gradeId);
    if (mounted) {
      setState(() {
        _salarySteps = steps;
        _isLoadingSteps = false;
      });
    }
  }

  Future<void> _loadAppointmentContext(String empId) async {
    final ctx = await HrmService().getAppointmentContext(empId);
    if (mounted) {
      setState(() => _appointmentContext = ctx);
    }
  }

  bool get _isPositionChanging =>
      _decisionType == 'APPOINT' ||
      _decisionType == 'PROMOTE' ||
      _decisionType == 'TRANSFER' ||
      _decisionType == 'CONCURRENT';

  bool get _showsTargetPosition =>
      _isPositionChanging || _decisionType == 'REVOKE';

  HrmEmployeeItem? get _selectedEmployee {
    if (_selectedEmployeeId == null) return null;
    try {
      return widget.employees.firstWhere((e) => e.id == _selectedEmployeeId);
    } catch (_) {
      return null;
    }
  }

  HrmPositionItem? get _selectedPosition {
    if (_selectedPositionNodeId == null) return null;
    try {
      return widget.positions.firstWhere((p) => p.id == _selectedPositionNodeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      setState(() => _employeeHasError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nhân viên')),
      );
      return;
    }

    if (_showsTargetPosition && _decisionType != 'REVOKE') {
      if (_selectedPositionNodeId == null || _selectedPositionNodeId!.isEmpty) {
        setState(() => _positionHasError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn chức danh mới')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final dateStr =
          '${_effectiveDate.year.toString().padLeft(4, '0')}-${_effectiveDate.month.toString().padLeft(2, '0')}-${_effectiveDate.day.toString().padLeft(2, '0')}';

      final finalType = _mode == 'CONCURRENT' ? 'CONCURRENT' : _decisionType;

      final payload = <String, dynamic>{
        'decisionType': finalType,
        'employeeId': _selectedEmployeeId,
        'effectiveDate': dateStr,
        'reason': _reasonCtrl.text.trim(),
        'toPositionNodeId': _showsTargetPosition ? _selectedPositionNodeId : null,
        'salaryChanged': _salaryChanged,
        if (_salaryChanged) ...{
          'toSalaryGradeId': _selectedSalaryGradeId,
          'toSalaryStepId': _selectedSalaryStepId,
          'toSalaryType': _salaryType,
          'toBaseSalary': double.tryParse(_baseSalaryCtrl.text.replaceAll('.', '').replaceAll(',', '').trim()),
        },
      };

      if (widget.decision != null) {
        await HrmService().updatePersonnelDecision(widget.decision!.id, payload);
      } else {
        await HrmService().createPersonnelDecision(payload);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(widget.decision != null
                ? 'Đã cập nhật quyết định thành công'
                : 'Đã tạo quyết định mới thành công'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Lỗi khi lưu quyết định: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final emp = _selectedEmployee;
    final pos = _selectedPosition;

    // Tính toán Trước / Sau
    final beforePosition = emp?.position.isNotEmpty == true ? emp!.position : '----';
    final afterPosition = _decisionType == 'DISMISS'
        ? 'Miễn nhiệm'
        : _decisionType == 'REVOKE'
            ? 'Bãi nhiệm'
            : (pos?.title ?? '----');
    final isPosChanged = afterPosition != '----' && afterPosition != beforePosition;

    final beforeUnit = emp?.department.isNotEmpty == true ? emp!.department : '----';
    final afterUnit = _showsTargetPosition
        ? (pos?.departmentName ?? (beforeUnit != '----' ? beforeUnit : '----'))
        : beforeUnit;
    final isUnitChanged = afterUnit != '----' && afterUnit != beforeUnit;

    // Lương cơ bản Trước / Sau (1:1 Web)
    final num? ctxSalary = _appointmentContext?['salary']?['baseSalary'] is num
        ? _appointmentContext!['salary']['baseSalary'] as num
        : (emp != null && emp.baseSalary != null && emp.baseSalary! > 0 ? emp.baseSalary : null);

    final beforeSalary = ctxSalary != null ? '${formatDecisionMoney(ctxSalary.toInt().toString())} đ' : '----';
    final afterSalary = _salaryChanged
        ? (_baseSalaryCtrl.text.trim().isNotEmpty
            ? '${formatDecisionMoney(_baseSalaryCtrl.text)} đ'
            : '----')
        : beforeSalary;
    final isSalaryChanged = _salaryChanged && afterSalary != beforeSalary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header (Matching Web 1:1)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.decision != null
                        ? 'Sửa quyết định ${widget.decision?.decisionNo ?? ''}'
                        : 'Tạo quyết định nhân sự',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Form Body
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. NHÂN VIÊN
                    DecisionEmployeePicker(
                      employees: widget.employees,
                      selectedEmployeeId: _selectedEmployeeId,
                      hasError: _employeeHasError,
                      onSelectEmployee: (employee) {
                        setState(() {
                          _selectedEmployeeId = employee.id;
                          _employeeHasError = false;
                        });
                        _loadAppointmentContext(employee.id);
                      },
                      onClear: () {
                        setState(() {
                          _selectedEmployeeId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. LOẠI QUYẾT ĐỊNH, NGÀY HIỆU LỰC, HÌNH THỨC, LÝ DO, INFO BANNER
                    DecisionBasicInfoForm(
                      decisionType: _decisionType,
                      onDecisionTypeChanged: (newType) {
                        setState(() {
                          _decisionType = newType;
                          _mode = (newType == 'CONCURRENT') ? 'CONCURRENT' : 'REPLACE';
                        });
                      },
                      effectiveDate: _effectiveDate,
                      onEffectiveDateChanged: (newDate) {
                        setState(() => _effectiveDate = newDate);
                      },
                      isPositionChanging: _isPositionChanging,
                      mode: _mode,
                      onModeChanged: (newMode) {
                        setState(() {
                          _mode = newMode;
                          if (newMode == 'CONCURRENT') {
                            _decisionType = 'CONCURRENT';
                          } else if (_decisionType == 'CONCURRENT') {
                            _decisionType = 'APPOINT';
                          }
                        });
                      },
                      reasonCtrl: _reasonCtrl,
                      typeLabels: _typeLabels,
                    ),
                    const SizedBox(height: 14),

                    // 3. CHỨC DANH MỚI
                    if (_showsTargetPosition && _decisionType != 'REVOKE') ...[
                      DecisionPositionPicker(
                        positions: widget.positions,
                        selectedPositionNodeId: _selectedPositionNodeId,
                        hasError: _positionHasError,
                        onSelectPosition: (posItem) {
                          setState(() {
                            _selectedPositionNodeId = posItem.id;
                            _positionHasError = false;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _selectedPositionNodeId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. KHUNG SO SÁNH "TRƯỚC / SAU" (Matching Web 1:1)
                    DecisionCompareCard(
                      beforePosition: beforePosition,
                      afterPosition: afterPosition,
                      isPosChanged: isPosChanged,
                      beforeUnit: beforeUnit,
                      afterUnit: afterUnit,
                      isUnitChanged: isUnitChanged,
                      beforeSalary: beforeSalary,
                      afterSalary: afterSalary,
                      isSalaryChanged: isSalaryChanged,
                    ),
                    const SizedBox(height: 14),

                    // 5. KHUNG ĐIỀU CHỈNH LƯƠNG (Ngạch lương, Bậc lương, Loại lương, Lương cơ bản)
                    DecisionSalaryForm(
                      salaryChanged: _salaryChanged,
                      onSalaryChangedToggle: (val) {
                        setState(() => _salaryChanged = val);
                      },
                      selectedSalaryGradeId: _selectedSalaryGradeId,
                      selectedSalaryStepId: _selectedSalaryStepId,
                      salaryGrades: _salaryGrades,
                      salarySteps: _salarySteps,
                      isLoadingGrades: _isLoadingGrades,
                      isLoadingSteps: _isLoadingSteps,
                      onSelectGrade: (HrmSalaryGrade grade) {
                        setState(() {
                          _selectedSalaryGradeId = grade.id;
                          _selectedSalaryStepId = null;
                          _salarySteps = [];
                        });
                        _loadSalarySteps(grade.id);
                      },
                      onClearGrade: () {
                        setState(() {
                          _selectedSalaryGradeId = null;
                          _selectedSalaryStepId = null;
                          _salarySteps = [];
                        });
                      },
                      onSelectStep: (HrmSalaryGradeStep step) {
                        setState(() {
                          _selectedSalaryStepId = step.id;
                          if (step.baseSalary > 0) {
                            _baseSalaryCtrl.text = step.baseSalary.toInt().toString();
                          }
                        });
                      },
                      onClearStep: () {
                        setState(() {
                          _selectedSalaryStepId = null;
                        });
                      },
                      salaryType: _salaryType,
                      onSalaryTypeChanged: (type) {
                        setState(() => _salaryType = type);
                      },
                      baseSalaryCtrl: _baseSalaryCtrl,
                      onBaseSalaryChanged: () {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Footer (Matching Web 1:1: Đóng + Tạo quyết định [Gold/Yellow])
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Đóng', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308), // Web Yellow/Gold
                    foregroundColor: const Color(0xFF451A03),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Color(0xFF451A03), strokeWidth: 2),
                        )
                      : Text(
                          widget.decision != null ? 'Lưu thay đổi' : 'Tạo quyết định',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
