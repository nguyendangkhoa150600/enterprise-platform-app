import 'package:flutter/material.dart';
import '../../../../../../models/hrm_personnel_decision_model.dart';
import 'decision_dialog_helpers.dart';

class DecisionSalaryForm extends StatefulWidget {
  final bool salaryChanged;
  final ValueChanged<bool> onSalaryChangedToggle;
  final String? selectedSalaryGradeId;
  final String? selectedSalaryStepId;
  final List<HrmSalaryGrade> salaryGrades;
  final List<HrmSalaryGradeStep> salarySteps;
  final bool isLoadingGrades;
  final bool isLoadingSteps;
  final ValueChanged<HrmSalaryGrade> onSelectGrade;
  final VoidCallback onClearGrade;
  final ValueChanged<HrmSalaryGradeStep> onSelectStep;
  final VoidCallback onClearStep;
  final String salaryType;
  final ValueChanged<String> onSalaryTypeChanged;
  final TextEditingController baseSalaryCtrl;
  final VoidCallback onBaseSalaryChanged;

  const DecisionSalaryForm({
    super.key,
    required this.salaryChanged,
    required this.onSalaryChangedToggle,
    required this.selectedSalaryGradeId,
    required this.selectedSalaryStepId,
    required this.salaryGrades,
    required this.salarySteps,
    required this.isLoadingGrades,
    required this.isLoadingSteps,
    required this.onSelectGrade,
    required this.onClearGrade,
    required this.onSelectStep,
    required this.onClearStep,
    required this.salaryType,
    required this.onSalaryTypeChanged,
    required this.baseSalaryCtrl,
    required this.onBaseSalaryChanged,
  });

  @override
  State<DecisionSalaryForm> createState() => _DecisionSalaryFormState();
}

class _DecisionSalaryFormState extends State<DecisionSalaryForm> {
  bool _isGradeDropdownOpen = false;
  final TextEditingController _gradeSearchCtrl = TextEditingController();
  final FocusNode _gradeFocusNode = FocusNode();

  bool _isStepDropdownOpen = false;
  final TextEditingController _stepSearchCtrl = TextEditingController();
  final FocusNode _stepFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncGradeText();
    _syncStepText();

    _gradeFocusNode.addListener(() {
      if (_gradeFocusNode.hasFocus && !_isGradeDropdownOpen) {
        setState(() => _isGradeDropdownOpen = true);
      }
    });

    _stepFocusNode.addListener(() {
      if (_stepFocusNode.hasFocus && !_isStepDropdownOpen) {
        setState(() => _isStepDropdownOpen = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DecisionSalaryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSalaryGradeId != widget.selectedSalaryGradeId ||
        oldWidget.salaryGrades != widget.salaryGrades) {
      _syncGradeText();
    }
    if (oldWidget.selectedSalaryStepId != widget.selectedSalaryStepId ||
        oldWidget.salarySteps != widget.salarySteps) {
      _syncStepText();
    }
  }

  void _syncGradeText() {
    if (widget.selectedSalaryGradeId != null) {
      final g = widget.salaryGrades.cast<HrmSalaryGrade?>().firstWhere(
        (x) => x?.id == widget.selectedSalaryGradeId,
        orElse: () => null,
      );
      if (g != null) {
        _gradeSearchCtrl.text = '${g.code} · ${g.name}';
      }
    } else {
      _gradeSearchCtrl.clear();
    }
  }

  void _syncStepText() {
    if (widget.selectedSalaryStepId != null) {
      final s = widget.salarySteps.cast<HrmSalaryGradeStep?>().firstWhere(
        (x) => x?.id == widget.selectedSalaryStepId,
        orElse: () => null,
      );
      if (s != null) {
        _stepSearchCtrl.text = 'Bậc ${s.stepNo} - ${formatDecisionMoney(s.baseSalary.toInt().toString())}';
      }
    } else {
      _stepSearchCtrl.clear();
    }
  }

  @override
  void dispose() {
    _gradeSearchCtrl.dispose();
    _gradeFocusNode.dispose();
    _stepSearchCtrl.dispose();
    _stepFocusNode.dispose();
    super.dispose();
  }

  HrmSalaryGrade? get _selectedSalaryGrade {
    if (widget.selectedSalaryGradeId == null) return null;
    return widget.salaryGrades.cast<HrmSalaryGrade?>().firstWhere(
      (g) => g?.id == widget.selectedSalaryGradeId,
      orElse: () => null,
    );
  }

  HrmSalaryGradeStep? get _selectedSalaryStep {
    if (widget.selectedSalaryStepId == null) return null;
    return widget.salarySteps.cast<HrmSalaryGradeStep?>().firstWhere(
      (s) => s?.id == widget.selectedSalaryStepId,
      orElse: () => null,
    );
  }

  List<HrmSalaryGrade> get _filteredGrades {
    final query = _gradeSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.salaryGrades;
    final sel = _selectedSalaryGrade;
    if (sel != null && query == '${sel.code} · ${sel.name}'.toLowerCase()) {
      return widget.salaryGrades;
    }
    return widget.salaryGrades.where((g) {
      final code = g.code.toLowerCase();
      final name = g.name.toLowerCase();
      final full = '$code · $name';
      return full.contains(query) || code.contains(query) || name.contains(query);
    }).toList();
  }

  List<HrmSalaryGradeStep> get _filteredSteps {
    final query = _stepSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.salarySteps;
    final sel = _selectedSalaryStep;
    if (sel != null &&
        query == 'Bậc ${sel.stepNo} - ${formatDecisionMoney(sel.baseSalary.toInt().toString())}'.toLowerCase()) {
      return widget.salarySteps;
    }
    return widget.salarySteps.where((s) {
      final label = 'bậc ${s.stepNo} - ${formatDecisionMoney(s.baseSalary.toInt().toString())}'.toLowerCase();
      final no = '${s.stepNo}';
      return label.contains(query) || no.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => widget.onSalaryChangedToggle(!widget.salaryChanged),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: widget.salaryChanged,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (v) => widget.onSalaryChangedToggle(v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Thay đổi lương',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          if (widget.salaryChanged) ...[
            const SizedBox(height: 12),
            // Row 1: Ngạch lương & Bậc lương
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ngạch lương
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDecisionFieldLabel('Ngạch lương'),
                      _buildSelectBox(
                        hintText: 'Chọn ngạch',
                        controller: _gradeSearchCtrl,
                        focusNode: _gradeFocusNode,
                        isOpen: _isGradeDropdownOpen,
                        isLoading: widget.isLoadingGrades,
                        onToggle: () {
                          setState(() {
                            _isGradeDropdownOpen = !_isGradeDropdownOpen;
                            _isStepDropdownOpen = false;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _gradeSearchCtrl.clear();
                            _stepSearchCtrl.clear();
                          });
                          widget.onClearGrade();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Bậc lương
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDecisionFieldLabel('Bậc lương'),
                      _buildSelectBox(
                        hintText: widget.selectedSalaryGradeId == null ? 'Chọn ngạch trước' : 'Chọn bậc',
                        controller: _stepSearchCtrl,
                        focusNode: _stepFocusNode,
                        isOpen: _isStepDropdownOpen,
                        disabled: widget.selectedSalaryGradeId == null,
                        isLoading: widget.isLoadingSteps,
                        onToggle: () {
                          if (widget.selectedSalaryGradeId != null) {
                            setState(() {
                              _isStepDropdownOpen = !_isStepDropdownOpen;
                              _isGradeDropdownOpen = false;
                            });
                          }
                        },
                        onClear: () {
                          setState(() {
                            _stepSearchCtrl.clear();
                          });
                          widget.onClearStep();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Dropdown ngạch lương
            if (_isGradeDropdownOpen) ...[
              const SizedBox(height: 4),
              _buildGradeDropdownMenu(),
            ],
            // Dropdown bậc lương
            if (_isStepDropdownOpen) ...[
              const SizedBox(height: 4),
              _buildStepDropdownMenu(),
            ],
            const SizedBox(height: 12),
            // Row 2: Loại lương & Lương cơ bản (đ)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loại lương
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDecisionFieldLabel('Loại lương'),
                      DropdownButtonFormField<String>(
                        initialValue: widget.salaryType,
                        menuMaxHeight: 200,
                        borderRadius: BorderRadius.circular(8),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'GROSS',
                            child: Text('Gross', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: 'NET',
                            child: Text('Net', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) widget.onSalaryTypeChanged(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Lương cơ bản (đ)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDecisionFieldLabel('Lương cơ bản (đ)'),
                      TextFormField(
                        controller: widget.baseSalaryCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => widget.onBaseSalaryChanged(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập lương cơ bản',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectBox({
    required String hintText,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isOpen,
    required VoidCallback onToggle,
    VoidCallback? onClear,
    bool disabled = false,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
          width: isOpen ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(Icons.search, size: 16, color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !disabled,
              onTap: onToggle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          if (controller.text.isNotEmpty && !disabled && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.cancel, size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
              ),
            )
          else
            InkWell(
              onTap: disabled ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradeDropdownMenu() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _filteredGrades.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text('Không tìm thấy ngạch lương', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filteredGrades.length,
              itemBuilder: (context, i) {
                final grade = _filteredGrades[i];
                final isChosen = grade.id == widget.selectedSalaryGradeId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _gradeSearchCtrl.text = '${grade.code} · ${grade.name}';
                      _isGradeDropdownOpen = false;
                      _stepSearchCtrl.clear();
                    });
                    _gradeFocusNode.unfocus();
                    widget.onSelectGrade(grade);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: isChosen ? const Color(0xFFEFF6FF) : Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            grade.code,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            grade.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                              color: isChosen ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isChosen) const Icon(Icons.check, size: 15, color: Color(0xFF1D4ED8)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStepDropdownMenu() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _filteredSteps.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text('Không có bậc lương cho ngạch này', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filteredSteps.length,
              itemBuilder: (context, i) {
                final step = _filteredSteps[i];
                final isChosen = step.id == widget.selectedSalaryStepId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _stepSearchCtrl.text = 'Bậc ${step.stepNo} - ${formatDecisionMoney(step.baseSalary.toInt().toString())}';
                      _isStepDropdownOpen = false;
                    });
                    _stepFocusNode.unfocus();
                    widget.onSelectStep(step);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: isChosen ? const Color(0xFFEFF6FF) : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bậc ${step.stepNo} - ${formatDecisionMoney(step.baseSalary.toInt().toString())} đ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                              color: isChosen ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isChosen) const Icon(Icons.check, size: 15, color: Color(0xFF1D4ED8)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
