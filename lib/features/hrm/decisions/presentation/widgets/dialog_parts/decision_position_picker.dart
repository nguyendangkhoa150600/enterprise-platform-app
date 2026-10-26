import 'package:flutter/material.dart';
import '../../../../../../models/hrm_models.dart';
import 'decision_dialog_helpers.dart';

class DecisionPositionPicker extends StatefulWidget {
  final List<HrmPositionItem> positions;
  final String? selectedPositionNodeId;
  final ValueChanged<HrmPositionItem> onSelectPosition;
  final VoidCallback onClear;
  final bool hasError;

  const DecisionPositionPicker({
    super.key,
    required this.positions,
    required this.selectedPositionNodeId,
    required this.onSelectPosition,
    required this.onClear,
    required this.hasError,
  });

  @override
  State<DecisionPositionPicker> createState() => _DecisionPositionPickerState();
}

class _DecisionPositionPickerState extends State<DecisionPositionPicker> {
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
  void didUpdateWidget(covariant DecisionPositionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPositionNodeId != widget.selectedPositionNodeId) {
      _syncText();
    }
  }

  void _syncText() {
    if (widget.selectedPositionNodeId != null) {
      try {
        final pos = widget.positions.firstWhere((p) => p.id == widget.selectedPositionNodeId);
        _searchCtrl.text = '${pos.title} · ${pos.departmentName}';
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

  HrmPositionItem? get _selectedPosition {
    if (widget.selectedPositionNodeId == null) return null;
    try {
      return widget.positions.firstWhere((p) => p.id == widget.selectedPositionNodeId);
    } catch (_) {
      return null;
    }
  }

  List<HrmPositionItem> get _filteredPositions {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.positions;
    final sel = _selectedPosition;
    if (sel != null && query == '${sel.title} · ${sel.departmentName}'.toLowerCase()) {
      return widget.positions;
    }
    return widget.positions.where((p) {
      final title = p.title.toLowerCase();
      final dept = p.departmentName.toLowerCase();
      final full = '$title · $dept';
      return full.contains(query) || title.contains(query) || dept.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDecisionFieldLabel('Chức danh mới'),
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
                    hintText: 'Chọn chức danh',
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
            child: _filteredPositions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Center(
                      child: Text(
                        'Không tìm thấy chức danh phù hợp',
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
                      itemCount: _filteredPositions.length,
                      itemBuilder: (context, i) {
                        final pos = _filteredPositions[i];
                        final isChosen = pos.id == widget.selectedPositionNodeId;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _searchCtrl.text = '${pos.title} · ${pos.departmentName}';
                              _isOpen = false;
                            });
                            _focusNode.unfocus();
                            widget.onSelectPosition(pos);
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
                                          text: pos.title,
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
                                          text: pos.departmentName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                                            color: isChosen
                                                ? const Color(0xFF1D4ED8)
                                                : const Color(0xFF64748B),
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
              'Vui lòng chọn chức danh mới',
              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ],
    );
  }
}
