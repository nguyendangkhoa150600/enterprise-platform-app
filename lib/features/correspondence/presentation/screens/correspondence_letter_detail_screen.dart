import 'package:flutter/material.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/detail/letter_detail_header_card.dart';
import '../widgets/detail/letter_flow_stepper_view.dart';
import '../widgets/detail/letter_action_panel_view.dart';
import '../widgets/detail/letter_metadata_grid_view.dart';
import '../widgets/detail/letter_steps_review_view.dart';
import '../widgets/detail/letter_comments_view.dart';
import '../widgets/detail/letter_attachments_view.dart';
import '../widgets/detail/letter_history_timeline_view.dart';
import '../widgets/correspondence_outgoing_dialog.dart';

/// Full-detail screen for an Incoming or Outgoing Letter with 3 sub-tabs matching Savina Web
class CorrespondenceLetterDetailScreen extends StatefulWidget {
  final String letterId;

  const CorrespondenceLetterDetailScreen({
    super.key,
    required this.letterId,
  });

  static Future<void> open(BuildContext context, String letterId) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CorrespondenceLetterDetailScreen(letterId: letterId),
      ),
    );
  }

  @override
  State<CorrespondenceLetterDetailScreen> createState() =>
      _CorrespondenceLetterDetailScreenState();
}

class _CorrespondenceLetterDetailScreenState
    extends State<CorrespondenceLetterDetailScreen>
    with SingleTickerProviderStateMixin {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  late final TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  LetterDetail? _letter;
  CorrespondenceDirectory _directory = const CorrespondenceDirectory();
  late final String _today;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _today = CorrespondenceDateUtils.localToday();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getLetter(widget.letterId),
        _repository.getDirectory(),
      ]);

      if (!mounted) return;
      setState(() {
        _letter = results[0] as LetterDetail;
        _directory = results[1] as CorrespondenceDirectory;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được chi tiết công văn. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDispatch(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.dispatchLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã giao phòng ban xử lý thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể giao phòng ban. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.approveLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã duyệt công văn thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể duyệt công văn. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleReturn(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.returnLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã trả lại công văn.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể trả lại công văn. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSendComment(String content, List<String> mentionedUserIds) async {
    try {
      final updated = await _repository.commentLetter(
        widget.letterId,
        content,
        mentionedUserIds: mentionedUserIds,
      );
      if (!mounted) return;
      setState(() => _letter = updated);
      if (mentionedUserIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi trao đổi, báo ${mentionedUserIds.length} người được nhắc.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể gửi trao đổi. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleRemind() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đôn đốc xử lý', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập nội dung nhắc nhở đôn đốc...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.remindLetter(widget.letterId, 'urgent', noteCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi thông báo đôn đốc thành công.'), behavior: SnackBarBehavior.floating),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không thể gửi đôn đốc.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            child: const Text('Gửi đôn đốc'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chi tiết công văn',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
            SizedBox(height: 14),
            Text('Đang tải chi tiết công văn...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null || _letter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Không tìm thấy thông tin công văn.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final letter = _letter!;

    return RefreshIndicator(
      color: const Color(0xFF0284C7),
      onRefresh: _loadData,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 1. Header Card (Pinned info at the top)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: LetterDetailHeaderCard(
                  letter: letter,
                  onReply: () => CorrespondenceOutgoingDialog.show(context, onCreated: _loadData),
                  onRemind: _handleRemind,
                  onEdit: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chức năng sửa thông tin đang được cập nhật.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Persistent TabBar with 3 sub-tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _LetterDetailTabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: [
                    const Tab(text: 'Xử lý'),
                    const Tab(text: 'Thông tin'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Trao đổi'),
                          if (letter.comments.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${letter.comments.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Tiến trình & Xử lý
            _buildProcessingTab(letter),

            // Tab 2: Thông tin & Hồ sơ
            _buildInfoTab(letter),

            // Tab 3: Trao đổi
            _buildCommentsTab(letter),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Tiến trình xử lý & Thao tác duyệt/giao phòng ban
  Widget _buildProcessingTab(LetterDetail letter) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        // 1. Tiến trình xử lý (FlowStepper)
        LetterFlowStepperView(
          flow: letter.flow,
          workflowName: letter.workflowName,
        ),
        const SizedBox(height: 14),

        // 2. Thao tác bước hiện tại (Action Panel)
        LetterActionPanelView(
          letter: letter,
          units: _directory.units,
          onDispatch: _handleDispatch,
          onApprove: _handleApprove,
          onReturn: _handleReturn,
        ),
        if (letter.actions.dispatch || letter.actions.approve)
          const SizedBox(height: 14),

        // 3. Ý kiến các bước duyệt
        LetterStepsReviewView(
          steps: letter.steps,
        ),
      ],
    );
  }

  /// Tab 2: Thông tin chi tiết, tệp đính kèm và lịch sử
  Widget _buildInfoTab(LetterDetail letter) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        // 1. Thông tin công văn (Metadata Grid)
        LetterMetadataGridView(
          letter: letter,
          today: _today,
        ),
        const SizedBox(height: 14),

        // 2. Tệp của hồ sơ
        LetterAttachmentsView(
          attachments: letter.attachments,
          onUploadScan: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đang chuẩn bị tải bản quét công văn đến...'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          onUploadRef: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đang chuẩn bị tải tài liệu kèm theo...'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. Lịch sử xử lý
        LetterHistoryTimelineView(
          history: letter.history,
        ),
      ],
    );
  }

  /// Tab 3: Trao đổi & Thảo luận nội bộ
  Widget _buildCommentsTab(LetterDetail letter) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        LetterCommentsView(
          comments: letter.comments,
          people: _directory.people,
          onSendComment: _handleSendComment,
        ),
      ],
    );
  }
}

/// Sliver delegate to keep TabBar pinned at the top when scrolling
class _LetterDetailTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _LetterDetailTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height + 12;

  @override
  double get maxExtent => tabBar.preferredSize.height + 12;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LetterDetailTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
