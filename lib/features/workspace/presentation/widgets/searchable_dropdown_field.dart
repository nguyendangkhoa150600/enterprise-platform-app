import 'package:flutter/material.dart';

/// Searchable & Scrollable Dropdown Menu matching 1:1 Savina ERP Web
class SearchableDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) itemLabel;
  final String? Function(T)? itemSubtitle;
  final String? hintText;
  final IconData? icon;
  final VoidCallback? onClear;
  final bool showClear;
  final double maxHeight;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
    this.itemSubtitle,
    this.hintText,
    this.icon = Icons.search,
    this.onClear,
    this.showClear = true,
    this.maxHeight = 220,
  });

  @override
  State<SearchableDropdownField<T>> createState() => _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T> extends State<SearchableDropdownField<T>> {
  bool _isOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  void _selectItem(T item) {
    widget.onChanged(item);
    setState(() {
      _isOpen = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.value != null ? widget.itemLabel(widget.value as T) : '';
    final filteredItems = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final label = widget.itemLabel(item).toLowerCase();
      final sub = widget.itemSubtitle?.call(item)?.toLowerCase() ?? '';
      return label.contains(q) || sub.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Input Box (Matching Web Q [text] x ^)
        InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _isOpen ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                width: _isOpen ? 1.5 : 1.0,
              ),
              borderRadius: _isOpen
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    )
                  : BorderRadius.circular(6),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: const Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    selectedText.isNotEmpty ? selectedText : (widget.hintText ?? 'Chọn mục...'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selectedText.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      fontWeight: selectedText.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.showClear && selectedText.isNotEmpty && widget.onClear != null)
                  InkWell(
                    onTap: () {
                      widget.onClear!();
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                    ),
                  ),
                const SizedBox(width: 2),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),

        // Dropdown List Container (Matching Web)
        if (_isOpen)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
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
                // Search Input inside dropdown
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
                      const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: (q) => setState(() => _searchQuery = q.trim()),
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Gõ để tìm kiếm...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? InkWell(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Item List
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxHeight),
                  child: filteredItems.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: const Text(
                            'Không tìm thấy kết quả',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isSelected = widget.value != null && item == widget.value;
                              final label = widget.itemLabel(item);
                              final subtitle = widget.itemSubtitle?.call(item);

                              return InkWell(
                                onTap: () => _selectItem(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (subtitle != null && subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check, size: 16, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
