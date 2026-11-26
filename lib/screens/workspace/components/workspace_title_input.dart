import 'package:flutter/material.dart';

String _fold(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll(RegExp(r'[đ]'), 'd')
      .trim();
}

/// Ô nhập Tên công việc đồng bộ 1:1 với Web React (title-input.tsx & work-item-draft.tsx)
/// - Hỗ trợ gợi ý danh sách tên công việc đã dùng (history từ /api/workspace/v1/work-item-titles)
/// - Lọc gợi ý không phân biệt dấu tiếng Việt
/// - Chip "✨ Ask AI" và nút "Nhân bản"
class WorkspaceTitleInput extends StatefulWidget {
  final TextEditingController controller;
  final List<String> history;
  final String? placeholder;
  final VoidCallback? onDuplicate;
  final ValueChanged<String>? onChanged;
  final ValueChanged<List<String>>? onPasteLines;

  const WorkspaceTitleInput({
    super.key,
    required this.controller,
    required this.history,
    this.placeholder,
    this.onDuplicate,
    this.onChanged,
    this.onPasteLines,
  });

  @override
  State<WorkspaceTitleInput> createState() => _WorkspaceTitleInputState();
}

class _WorkspaceTitleInputState extends State<WorkspaceTitleInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() => _isOpen = true);
    } else {
      // Đợi microtask trước khi đóng để sự kiện chạm vào suggestion kịp chạy
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _isOpen = false);
        }
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      widget.onChanged?.call(widget.controller.text);
      if (!_isOpen && _focusNode.hasFocus) {
        setState(() => _isOpen = true);
      } else {
        setState(() {});
      }
    }
  }

  void _pickTitle(String title) {
    widget.controller.text = title;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: title.length),
    );
    widget.onChanged?.call(title);
    setState(() => _isOpen = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = _fold(widget.controller.text);
    final suggestions = widget.history
        .where((t) {
          final folded = _fold(t);
          if (t == widget.controller.text) return false;
          return query.isEmpty || folded.contains(query);
        })
        .take(8)
        .toList();

    final showDropdown = _isOpen && suggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Ô nhập liệu chính (Input Row)
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: showDropdown
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        )
                      : BorderRadius.circular(8),
                  border: Border.all(
                    color: _focusNode.hasFocus ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    width: _focusNode.hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: _focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: (val) {
                    setState(() {});
                    widget.onChanged?.call(val);
                  },
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    hintText: widget.placeholder ?? 'Gõ tên, hoặc dán nhiều dòng để tạo nhiều việc',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    suffixIcon: widget.controller.text.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              widget.controller.clear();
                              widget.onChanged?.call('');
                            },
                            child: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (widget.onDuplicate != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Nhân bản (chép mọi trường trừ tên)',
                child: InkWell(
                  onTap: widget.onDuplicate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        // 2. Dropdown gợi ý danh sách tên đã dùng (Khớp 1:1 với Web TitleInput)
        if (showDropdown)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Scrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final title = suggestions[index];
                        return InkWell(
                          onTap: () => _pickTitle(title),
                          hoverColor: const Color(0xFFF8FAFC),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Footer nhỏ với chip ✨ Ask AI (Khớp 1:1 góc phải của Web)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✨', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 4),
                            Text(
                              'Ask AI',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
