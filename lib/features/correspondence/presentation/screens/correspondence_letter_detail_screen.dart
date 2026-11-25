import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/detail/letter_detail_header_card.dart';
import '../widgets/detail/letter_flow_stepper_view.dart';
import '../widgets/detail/letter_action_panel_view.dart';
import '../widgets/detail/letter_assignments_section_view.dart';
import '../widgets/detail/letter_metadata_grid_view.dart';
import '../widgets/detail/letter_steps_review_view.dart';
import '../widgets/detail/letter_comments_view.dart';
import '../widgets/detail/letter_attachments_view.dart';
import '../widgets/detail/letter_history_timeline_view.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../utils/correspondence_error.dart';
import '../../../../core/i18n/app_i18n.dart';

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
  CorrespondenceConfig _config = const CorrespondenceConfig();
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

  /// [silent]: làm mới dữ liệu mà không thay toàn bộ màn bằng spinner
  /// (giữ nguyên state các widget con như ô nhập kết quả xử lý).
  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getLetter(widget.letterId),
        _repository.getDirectory(),
        _repository.getConfig(),
      ]);

      if (!mounted) return;
      setState(() {
        _letter = results[0] as LetterDetail;
        _directory = results[1] as CorrespondenceDirectory;
        _config = results[2] as CorrespondenceConfig;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('correspondence.detail.refresh_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _errorMessage = 'correspondence.detail_screen.load_failed'.tr();
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
        SnackBar(
          content: Text('correspondence.detail_screen.dispatch_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.dispatch_failed'.tr())),
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
        SnackBar(
          content: Text('correspondence.detail_screen.approve_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.approve_failed'.tr())),
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
        SnackBar(
          content: Text('correspondence.detail_screen.return_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.return_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSendToClerk(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.sendToClerk(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.send_to_clerk_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.send_to_clerk_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSubmitLetter(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.submitLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.advance_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.advance_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handlePublishLetter(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.publishLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.issue_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.issue_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCompleteLetter(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.completeLetter(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.complete_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.complete_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCancelLetter(String reason) async {
    try {
      await _repository.cancelLetter(widget.letterId, reason);
      await _loadData(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.cancel_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.cancel_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleUpdateDelivery(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.updateDelivery(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.delivery_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.delivery_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRequestRevoke(Map<String, dynamic> body) async {
    try {
      final updated = await _repository.requestRevoke(widget.letterId, body);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.stage == 'cancelled' ? 'correspondence.detail_screen.cancel_success'.tr() : 'correspondence.detail_screen.revoke_request_sent'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.revoke_request_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDecideRevoke(bool approve, String? note) async {
    try {
      final updated = await _repository.decideRevoke(widget.letterId, approve: approve, note: note);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'correspondence.detail_screen.revoke_approved'.tr() : 'correspondence.detail_screen.revoke_rejected'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.revoke_decide_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleWithdrawRevoke() async {
    try {
      final updated = await _repository.withdrawRevoke(widget.letterId);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.revoke_withdrawn'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.revoke_withdraw_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRemoveLetter() async {
    try {
      await _repository.removeLetter(widget.letterId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.delete_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.delete_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleAssignAssignmentHandler(String assignmentId, String handlerUserId) async {
    try {
      final updated = await _repository.assignAssignmentHandler(widget.letterId, assignmentId, handlerUserId);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.assign_handler_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.assign_handler_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRespondAssignment(String assignmentId, String note) async {
    try {
      final updated = await _repository.respondAssignment(widget.letterId, assignmentId, note);
      if (!mounted) return;
      setState(() => _letter = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.detail_screen.submit_result_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.submit_result_failed'.tr())),
          behavior: SnackBarBehavior.floating,
        ),
      );
      rethrow; // để LetterAssignmentsSectionView giữ lại nội dung đã nhập
    }
  }

  Future<void> _handleUploadResultFile(String assignmentId, dynamic file) async {
    // Không reload ở đây: section gọi onFilesChanged một lần sau khi tải xong.
    await _repository.uploadLetterAttachment(
      widget.letterId,
      file,
      'draft',
      assignmentId: assignmentId,
    );
  }

  Future<void> _handleUploadAttachment(String kind) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );
      if (files.isEmpty) return;

      // Như web: tệp lỗi thì báo riêng tệp đó và vẫn tải tiếp các tệp còn lại.
      int count = 0;
      for (final f in files) {
        try {
          await _repository.uploadLetterAttachment(widget.letterId, f, kind);
          count++;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(correspondenceErrorMessage(e, 'correspondence.attachments.upload_file_failed'.tr(args: {'name': f.name}))),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (count > 0 && mounted) {
        await _loadData(silent: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('correspondence.detail_screen.upload_success'.tr(args: {'count': count})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.upload_failed'.tr())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            content: Text('correspondence.detail_screen.comment_sent_mentions'.tr(args: {'count': mentionedUserIds.length})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.comment_failed'.tr())),
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
        title: Text('correspondence.detail_screen.remind_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'correspondence.detail_screen.remind_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.remindLetter(widget.letterId, 'urgent', noteCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('correspondence.detail_screen.remind_success'.tr()), behavior: SnackBarBehavior.floating),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(correspondenceErrorMessage(e, 'correspondence.detail_screen.remind_failed'.tr())), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            child: Text('correspondence.detail_screen.remind_submit'.tr()),
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
        title: Text(
          'correspondence.detail_screen.title'.tr(),
          style: const TextStyle(
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
            const SizedBox(height: 14),
            Text('correspondence.detail_screen.loading'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                _errorMessage ?? 'correspondence.detail_screen.not_found'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('common.retry'.tr()),
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
                  onReply: () => CorrespondenceOutgoingDialog.show(context, onCreated: _loadData, replyTo: letter),
                  onRemind: _handleRemind,
                  onEdit: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('correspondence.detail_screen.edit_coming_soon'.tr()),
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
                    Tab(text: 'correspondence.detail_screen.tab_processing'.tr()),
                    Tab(text: 'correspondence.detail_screen.tab_info'.tr()),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('correspondence.detail_screen.tab_comments'.tr()),
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
          config: _config,
          directory: _directory,
          onDispatch: _handleDispatch,
          onApprove: _handleApprove,
          onReturn: _handleReturn,
          onSendToClerk: _handleSendToClerk,
          onSubmit: _handleSubmitLetter,
          onPublish: _handlePublishLetter,
          onComplete: _handleCompleteLetter,
          onCancel: _handleCancelLetter,
          onUpdateDelivery: _handleUpdateDelivery,
          onRequestRevoke: _handleRequestRevoke,
          onDecideRevoke: _handleDecideRevoke,
          onWithdrawRevoke: _handleWithdrawRevoke,
          onRemoveLetter: _handleRemoveLetter,
        ),
        const SizedBox(height: 14),

        // 3. Phòng ban xử lý (đồng bộ 1:1 với Web)
        if (letter.assignments.isNotEmpty) ...[
          LetterAssignmentsSectionView(
            letter: letter,
            directory: _directory,
            onAssignHandler: _handleAssignAssignmentHandler,
            onRespond: _handleRespondAssignment,
            onUploadResultFile: _handleUploadResultFile,
            onFilesChanged: () => _loadData(silent: true),
          ),
          const SizedBox(height: 14),
        ],

        // 4. Ý kiến các bước duyệt
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

        // 1.5. Phòng ban xử lý (nếu có đơn vị được giao)
        if (letter.assignments.isNotEmpty) ...[
          LetterAssignmentsSectionView(
            letter: letter,
            directory: _directory,
            onAssignHandler: _handleAssignAssignmentHandler,
            onRespond: _handleRespondAssignment,
            onUploadResultFile: _handleUploadResultFile,
            onFilesChanged: () => _loadData(silent: true),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Tệp của hồ sơ
        LetterAttachmentsView(
          letter: letter,
          onUpload: _handleUploadAttachment,
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
