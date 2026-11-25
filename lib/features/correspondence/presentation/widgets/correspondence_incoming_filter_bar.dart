import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/correspondence_models.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';

/// Filter Bar for Incoming Letters (Stages pills, Date capsule, Catalog filter, Search & Export)
class CorrespondenceIncomingFilterBar extends StatefulWidget {
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
    {'key': '', 'label': 'common.all'},
    {'key': 'received', 'label': 'correspondence.filter.stage_received'},
    {'key': 'processing', 'label': 'correspondence.filter.stage_processing'},
    {'key': 'reviewing', 'label': 'correspondence.filter.stage_reviewing'},
    {'key': 'closing', 'label': 'correspondence.filter.stage_closing'},
    {'key': 'overdue', 'label': 'correspondence.filter.stage_overdue'},
    {'key': 'archived', 'label': 'correspondence.filter.stage_archived'},
    {'key': 'revoking', 'label': 'correspondence.filter.stage_revoking'},
    {'key': 'cancelled', 'label': 'correspondence.filter.stage_cancelled'},
  ];

  static const List<Map<String, String>> monthOptions = [
    {'key': 'this_month', 'label': 'correspondence.filter.period_this_month'},
    {'key': 'last_month', 'label': 'correspondence.filter.period_last_month'},
    {'key': 'this_year', 'label': 'correspondence.filter.period_this_year'},
    {'key': 'all', 'label': 'correspondence.filter.period_all'},
  ];

  @override
  State<CorrespondenceIncomingFilterBar> createState() => _CorrespondenceIncomingFilterBarState();
}

class _CorrespondenceIncomingFilterBarState extends State<CorrespondenceIncomingFilterBar> {
  final ScrollController _stageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToSelectedStage();
  }

  @override
  void didUpdateWidget(covariant CorrespondenceIncomingFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStage != widget.selectedStage) {
      _scrollToSelectedStage();
    }
  }

  @override
  void dispose() {
    _stageScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedStage() {
    final idx = CorrespondenceIncomingFilterBar.stageTabs
        .indexWhere((tab) => tab['key'] == widget.selectedStage);
    if (idx <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stageScrollController.hasClients) return;
      final target = (idx * 115.0) - 40.0;
      final maxScroll = _stageScrollController.position.maxScrollExtent;
      _stageScrollController.animateTo(
        target.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

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
            controller: _stageScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: CorrespondenceIncomingFilterBar.stageTabs.map((tab) {
                final isSelected = widget.selectedStage == tab['key'];
                final isOverdue = tab['key'] == 'overdue';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => widget.onStageChanged(tab['key']!),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isOverdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
                            : (isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isOverdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
                              : (isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOverdue) ...[
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: isSelected ? Colors.white : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            tab['label']!.tr(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isOverdue ? const Color(0xFFDC2626) : const Color(0xFF475569)),
                            ),
                          ),
                        ],
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
                    value: widget.kinds.where((k) => k.code == widget.selectedKind).firstOrNull,
                    items: widget.kinds,
                    onChanged: (k) => widget.onKindChanged(k.code),
                    itemLabel: (k) => k.name,
                    hintText: 'correspondence.filter.all_kinds'.tr(),
                    icon: Icons.search,
                    showClear: true,
                    onClear: () => widget.onKindChanged(null),
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
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      onChanged: widget.onSearchChanged,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'correspondence.filter.search_hint_incoming'.tr(),
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        suffixIcon: widget.searchController.text.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  widget.searchController.clear();
                                  widget.onSearchChanged('');
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
                  onTap: widget.onExport,
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
                      children: [
                        const Icon(Icons.assignment_outlined, size: 15, color: Color(0xFF475569)),
                        const SizedBox(width: 5),
                        Text(
                          'correspondence.filter.export_register'.tr(),
                          style: const TextStyle(
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
    final currentLabel = CorrespondenceIncomingFilterBar.monthOptions
        .firstWhere((m) => m['key'] == widget.selectedMonthKey,
            orElse: () => CorrespondenceIncomingFilterBar.monthOptions.first)['label']!.tr();

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Text(
                    'correspondence.filter.pick_time_range'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                const Divider(),
                ...CorrespondenceIncomingFilterBar.monthOptions.map((opt) {
                  final isSelected = widget.selectedMonthKey == opt['key'];
                  return ListTile(
                    dense: true,
                    title: Text(
                      opt['label']!.tr(),
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
                      widget.onMonthChanged(opt['key']!);
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
