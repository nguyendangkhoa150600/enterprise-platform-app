import 'package:flutter/material.dart';
import '../../domain/models/correspondence_models.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';

/// Filter Bar for Incoming Letters (Stages pills, Date capsule, Catalog filter, Search & Export)
class CorrespondenceIncomingFilterBar extends StatelessWidget {
  final String selectedStage;
  final ValueChanged<String> onStageChanged;

  final String selectedMonthKey; // 'this_month' | 'last_month' | 'this_year' | 'all'
  final ValueChanged<String> onMonthChanged;

  final String? selectedKind;
  final ValueChanged<String?> onKindChanged;

  final String? selectedBookId;
  final ValueChanged<String?> onBookChanged;

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onExport;

  final List<CatalogItem> kinds;
  final List<RegisterBookModel> books;

  const CorrespondenceIncomingFilterBar({
    super.key,
    required this.selectedStage,
    required this.onStageChanged,
    required this.selectedMonthKey,
    required this.onMonthChanged,
    required this.selectedKind,
    required this.onKindChanged,
    required this.selectedBookId,
    required this.onBookChanged,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onExport,
    required this.kinds,
    required this.books,
  });

  static const List<Map<String, String>> stageTabs = [
    {'key': '', 'label': 'Tất cả'},
    {'key': 'received', 'label': 'Văn thư tiếp nhận'},
    {'key': 'processing', 'label': 'Phòng ban xử lý'},
    {'key': 'reviewing', 'label': 'Đang trình duyệt'},
    {'key': 'closing', 'label': 'Chờ hoàn tất'},
    {'key': 'archived', 'label': 'Đã lưu trữ'},
    {'key': 'revoking', 'label': 'Chờ duyệt huỷ'},
    {'key': 'cancelled', 'label': 'Đã huỷ'},
  ];

  static const List<Map<String, String>> monthOptions = [
    {'key': 'this_month', 'label': 'Tháng này'},
    {'key': 'last_month', 'label': 'Tháng trước'},
    {'key': 'this_year', 'label': 'Năm nay'},
    {'key': 'all', 'label': 'Tất cả thời gian'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Tabs (Scrollable horizontal pills)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: stageTabs.map((tab) {
                final isSelected = selectedStage == tab['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onStageChanged(tab['key']!),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1, thickness: 0.6, color: Color(0xFFF1F5F9)),

          // 2. Dropdown Filter Row: Month Capsule, Loại văn bản, Sổ
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(
              children: [
                // Month capsule
                Expanded(
                  flex: 3,
                  child: _buildMonthCapsule(context),
                ),
                const SizedBox(width: 8),

                // Loại văn bản SearchableDropdown
                Expanded(
                  flex: 4,
                  child: SearchableDropdownField<CatalogItem>(
                    value: kinds.where((k) => k.code == selectedKind).firstOrNull,
                    items: kinds,
                    onChanged: (k) => onKindChanged(k.code),
                    itemLabel: (k) => k.name,
                    hintText: 'Tất cả loại văn bản',
                    icon: Icons.search,
                    showClear: true,
                    onClear: () => onKindChanged(null),
                    maxHeight: 200,
                  ),
                ),
              ],
            ),
          ),

          // 3. Search Field & Export Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Tìm theo số, trích yếu, cơ quan gửi...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        suffixIcon: searchController.text.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                                child: const Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onExport,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.assignment_outlined, size: 15, color: Color(0xFF475569)),
                        SizedBox(width: 5),
                        Text(
                          'Xuất sổ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCapsule(BuildContext context) {
    final currentLabel = monthOptions
        .firstWhere((m) => m['key'] == selectedMonthKey, orElse: () => monthOptions.first)['label']!;

    return InkWell(
      onTap: () => _showMonthPickerSheet(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                currentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showMonthPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Text(
                    'Chọn khoảng thời gian',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                const Divider(),
                ...monthOptions.map((opt) {
                  final isSelected = selectedMonthKey == opt['key'];
                  return ListTile(
                    dense: true,
                    title: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onMonthChanged(opt['key']!);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
