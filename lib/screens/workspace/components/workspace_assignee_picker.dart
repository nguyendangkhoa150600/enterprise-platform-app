import 'package:flutter/material.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/platform_service.dart';

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

/// Bộ chọn Người phụ trách (Assignee Picker) đồng bộ 1:1 với Web React:
/// - "Trong dự án" (badge xanh #1D4ED8 / #EFF6FF) kèm chức danh / bộ phận
/// - "Ngoài dự án (N)" (badge vàng #854D0E / #FEF9C3) có thể gập mở và lọc theo Tên / Chức danh
/// - Tìm kiếm tức thì không phân biệt dấu tiếng Việt trên cả 2 nhóm
/// - Mở Full-Width Bottom Sheet chống co cụm và tràn layout trên thiết bị di động
class WorkspaceAssigneePicker extends StatelessWidget {
  final String selectedUserId;
  final List<ProjectMemberItem> members;
  final List<WorkspaceDirectoryPerson> directoryPeople;
  final ValueChanged<String> onChanged;

  const WorkspaceAssigneePicker({
    super.key,
    required this.selectedUserId,
    required this.members,
    required this.directoryPeople,
    required this.onChanged,
  });

  WorkspaceDirectoryPerson? _findPerson(String userId) {
    return directoryPeople.where((p) => p.userId == userId).firstOrNull;
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssigneePickerBottomSheet(
        selectedUserId: selectedUserId,
        members: members,
        directoryPeople: directoryPeople,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberUserIds = members.map((m) => m.userId).toSet();

    String selectedLabel = 'Chưa giao';
    bool isSelectedInProject = true;
    if (selectedUserId.isNotEmpty) {
      final p = _findPerson(selectedUserId);
      final m = members.where((x) => x.userId == selectedUserId).firstOrNull;
      selectedLabel = p?.displayName ?? m?.fullName ?? selectedUserId;
      isSelectedInProject = memberUserIds.contains(selectedUserId);
    }

    return InkWell(
      onTap: () => _openBottomSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: selectedUserId.isEmpty
                  ? const Text(
                      'Chưa giao',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    )
                  : Row(
                      children: [
                        Flexible(
                          child: Text(
                            selectedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelectedInProject ? const Color(0xFFEFF6FF) : const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelectedInProject ? const Color(0xFFBFDBFE) : const Color(0xFFFDE047),
                            ),
                          ),
                          child: Text(
                            isSelectedInProject ? 'Trong dự án' : 'Ngoài dự án',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelectedInProject ? const Color(0xFF1D4ED8) : const Color(0xFF854D0E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneePickerBottomSheet extends StatefulWidget {
  final String selectedUserId;
  final List<ProjectMemberItem> members;
  final List<WorkspaceDirectoryPerson> directoryPeople;
  final ValueChanged<String> onChanged;

  const _AssigneePickerBottomSheet({
    required this.selectedUserId,
    required this.members,
    required this.directoryPeople,
    required this.onChanged,
  });

  @override
  State<_AssigneePickerBottomSheet> createState() => _AssigneePickerBottomSheetState();
}

class _AssigneePickerBottomSheetState extends State<_AssigneePickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _outsideNameCtrl = TextEditingController();
  final TextEditingController _outsideRoleCtrl = TextEditingController();

  String _searchQuery = '';
  String _outsideNameQuery = '';
  String _outsideRoleQuery = '';
  bool _isOutsideExpanded = false;
  List<WorkspaceDirectoryPerson> _allPeople = [];

  @override
  void initState() {
    super.initState();
    _allPeople = List.from(widget.directoryPeople);
    _ensureDirectoryPeople();
  }

  Future<void> _ensureDirectoryPeople() async {
    if (_allPeople.isNotEmpty) return;
    try {
      final uList = await PlatformService().getTenantUsers();
      if (mounted && uList.isNotEmpty) {
        setState(() {
          _allPeople = uList.map((u) {
            final name = u.fullName.isNotEmpty ? u.fullName : (u.username ?? u.email);
            final pos = u.systemRole == 'tenant-admin' ? 'Quản trị viên' : 'Nhân viên';
            return WorkspaceDirectoryPerson(userId: u.id, displayName: name, email: u.email, positionName: pos);
          }).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _outsideNameCtrl.dispose();
    _outsideRoleCtrl.dispose();
    super.dispose();
  }

  WorkspaceDirectoryPerson? _findPerson(String userId) {
    return _allPeople.where((p) => p.userId == userId).firstOrNull;
  }

  String _formatSubtitle(String? position, List<String> units) {
    final parts = <String>[];
    if (position != null && position.trim().isNotEmpty) parts.add(position.trim());
    if (units.isNotEmpty) parts.add(units.join(', '));
    return parts.join(' · ');
  }

  void _selectUser(String userId) {
    widget.onChanged(userId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final memberUserIds = widget.members.map((m) => m.userId).toSet();
    final q = _fold(_searchQuery);

    // 1. Thành viên trong dự án
    final insideMembers = widget.members.where((m) {
      if (q.isEmpty) return true;
      final person = _findPerson(m.userId);
      final name = person?.displayName ?? m.fullName ?? m.userId;
      final sub = _formatSubtitle(person?.positionName, person?.unitNames ?? []);
      return _fold(name).contains(q) || _fold(sub).contains(q);
    }).toList();

    // 2. Người ngoài dự án (lấy từ _allPeople mà không thuộc memberUserIds)
    final outsideQName = _fold(_outsideNameQuery);
    final outsideQRole = _fold(_outsideRoleQuery);

    final allOutside = _allPeople.where((p) => !memberUserIds.contains(p.userId)).toList();
    final outsidePeople = allOutside.where((p) {
      final matchMain = q.isEmpty ||
          _fold(p.displayName).contains(q) ||
          _fold(_formatSubtitle(p.positionName, p.unitNames)).contains(q);
      if (!matchMain) return false;

      final matchName = outsideQName.isEmpty || _fold(p.displayName).contains(outsideQName);
      final matchRole = outsideQRole.isEmpty ||
          _fold(_formatSubtitle(p.positionName, p.unitNames)).contains(outsideQRole);
      return matchName && matchRole;
    }).toList();

    // Khớp Web: Khi gõ tìm kiếm ở ô chính thì tự động bung mở nhóm Ngoài dự án
    final showOutside = _isOutsideExpanded || q.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Người phụ trách',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn từ thành viên dự án hoặc toàn bộ công ty',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Ô tìm kiếm chính
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                hintText: 'Tìm theo tên người phụ trách...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Danh sách cuộn
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                // Mục 1: Chưa giao
                InkWell(
                  onTap: () => _selectUser(''),
                  hoverColor: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chưa giao',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: widget.selectedUserId.isEmpty
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF0F172A),
                              fontWeight: widget.selectedUserId.isEmpty ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (widget.selectedUserId.isEmpty)
                          const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Mục 2: Trong dự án
                if (insideMembers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text(
                      'Trong dự án (${insideMembers.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  ...insideMembers.map((m) {
                    final person = _findPerson(m.userId);
                    final name = person?.displayName ?? m.fullName ?? m.userId;
                    final sub = _formatSubtitle(person?.positionName, person?.unitNames ?? []);
                    final isSelected = widget.selectedUserId == m.userId;

                    return InkWell(
                      onTap: () => _selectUser(m.userId),
                      hoverColor: const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Text(
                                          'Trong dự án',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF1D4ED8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (sub.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],

                // Mục 3: Ngoài dự án (Gập mở có thể lọc)
                if (allOutside.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _isOutsideExpanded = !_isOutsideExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ngoài dự án (${allOutside.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          Icon(
                            showOutside ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 18,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (showOutside) ...[
                    // Bộ lọc kép đồng bộ Web: [Tên] và [Chức danh / bộ phận]
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: TextField(
                                controller: _outsideNameCtrl,
                                onChanged: (val) => setState(() => _outsideNameQuery = val.trim()),
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Tên',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: TextField(
                                controller: _outsideRoleCtrl,
                                onChanged: (val) => setState(() => _outsideRoleQuery = val.trim()),
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Chức danh / bộ phận',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Danh sách nhân sự ngoài dự án
                    if (outsidePeople.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Không tìm thấy nhân sự phù hợp',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      ...outsidePeople.map((p) {
                        final isSelected = widget.selectedUserId == p.userId;
                        final sub = _formatSubtitle(p.positionName, p.unitNames);

                        return InkWell(
                          onTap: () => _selectUser(p.userId),
                          hoverColor: const Color(0xFFF8FAFC),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.displayName,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF9C3),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFFDE047)),
                                            ),
                                            child: const Text(
                                              'Ngoài dự án',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF854D0E),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (sub.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sub,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
