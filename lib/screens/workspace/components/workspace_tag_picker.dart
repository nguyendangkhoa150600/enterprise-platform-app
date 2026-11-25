import 'package:flutter/material.dart';

/// Bảng màu chuẩn từ Web (packages/features/workspace/src/lib/components/use-tags.ts)
const List<Color> _tagPalette = [
  Color(0xFF2563EB),
  Color(0xFF0D9488),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFD97706),
  Color(0xFF16A34A),
  Color(0xFF475569),
];

Color getTagColor(String name, [String? colorHex]) {
  if (colorHex != null && colorHex.isNotEmpty) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
  }
  int hash = 0;
  for (int i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return _tagPalette[hash % _tagPalette.length];
}

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

/// Bộ chọn nhãn đa năng (TagPicker) khớp 1:1 với Web MultiSelectBox
/// - Chiều rộng dropdown 100% tràn đều theo ô input
/// - Tìm kiếm tức thì không phân biệt dấu
/// - Cho phép chọn/bỏ chọn nhiều nhãn cùng lúc không bị đóng đột ngột
/// - Hỗ trợ tạo nhãn mới nhanh nếu chưa có
class WorkspaceTagPicker extends StatefulWidget {
  final List<String> selectedTagIds;
  final List<Map<String, dynamic>> availableTags;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<Map<String, dynamic>>? onTagCreated;
  final Future<Map<String, dynamic>?> Function(String name)? createTagAction;

  const WorkspaceTagPicker({
    super.key,
    required this.selectedTagIds,
    required this.availableTags,
    required this.onChanged,
    this.onTagCreated,
    this.createTagAction,
  });

  @override
  State<WorkspaceTagPicker> createState() => _WorkspaceTagPickerState();
}

class _WorkspaceTagPickerState extends State<WorkspaceTagPicker> {
  bool _isOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _newTagCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isCreating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    setState(() {
      _isOpen = !_isOpen;
      if (!_isOpen) {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });
  }

  void _toggleTag(String tagId) {
    final list = List<String>.from(widget.selectedTagIds);
    if (list.contains(tagId)) {
      list.remove(tagId);
    } else {
      list.add(tagId);
    }
    widget.onChanged(list);
  }

  Future<void> _handleCreateTag(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty || _isCreating) return;

    // Kiểm tra xem đã có nhãn trùng tên chưa
    final folded = _fold(name);
    final existing = widget.availableTags.firstWhere(
      (t) => _fold(t['name']?.toString() ?? '') == folded,
      orElse: () => {},
    );

    if (existing.isNotEmpty && existing['id'] != null) {
      final id = existing['id'].toString();
      if (!widget.selectedTagIds.contains(id)) {
        _toggleTag(id);
      }
      _searchCtrl.clear();
      _newTagCtrl.clear();
      setState(() => _searchQuery = '');
      return;
    }

    if (widget.createTagAction == null) return;

    setState(() => _isCreating = true);
    try {
      final created = await widget.createTagAction!(name);
      if (mounted && created != null && created['id'] != null) {
        widget.onTagCreated?.call(created);
        _toggleTag(created['id'].toString());
        _searchCtrl.clear();
        _newTagCtrl.clear();
        setState(() {
          _searchQuery = '';
        });
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldedQuery = _fold(_searchQuery);
    final filteredTags = widget.availableTags.where((t) {
      if (foldedQuery.isEmpty) return true;
      final name = t['name']?.toString() ?? '';
      return _fold(name).contains(foldedQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Khung Input hiển thị Chip (Full-width, đều đẹp)
        InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _isOpen
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    )
                  : BorderRadius.circular(8),
              border: Border.all(
                color: _isOpen ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                width: _isOpen ? 1.5 : 1.0,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: widget.selectedTagIds.isEmpty
                      ? const Text(
                          'Chọn hoặc gõ để tìm nhãn',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: widget.selectedTagIds.map((tagId) {
                            final tag = widget.availableTags.firstWhere(
                              (t) => t['id']?.toString() == tagId,
                              orElse: () => {'name': tagId},
                            );
                            final name = tag['name']?.toString() ?? tagId;
                            final color = getTagColor(name, tag['color']?.toString());

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: color.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _toggleTag(tagId),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(1.0),
                                      child: Icon(Icons.close, size: 13, color: color),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                if (widget.selectedTagIds.isNotEmpty) ...[
                  InkWell(
                    onTap: () => widget.onChanged([]),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: _isOpen ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),

        // 2. Dropdown List hiển thị đều 100% bề rộng
        if (_isOpen)
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
              children: [
                // Ô tìm kiếm nhãn tức thì (Search input)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: (q) => setState(() => _searchQuery = q.trim()),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _handleCreateTag(val);
                            }
                          },
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Gõ để tìm nhãn...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        InkWell(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),

                // Danh sách nhãn (Scrollable list)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: filteredTags.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          alignment: Alignment.center,
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'Không có nhãn nào khớp. Nhấn tạo ở dưới để thêm.'
                                : 'Chưa có nhãn nào.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        )
                      : Scrollbar(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filteredTags.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final tag = filteredTags[index];
                              final id = tag['id']?.toString() ?? '';
                              final name = tag['name']?.toString() ?? id;
                              final isSelected = widget.selectedTagIds.contains(id);
                              final color = getTagColor(name, tag['color']?.toString());

                              return InkWell(
                                onTap: () => _toggleTag(id),
                                hoverColor: const Color(0xFFF8FAFC),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Color(0xFF2563EB),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),

                // Chân Dropdown: Thêm nhãn mới nếu người dùng gõ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Tạo nhanh "$_searchQuery"'
                              : 'Đã chọn ${widget.selectedTagIds.length} nhãn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty && widget.createTagAction != null) ...[
                        TextButton.icon(
                          onPressed: _isCreating ? null : () => _handleCreateTag(_searchQuery),
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                )
                              : const Icon(Icons.add, size: 14),
                          label: const Text('Thêm nhãn', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      TextButton(
                        onPressed: () => setState(() => _isOpen = false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF475569),
                        ),
                        child: const Text('Xong', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
