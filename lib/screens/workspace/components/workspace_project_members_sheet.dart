import 'package:flutter/material.dart';
import '../../../models/workspace_models.dart';
import '../../../services/workspace_service.dart';
import '../../../utils/user_resolver.dart';

void showWorkspaceProjectMembersSheet(
  BuildContext context, {
  required ProjectItem project,
  required WorkspaceService service,
  required List<ProjectMemberItem> initialMembers,
  required List<StandaloneTaskItem> projectTasks,
  required VoidCallback onMembersUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WorkspaceProjectMembersSheet(
      project: project,
      service: service,
      initialMembers: initialMembers,
      projectTasks: projectTasks,
      onMembersUpdated: onMembersUpdated,
    ),
  );
}

class WorkspaceProjectMembersSheet extends StatefulWidget {
  final ProjectItem project;
  final WorkspaceService service;
  final List<ProjectMemberItem> initialMembers;
  final List<StandaloneTaskItem> projectTasks;
  final VoidCallback onMembersUpdated;

  const WorkspaceProjectMembersSheet({
    super.key,
    required this.project,
    required this.service,
    required this.initialMembers,
    required this.projectTasks,
    required this.onMembersUpdated,
  });

  @override
  State<WorkspaceProjectMembersSheet> createState() => _WorkspaceProjectMembersSheetState();
}

class _WorkspaceProjectMembersSheetState extends State<WorkspaceProjectMembersSheet> {
  bool _isLoadingDirectory = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<ProjectMemberItem> _members = [];
  final Map<String, WorkspaceDirectoryPerson> _directoryMap = {};
  final Map<String, WorkspaceDirectoryPerson> _directoryByNameOrEmail = {};
  List<WorkspaceDirectoryPerson> _allDirectoryPeople = [];

  // Search in "Thêm người"
  final TextEditingController _searchCtrl = TextEditingController();
  String _addSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _initMembersList();
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _initMembersList() {
    final Map<String, ProjectMemberItem> memberMap = {};

    // 1. Initial members from API
    for (final m in widget.initialMembers) {
      if (m.userId.isNotEmpty) {
        memberMap[m.userId] = m;
      }
    }

    // 2. Synchronize with task assignees if not present
    for (final t in widget.projectTasks) {
      if (t.assigneeUserId.isNotEmpty && !memberMap.containsKey(t.assigneeUserId)) {
        final name = t.assigneeName != null && t.assigneeName!.isNotEmpty
            ? t.assigneeName!
            : UserResolver.resolveName(t.assigneeUserId);
        memberMap[t.assigneeUserId] = ProjectMemberItem(
          userId: t.assigneeUserId,
          fullName: name,
          email: '',
          role: 'member',
        );
      }
    }

    _members = memberMap.values.toList();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoadingDirectory = true);
    try {
      final res = await widget.service.getDirectory();
      if (res != null && mounted) {
        setState(() {
          _allDirectoryPeople = res.people;
          for (final p in res.people) {
            _directoryMap[p.userId] = p;
            if (p.email != null && p.email!.isNotEmpty) {
              _directoryByNameOrEmail[p.email!.toLowerCase()] = p;
            }
            if (p.displayName.isNotEmpty) {
              _directoryByNameOrEmail[p.displayName.trim().toLowerCase()] = p;
            }
            UserResolver.registerUser(p.userId, p.displayName, email: p.email);
          }

          // Reconcile any existing members whose userId might have been from HRM instead of Workspace Directory
          for (int i = 0; i < _members.length; i++) {
            final m = _members[i];
            if (!_directoryMap.containsKey(m.userId)) {
              WorkspaceDirectoryPerson? matched;
              if (m.email != null && m.email!.isNotEmpty) {
                matched = _directoryByNameOrEmail[m.email!.toLowerCase()];
              }
              if (matched == null && m.fullName != null && m.fullName!.isNotEmpty) {
                matched = _directoryByNameOrEmail[m.fullName!.trim().toLowerCase()];
              }
              if (matched != null) {
                _members[i] = ProjectMemberItem(
                  userId: matched.userId,
                  fullName: matched.displayName,
                  email: matched.email ?? m.email,
                  role: m.role,
                );
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[WorkspaceProjectMembersSheet] loadDirectory error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDirectory = false);
    }
  }

  String _formatMemberSubtitle(ProjectMemberItem m) {
    WorkspaceDirectoryPerson? person = _directoryMap[m.userId];
    if (person == null && m.email != null && m.email!.isNotEmpty) {
      person = _directoryByNameOrEmail[m.email!.toLowerCase()];
    }
    if (person == null && m.fullName != null && m.fullName!.isNotEmpty) {
      person = _directoryByNameOrEmail[m.fullName!.trim().toLowerCase()];
    }

    if (person != null) {
      return person.subtitle;
    }

    final name = m.fullName != null && m.fullName!.isNotEmpty && m.fullName != '—'
        ? m.fullName!
        : UserResolver.resolveName(m.userId);
    if (m.email != null && m.email!.isNotEmpty) {
      return '$name · ${m.email}';
    }
    return name;
  }

  List<Map<String, String>> _buildMembersPayload(List<ProjectMemberItem> list) {
    final Map<String, String> userRoleMap = {};
    String? ownerUserId;

    for (final m in list) {
      if (m.userId.isEmpty) continue;

      // Re-verify that the userId is from directory
      String validUserId = m.userId;
      if (!_directoryMap.containsKey(validUserId)) {
        WorkspaceDirectoryPerson? matched;
        if (m.email != null && m.email!.isNotEmpty) {
          matched = _directoryByNameOrEmail[m.email!.toLowerCase()];
        }
        if (matched == null && m.fullName != null && m.fullName!.isNotEmpty) {
          matched = _directoryByNameOrEmail[m.fullName!.trim().toLowerCase()];
        }
        if (matched != null) {
          validUserId = matched.userId;
        }
      }

      String apiRole = m.role.toLowerCase();
      if (apiRole == 'technician') apiRole = 'member';
      if (apiRole == 'pm') apiRole = 'manager';
      if (apiRole == 'owner') {
        ownerUserId = validUserId;
      }
      userRoleMap[validUserId] = apiRole;
    }

    // Backend rule #16: Danh sách phải có ĐÚNG MỘT người vai owner
    if (ownerUserId == null && userRoleMap.isNotEmpty) {
      ownerUserId = userRoleMap.keys.first;
      userRoleMap[ownerUserId] = 'owner';
    }

    return userRoleMap.entries.map((e) {
      return <String, String>{
        'userId': e.key,
        'role': e.value,
      };
    }).toList();
  }

  void _onSelectPersonToAdd(WorkspaceDirectoryPerson person) {
    if (_members.any((m) => m.userId == person.userId)) {
      setState(() {
        _errorMessage = '${person.displayName} đã có trong danh sách thành viên!';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _members.add(ProjectMemberItem(
        userId: person.userId,
        fullName: person.displayName,
        email: person.email ?? '',
        role: 'member',
      ));
      _searchCtrl.clear();
      _addSearchQuery = '';
    });
  }

  void _onUpdateRole(ProjectMemberItem member, String newRole) {
    setState(() {
      _errorMessage = null;
      if (newRole == 'owner') {
        for (int i = 0; i < _members.length; i++) {
          if (_members[i].role.toLowerCase() == 'owner' && _members[i].userId != member.userId) {
            _members[i] = ProjectMemberItem(
              userId: _members[i].userId,
              fullName: _members[i].fullName,
              email: _members[i].email,
              role: 'manager',
            );
          }
        }
      }

      final idx = _members.indexWhere((m) => m.userId == member.userId);
      if (idx != -1) {
        _members[idx] = ProjectMemberItem(
          userId: member.userId,
          fullName: member.fullName,
          email: member.email,
          role: newRole,
        );
      }
    });
  }

  void _onRemoveMember(ProjectMemberItem member) {
    if (member.role.toLowerCase() == 'owner') {
      setState(() {
        _errorMessage = 'Không thể xoá Chủ nhiệm khỏi dự án';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _members.removeWhere((m) => m.userId == member.userId);
    });
  }

  Future<void> _saveAllMembers() async {
    if (_members.isEmpty) {
      setState(() {
        _errorMessage = 'Dự án phải có ít nhất 1 thành viên';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = _buildMembersPayload(_members);
    debugPrint('[WorkspaceProjectMembersSheet] PUT /projects/${widget.project.id}/members: $payload');

    final result = await widget.service.setProjectMembersWithResult(widget.project.id, payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (result.success) {
        widget.onMembersUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu danh sách thành viên dự án thành công!')),
        );
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Không thể lưu danh sách thành viên lên máy chủ!';
        });
      }
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Chủ nhiệm';
      case 'manager':
      case 'pm':
        return 'Quản lý';
      case 'member':
      case 'technician':
        return 'Thành viên';
      case 'viewer':
      default:
        return 'Người xem';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Filter available people for "Thêm người"
    final currentMemberIds = _members.map((m) => m.userId).toSet();
    final matchingPeople = _addSearchQuery.isEmpty
        ? <WorkspaceDirectoryPerson>[]
        : _allDirectoryPeople.where((p) {
            if (currentMemberIds.contains(p.userId)) return false;
            final q = _addSearchQuery.toLowerCase();
            final matchesName = p.displayName.toLowerCase().contains(q);
            final matchesEmail = p.email != null && p.email!.toLowerCase().contains(q);
            final matchesPosition = p.positionName != null && p.positionName!.toLowerCase().contains(q);
            final matchesUnit = p.unitNames.any((u) => u.toLowerCase().contains(q));
            return matchesName || matchesEmail || matchesPosition || matchesUnit;
          }).take(6).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header matching Web: Title + Subtitle count + Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thành viên dự án',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_members.length} thành viên',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Error banner inside modal (visible directly to user)
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 20, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
                      onPressed: () => setState(() => _errorMessage = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],

            // Content Area (Members list + Add Section)
            Expanded(
              child: _isLoadingDirectory && _members.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        // Members rows
                        for (int i = 0; i < _members.length; i++) ...[
                          _buildMemberRow(_members[i]),
                          if (i < _members.length - 1)
                            const Divider(height: 14, color: Color(0xFFF1F5F9)),
                        ],

                        const SizedBox(height: 24),

                        // Section: "Thêm người" matching Web 1:1
                        const Text(
                          'Thêm người',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Search box
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _addSearchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tên, email hoặc đơn vị',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: _addSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _addSearchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Helper text matching Web 1:1
                        const Text(
                          'Người vừa chọn hiện thành một dòng bên trên; chọn vai trò ngay tại dòng đó.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        // Suggestion list from Workspace Directory
                        if (matchingPeople.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: matchingPeople.map((person) {
                                return InkWell(
                                  onTap: () => _onSelectPersonToAdd(person),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_add_alt_1, size: 16, color: Color(0xFFEAB308)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            person.subtitle,
                                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 30),
                      ],
                    ),
            ),

            // Bottom Actions Footer: [Huỷ] and [Lưu] (matching Web 1:1)
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Huỷ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAllMembers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAB308),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Lưu',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Row matching Web 1:1: Full Name · Position · Department + Role Dropdown + Trash Icon
  Widget _buildMemberRow(ProjectMemberItem member) {
    final title = _formatMemberSubtitle(member);
    final currentRoleLabel = _getRoleLabel(member.role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Name and Department text on the left
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown matching Web: [ 🔍 Role ▾ ]
          PopupMenuButton<String>(
            onSelected: (newRole) => _onUpdateRole(member, newRole),
            itemBuilder: (ctx) => [
              _buildRoleMenuItem('owner', 'Chủ nhiệm', member.role.toLowerCase() == 'owner'),
              _buildRoleMenuItem('manager', 'Quản lý', member.role.toLowerCase() == 'manager' || member.role.toLowerCase() == 'pm'),
              _buildRoleMenuItem('member', 'Thành viên', member.role.toLowerCase() == 'member' || member.role.toLowerCase() == 'technician'),
              _buildRoleMenuItem('viewer', 'Người xem', member.role.toLowerCase() == 'viewer'),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    currentRoleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Trash icon
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
            onPressed: () => _onRemoveMember(member),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Xoá thành viên',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildRoleMenuItem(String roleValue, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: roleValue,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 16, color: Color(0xFFEAB308)),
        ],
      ),
    );
  }
}
