import 'package:flutter/material.dart';
import '../../../models/social_models.dart';
import '../../../services/social_service.dart';

class SocialGroupsView extends StatefulWidget {
  final Function(String groupId, String groupName) onGroupSelected;

  const SocialGroupsView({
    super.key,
    required this.onGroupSelected,
  });

  @override
  State<SocialGroupsView> createState() => _SocialGroupsViewState();
}

class _SocialGroupsViewState extends State<SocialGroupsView> {
  String _tab = 'all'; // 'mine' | 'all'
  final List<SocialGroupSummary> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final list = await SocialService().getGroups(
      scope: _tab,
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
    if (mounted) {
      setState(() {
        _groups.clear();
        _groups.addAll(list);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleJoin(SocialGroupSummary group) async {
    if (group.isMember) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rời khỏi nhóm'),
          content: Text('Bạn có chắc muốn rời khỏi nhóm "${group.name}" không?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rời nhóm', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await SocialService().leaveGroup(group.id);
        _loadGroups();
      }
    } else {
      await SocialService().joinGroup(group.id);
      _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar & Tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) {
                    setState(() => _searchQuery = q.trim());
                    _loadGroups();
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nhóm...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadGroups();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả nhóm'),
                    selected: _tab == 'all',
                    onSelected: (val) {
                      if (val && _tab != 'all') {
                        setState(() => _tab = 'all');
                        _loadGroups();
                      }
                    },
                    selectedColor: const Color(0xFFEFF6FF),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _tab == 'all' ? FontWeight.bold : FontWeight.normal,
                      color: _tab == 'all' ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Nhóm của bạn'),
                    selected: _tab == 'mine',
                    onSelected: (val) {
                      if (val && _tab != 'mine') {
                        setState(() => _tab = 'mine');
                        _loadGroups();
                      }
                    },
                    selectedColor: const Color(0xFFEFF6FF),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _tab == 'mine' ? FontWeight.bold : FontWeight.normal,
                      color: _tab == 'mine' ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Groups List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadGroups,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? Center(
                        child: Text(
                          _tab == 'mine' ? 'Bạn chưa tham gia nhóm nào.' : 'Chưa có nhóm nào được tạo.',
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        itemCount: _groups.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final g = _groups[index];
                          final isPublic = g.privacy == 'public';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB), size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g.name,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isPublic ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isPublic ? 'Công khai' : 'Riêng tư',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isPublic ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${g.memberCount} thành viên · ${g.postCount} bài viết',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (g.description != null && g.description!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    g.description!,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (g.isMember) ...[
                                      TextButton(
                                        onPressed: () => _toggleJoin(g),
                                        child: const Text('Rời nhóm', style: TextStyle(color: Colors.red, fontSize: 12.5)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => widget.onGroupSelected(g.id, g.name),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Xem nhóm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ),
                                    ] else
                                      ElevatedButton(
                                        onPressed: () => _toggleJoin(g),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Tham gia', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
