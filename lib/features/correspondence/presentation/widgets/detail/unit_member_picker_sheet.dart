import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../../../widgets/user_avatar.dart';

/// Modal BottomSheet tìm kiếm và chọn nhân sự xử lý trong phòng ban (Rule 5.2)
class UnitMemberPickerSheet extends StatefulWidget {
  final OrgUnitModel unit;
  final String currentHandlerUserId;

  const UnitMemberPickerSheet({
    super.key,
    required this.unit,
    required this.currentHandlerUserId,
  });

  static Future<String?> show(
    BuildContext context, {
    required OrgUnitModel unit,
    required String currentHandlerUserId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => UnitMemberPickerSheet(
        unit: unit,
        currentHandlerUserId: currentHandlerUserId,
      ),
    );
  }

  @override
  State<UnitMemberPickerSheet> createState() => _UnitMemberPickerSheetState();
}

class _UnitMemberPickerSheetState extends State<UnitMemberPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = widget.unit.members;
    final filtered = members.where((m) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          (m.positionName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tiêu đề
          Text(
            'correspondence.picker.member_title'.tr(args: {'unit': widget.unit.name}),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          // Ô tìm kiếm nhân sự tức thì (Rule 5.2)
          TextField(
            autofocus: false,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              hintText: 'correspondence.picker.member_search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
          const SizedBox(height: 10),

          // Tuỳ chọn mặc định: Cả phòng cùng nhận
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF2563EB)),
            ),
            title: Text(
              'correspondence.picker.whole_unit_default'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
            ),
            subtitle: Text(
              'correspondence.picker.whole_unit_desc'.tr(),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            trailing: widget.currentHandlerUserId.isEmpty
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18)
                : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(height: 1),

          // Danh sách nhân sự trong phòng
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'correspondence.picker.no_members'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'correspondence.picker.no_match'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (itemCtx, i) {
                  final m = filtered[i];
                  final isCurrent = m.userId == widget.currentHandlerUserId;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(
                      userId: m.userId,
                      name: m.name,
                      size: 32,
                      background: const Color(0xFFF1F5F9),
                      foreground: const Color(0xFF475569),
                      fontSize: 12,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m.isHead) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'correspondence.picker.head'.tr(),
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: m.positionName != null
                        ? Text(m.positionName!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                        : null,
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, m.userId),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
