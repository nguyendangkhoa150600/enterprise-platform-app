import 'package:flutter/material.dart';
import '../../../../../../models/hrm_models.dart';
import 'decision_dialog_helpers.dart';

class DecisionEmployeePicker extends StatefulWidget {
  final List<HrmEmployeeItem> employees;
  final String? selectedEmployeeId;
  final ValueChanged<HrmEmployeeItem> onSelectEmployee;
  final VoidCallback onClear;
  final bool hasError;

  const DecisionEmployeePicker({
    super.key,
    required this.employees,
    required this.selectedEmployeeId,
    required this.onSelectEmployee,
    required this.onClear,
    required this.hasError,
  });

  @override
  State<DecisionEmployeePicker> createState() => _DecisionEmployeePickerState();
}

class _DecisionEmployeePickerState extends State<DecisionEmployeePicker> {
  bool _isOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncText();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_isOpen) {
        setState(() => _isOpen = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DecisionEmployeePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEmployeeId != widget.selectedEmployeeId) {
      _syncText();
    }
  }

  void _syncText() {
    if (widget.selectedEmployeeId != null) {
      try {
        final emp = widget.employees.firstWhere((e) => e.id == widget.selectedEmployeeId);
        _searchCtrl.text = '${emp.code} · ${emp.fullName}';
      } catch (_) {}
    } else {
      _searchCtrl.clear();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  HrmEmployeeItem? get _selectedEmployee {
    if (widget.selectedEmployeeId == null) return null;
    try {
      return widget.employees.firstWhere((e) => e.id == widget.selectedEmployeeId);
    } catch (_) {
      return null;
    }
  }

  List<HrmEmployeeItem> get _filteredEmployees {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.employees;
    final sel = _selectedEmployee;
    if (sel != null && query == '${sel.code} · ${sel.fullName}'.toLowerCase()) {
      return widget.employees;
    }
    return widget.employees.where((e) {
      final codeName = '${e.code} · ${e.fullName}'.toLowerCase();
      final name = e.fullName.toLowerCase();
      final code = e.code.toLowerCase();
      final dept = e.department.toLowerCase();
      final pos = e.position.toLowerCase();
      return codeName.contains(query) ||
          name.contains(query) ||
          code.contains(query) ||
          dept.contains(query) ||
          pos.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDecisionFieldLabel('Nhân viên'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.hasError
                  ? const Color(0xFFEF4444)
                  : _isOpen
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFCBD5E1),
              width: _isOpen ? 1.5 : 1.0,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              ),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  onTap: () {
                    if (!_isOpen) setState(() => _isOpen = true);
                  },
                  onChanged: (_) {
                    if (!_isOpen) {
                      setState(() => _isOpen = true);
                    } else {
                      setState(() {});
                    }
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Chọn nhân viên',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty && _isOpen)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchCtrl.clear();
                    });
                    widget.onClear();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.cancel, size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isOpen = !_isOpen;
                    if (_isOpen) {
                      _focusNode.requestFocus();
                    } else {
                      _focusNode.unfocus();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Icon(
                    _isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _filteredEmployees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Center(
                      child: Text(
                        'Không tìm thấy nhân viên phù hợp',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                : RawScrollbar(
                    thumbVisibility: true,
                    radius: const Radius.circular(4),
                    thickness: 4,
                    thumbColor: const Color(0xFFCBD5E1),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, i) {
                        final emp = _filteredEmployees[i];
                        final isChosen = emp.id == widget.selectedEmployeeId;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _searchCtrl.text = '${emp.code} · ${emp.fullName}';
                              _isOpen = false;
                            });
                            _focusNode.unfocus();
                            widget.onSelectEmployee(emp);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            color: isChosen ? const Color(0xFFF1F5F9) : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: emp.code,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isChosen
                                                ? const Color(0xFF1D4ED8)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' · ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isChosen
                                                ? const Color(0xFF1D4ED8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: emp.fullName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                                            color: isChosen
                                                ? const Color(0xFF1D4ED8)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isChosen)
                                  const Icon(Icons.check, size: 16, color: Color(0xFF1D4ED8)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
        if (widget.hasError) ...[
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Vui lòng chọn nhân viên',
              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ],
    );
  }
}
