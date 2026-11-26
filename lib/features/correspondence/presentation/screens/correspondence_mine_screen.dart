import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/correspondence_letter_detail_bottom_sheet.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';

class CorrespondenceMineScreen extends StatefulWidget {
  const CorrespondenceMineScreen({super.key});

  @override
  State<CorrespondenceMineScreen> createState() => _CorrespondenceMineScreenState();
}

class _CorrespondenceMineScreenState extends State<CorrespondenceMineScreen> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<LetterSummary> _letters = [];
  CorrespondenceStatus _status = const CorrespondenceStatus();
  String _searchQuery = '';
  Timer? _debounceTimer;
  late final String _today;

  @override
  void initState() {
    super.initState();
    _today = CorrespondenceDateUtils.localToday();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getLetters(box: 'mine', search: _searchQuery),
        _repository.getStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _letters = results[0] as List<LetterSummary>;
        _status = results[1] as CorrespondenceStatus;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'correspondence.list.mine_load_failed'.tr();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadData();
    });
  }

  void _onActionTap(String action) {
    if (action == 'Soạn công văn đi') {
      CorrespondenceOutgoingDialog.show(context, onCreated: _loadData);
      return;
    }
    if (action == 'Tiếp nhận công văn đến') {
      CorrespondenceIntakeDialog.show(context, onCreated: _loadData);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('correspondence.list.feature_coming_soon'.tr(args: {'action': action})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'correspondence.list.mine_title'.tr(),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'correspondence.list.mine_breadcrumb'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Buttons
              _buildTopActions(),
              const SizedBox(height: 12),

              // Search Bar matching Web: "Tìm theo số, trích yếu, cơ quan gửi"
              _buildSearchBar(),
              const SizedBox(height: 14),

              // Content Area: Loading / Error / Empty / List
              _buildContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopActions() {
    final canCreateOutgoing = _status.canCreateOutgoing || _status.isTenantAdmin;
    final canRegister = _status.canRegister || _status.isTenantAdmin;

    if (!canCreateOutgoing && !canRegister) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Soạn công văn đi (Outlined Button)
          if (canCreateOutgoing) ...[
            OutlinedButton.icon(
              onPressed: () => _onActionTap('Soạn công văn đi'),
              icon: const Icon(Icons.edit_document, size: 16, color: Color(0xFF0284C7)),
              label: Text(
                'correspondence.list.compose_outgoing'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0284C7),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Tiếp nhận công văn đến (Filled Primary Button)
          if (canRegister)
            ElevatedButton.icon(
              onPressed: () => _onActionTap('Tiếp nhận công văn đến'),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                'correspondence.list.register_incoming'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'correspondence.list.mine_search_hint'.tr(),
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
            const SizedBox(height: 12),
            Text(
              'correspondence.list.mine_loading'.tr(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
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

    if (_letters.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x030F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _searchQuery.isNotEmpty
                ? 'correspondence.list.mine_empty_search'.tr()
                : 'correspondence.list.mine_empty'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x030F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _letters.length,
            separatorBuilder: (_, index) => const Divider(
              height: 1,
              color: Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final letter = _letters[index];
              return _buildLetterItem(context, letter);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'correspondence.list.showing_count'.tr(args: {'count': _letters.length}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterItem(BuildContext context, LetterSummary letter) {
    final isIncoming = letter.direction == 'incoming';
    final dateStr = CorrespondenceDateUtils.formatDay(
      !isIncoming && letter.publishedOn != null && letter.publishedOn!.isNotEmpty
          ? letter.publishedOn
          : letter.receivedOn,
    );
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, _today);
    final partyText = isIncoming
        ? (letter.senderRef != null && letter.senderRef!.isNotEmpty
            ? '${letter.senderOrg} · ${letter.senderRef}'
            : letter.senderOrg)
        : '${letter.authorUnitName ?? letter.authorName ?? ""} → ${letter.recipient ?? ""}';

    return InkWell(
      onTap: () {
        CorrespondenceLetterDetailBottomSheet.show(context, letter, _today);
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Số hiệu, Chiều văn bản (Đến/Đi), Ngày vào sổ & Độ khẩn chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        letter.displayNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isIncoming ? 'correspondence.list.direction_in'.tr() : 'correspondence.list.direction_out'.tr()} · $dateStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildUrgencyChip(letter),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Trích yếu (Tiêu đề công văn)
            Text(
              letter.subject,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // Row 3: Cơ quan ban hành / Gửi đến
            if (partyText.isNotEmpty)
              Text(
                partyText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            const SizedBox(height: 10),

            // Row 4: Bước xử lý & Hạn xử lý
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bước xử lý
                Expanded(
                  child: Row(
                    children: [
                      _buildStageChip(letter),
                      if (letter.currentAssigneeNames.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            letter.currentAssigneeNames.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Hạn xử lý
                if (due != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: due.bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: due.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          due.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: due.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (letter.dueOn != null && letter.dueOn!.isNotEmpty)
                  Text(
                    CorrespondenceDateUtils.formatDay(letter.dueOn),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(LetterSummary letter) {
    final isHighlight = letter.urgencyHighlight;
    final color = isHighlight ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final bgColor = isHighlight ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            letter.urgencyName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(LetterSummary letter) {
    Color textColor = const Color(0xFF2563EB);
    Color bgColor = const Color(0xFFEFF6FF);

    if (letter.stage == 'reviewing') {
      textColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFEF3C7);
    } else if (letter.stage == 'archived') {
      textColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFF0FDF4);
    }

    final label = letter.stageLabel.isNotEmpty
        ? letter.stageLabel
        : CorrespondenceConstants.stageLabelOf(letter.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
