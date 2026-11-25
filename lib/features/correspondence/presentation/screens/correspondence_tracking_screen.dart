import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/correspondence_letter_detail_bottom_sheet.dart';

/// Screen "Theo dõi đôn đốc" (Tracking View) matching Savina ERP Web 1:1
/// Hiển thị toàn bộ công văn có hạn xử lý, quá hạn và đôn đốc nhắc việc.
class CorrespondenceTrackingScreen extends StatefulWidget {
  final String initialFilter; // 'overdue' | 'soon' | 'all'

  const CorrespondenceTrackingScreen({
    super.key,
    this.initialFilter = 'overdue',
  });

  @override
  State<CorrespondenceTrackingScreen> createState() => _CorrespondenceTrackingScreenState();
}

class _CorrespondenceTrackingScreenState extends State<CorrespondenceTrackingScreen> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<LetterSummary> _allLetters = [];
  CorrespondenceStatus _status = const CorrespondenceStatus();

  late String _currentFilter; // 'overdue' | 'soon' | 'all'
  String _searchQuery = '';
  Timer? _debounceTimer;
  late final String _today;

  @override
  void initState() {
    super.initState();
    _today = CorrespondenceDateUtils.localToday();
    _currentFilter = widget.initialFilter;
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
        _repository.getLetters(box: 'tracking'),
        _repository.getStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _allLetters = results[0] as List<LetterSummary>;
        _status = results[1] as CorrespondenceStatus;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'correspondence.tracking.load_failed'.tr();
        _isLoading = false;
      });
    }
  }

  int _daysUntil(String? dueOn) {
    if (dueOn == null || dueOn.isEmpty) return 999;
    try {
      final dueDate = DateTime.parse('${dueOn.substring(0, 10)}T00:00:00Z');
      final todayDate = DateTime.parse('${_today.substring(0, 10)}T00:00:00Z');
      return dueDate.difference(todayDate).inDays;
    } catch (_) {
      return 999;
    }
  }

  Map<String, int> _getCounts() {
    int overdue = 0;
    int soon = 0;
    int all = _allLetters.length;

    for (final l in _allLetters) {
      final days = _daysUntil(l.dueOn);
      if (days < 0) {
        overdue++;
      } else if (days <= 3) {
        soon++;
      }
    }
    return {'overdue': overdue, 'soon': soon, 'all': all};
  }

  List<LetterSummary> _getFilteredLetters() {
    return _allLetters.where((letter) {
      final days = _daysUntil(letter.dueOn);

      // 1. Filter Tab
      if (_currentFilter == 'overdue' && days >= 0) {
        return false;
      }
      if (_currentFilter == 'soon' && (days < 0 || days > 3)) {
        return false;
      }

      // 2. Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSubject = letter.subject.toLowerCase().contains(q);
        final matchNo = letter.displayNo.toLowerCase().contains(q);
        final matchOrg = letter.senderOrg.toLowerCase().contains(q);
        final matchRecipient = (letter.recipient ?? '').toLowerCase().contains(q);
        if (!matchSubject && !matchNo && !matchOrg && !matchRecipient) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showRemindDialog(LetterSummary letter) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'correspondence.tracking.remind_title'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'correspondence.tracking.remind_message'.tr(args: {'no': letter.displayNo, 'stage': letter.stageLabel}),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'correspondence.tracking.remind_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 12.5),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final note = noteCtrl.text.trim();
              if (note.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.remindLetter(letter.id, 'urgent', note);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('correspondence.tracking.remind_sent'.tr(args: {'no': letter.displayNo})),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('correspondence.tracking.remind_failed'.tr()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            child: Text('correspondence.tracking.send_reminder'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _getCounts();
    final visibleLetters = _getFilteredLetters();
    final canRemind = _status.canRegister || _status.canReadReports || _status.isTenantAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              'correspondence.tracking.title'.tr(),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'correspondence.tracking.breadcrumb'.tr(),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                // Horizontal Tabs (Quá hạn · Sắp đến hạn · Tất cả)
                Row(
                  children: [
                    _buildFilterChip(
                      id: 'overdue',
                      label: 'correspondence.filter.stage_overdue'.tr(),
                      count: counts['overdue'] ?? 0,
                      isToneDanger: true,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      id: 'soon',
                      label: 'correspondence.tracking.filter_soon'.tr(),
                      count: counts['soon'] ?? 0,
                      isToneWarning: true,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      id: 'all',
                      label: 'correspondence.tracking.filter_all'.tr(),
                      count: counts['all'] ?? 0,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search field
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'correspondence.tracking.search_hint'.tr(),
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? InkWell(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),

          // Body List / Loading / Empty
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626))),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _loadData, child: Text('common.retry'.tr())),
                          ],
                        ),
                      )
                    : visibleLetters.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: visibleLetters.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final letter = visibleLetters[index];
                                return _buildTrackingCard(letter, canRemind);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    bool isToneDanger = false,
    bool isToneWarning = false,
  }) {
    final isSelected = _currentFilter == id;
    Color activeBg = const Color(0xFF2563EB);
    Color normalBg = const Color(0xFFF1F5F9);
    Color normalBorder = const Color(0xFFE2E8F0);
    Color normalText = const Color(0xFF475569);

    if (isToneDanger) {
      activeBg = const Color(0xFFDC2626);
      if (!isSelected && count > 0) {
        normalBg = const Color(0xFFFEF2F2);
        normalBorder = const Color(0xFFFECACA);
        normalText = const Color(0xFFDC2626);
      }
    } else if (isToneWarning) {
      activeBg = const Color(0xFFD97706);
      if (!isSelected && count > 0) {
        normalBg = const Color(0xFFFFFBEB);
        normalBorder = const Color(0xFFFDE68A);
        normalText = const Color(0xFFD97706);
      }
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _currentFilter = id);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : normalBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? activeBg : normalBorder),
          ),
          child: Text(
            '$label · $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : normalText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingCard(LetterSummary letter, bool canRemind) {
    final isIncoming = letter.direction == 'incoming';
    final due = CorrespondenceDateUtils.dueText(letter.dueOn, letter.stage, _today);
    final partyText = isIncoming
        ? letter.senderOrg
        : (letter.recipient != null && letter.recipient!.isNotEmpty ? '→ ${letter.recipient}' : '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: due?.isOverdue == true ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: due?.isOverdue == true ? 1.2 : 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => CorrespondenceLetterDetailBottomSheet.show(context, letter, _today),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Số hiệu, Chiều văn bản (Đến/Đi), Due status
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Direction Icon Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isIncoming ? const Color(0xFFEFF6FF) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIncoming ? Icons.move_to_inbox_rounded : Icons.send_rounded,
                          size: 12,
                          color: isIncoming ? const Color(0xFF2563EB) : const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIncoming ? 'correspondence.list.direction_in'.tr() : 'correspondence.list.direction_out'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isIncoming ? const Color(0xFF2563EB) : const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Số hiệu
                  Expanded(
                    child: Text(
                      letter.displayNo,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),

                  // Due badge
                  if (due != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: due.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        due.text,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: due.color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),

              // Trích yếu (Subject)
              Text(
                letter.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),

              // Gửi / Nhận hint
              if (partyText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  partyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),

              const Divider(height: 1, thickness: 0.6, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Step / Assignee and Action Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'correspondence.tracking.step'.tr(args: {'stage': letter.stageLabel}),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        if (letter.authorName != null && letter.authorName!.isNotEmpty)
                          Text(
                            letter.authorName!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),

                  // Nút Đôn đốc
                  if (canRemind)
                    OutlinedButton.icon(
                      onPressed: () => _showRemindDialog(letter),
                      icon: const Icon(Icons.notifications_active_outlined, size: 14),
                      label: Text('correspondence.tracking.remind'.tr()),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        backgroundColor: const Color(0xFFFFFBEB),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'correspondence.tracking.empty_all'.tr();
    if (_currentFilter == 'overdue') {
      message = 'correspondence.tracking.empty_overdue'.tr();
    } else if (_currentFilter == 'soon') {
      message = 'correspondence.tracking.empty_soon'.tr();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 32,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'correspondence.tracking.empty_hint'.tr(),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
