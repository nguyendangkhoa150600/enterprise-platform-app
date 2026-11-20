import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/correspondence_outgoing_filter_bar.dart';
import '../widgets/correspondence_letter_card.dart';
import '../widgets/correspondence_letter_detail_bottom_sheet.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';
import '../../utils/correspondence_register_exporter.dart';

/// Màn hình "Công văn đi" (Outgoing Letters) đồng bộ 1:1 với Savina ERP Web
class CorrespondenceOutgoingScreen extends StatefulWidget {
  final String? initialStage;

  const CorrespondenceOutgoingScreen({
    super.key,
    this.initialStage,
  });

  @override
  State<CorrespondenceOutgoingScreen> createState() => _CorrespondenceOutgoingScreenState();
}

class _CorrespondenceOutgoingScreenState extends State<CorrespondenceOutgoingScreen>
    with SingleTickerProviderStateMixin {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _floatingController;
  late Animation<Offset> _floatingOffsetAnimation;
  Timer? _debounceTimer;

  bool _isLoading = true;
  String? _errorMessage;

  List<LetterSummary> _allLetters = [];
  CorrespondenceStatus _status = const CorrespondenceStatus();
  CorrespondenceConfig _config = const CorrespondenceConfig();
  String _today = '';

  // Bộ lọc
  late String _selectedStage;
  String _selectedMonthKey = 'this_month';
  String? _selectedKind;
  String? _selectedBookId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage ?? '';

    // Khởi tạo Floating Collapsible Header (Rule 5.4)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1.0,
    );

    _floatingOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeOutCubic,
    ));

    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.offset <= 20) {
        if (!_floatingController.isCompleted) {
          _floatingController.forward();
        }
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      _today = '$y-$m-$d';

      final results = await Future.wait([
        _repository.getStatus(),
        _repository.getConfig(),
        _repository.getLetters(
          box: 'outgoing',
          search: _searchQuery,
          stage: _selectedStage.isNotEmpty ? _selectedStage : null,
          kind: _selectedKind,
          month: _selectedMonthKey != 'all' ? _selectedMonthKey : null,
          bookId: _selectedBookId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _status = results[0] as CorrespondenceStatus;
        _config = results[1] as CorrespondenceConfig;
        _allLetters = results[2] as List<LetterSummary>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được danh sách công văn đi. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  void _onStageSelected(String stage) {
    if (_selectedStage == stage) return;
    setState(() {
      _selectedStage = stage;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _floatingController.forward();
    _loadData();
  }

  void _onMonthSelected(String monthKey) {
    if (_selectedMonthKey == monthKey) return;
    setState(() {
      _selectedMonthKey = monthKey;
    });
    _loadData();
  }

  void _onKindSelected(String? kind) {
    setState(() {
      _selectedKind = kind;
    });
    _loadData();
  }

  void _onBookSelected(String? bookId) {
    setState(() {
      _selectedBookId = bookId;
    });
    _loadData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadData();
    });
  }

  Future<void> _onExport() async {
    final filtered = _getFilteredLetters();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có văn bản nào để xuất sổ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đang chuẩn bị trích xuất sổ đăng ký công văn đi...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final count = await CorrespondenceRegisterExporter.exportRegisterExcel(
        direction: 'outgoing',
        letters: filtered,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất sổ đăng ký: $count văn bản.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không xuất được sổ đăng ký: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleScrollNotification(UserScrollNotification notification) {
    if (_searchFocusNode.hasFocus) return; // Focus-Guard (Rule 5.4)

    if (_scrollController.hasClients && _scrollController.offset <= 20) {
      if (!_floatingController.isCompleted) {
        _floatingController.forward();
      }
      return;
    }

    if (notification.direction == ScrollDirection.reverse) {
      if (!_floatingController.isDismissed) {
        _floatingController.reverse();
      }
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_floatingController.isCompleted) {
        _floatingController.forward();
      }
    }
  }

  List<LetterSummary> _getFilteredLetters() {
    return _allLetters.where((letter) {
      // 1. Stage filter
      if (_selectedStage.isNotEmpty && letter.stage != _selectedStage) {
        return false;
      }
      // 2. Kind filter
      if (_selectedKind != null && _selectedKind!.isNotEmpty && letter.kind != _selectedKind) {
        return false;
      }
      // 3. Search filter: số, trích yếu, nơi nhận, phòng soạn
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSubject = letter.subject.toLowerCase().contains(q);
        final matchNo = letter.displayNo.toLowerCase().contains(q) ||
            (letter.outgoingNo != null && letter.outgoingNo!.toLowerCase().contains(q));
        final matchRecipient = (letter.recipient ?? '').toLowerCase().contains(q);
        final matchSender = letter.outgoingSenderText.toLowerCase().contains(q);
        if (!matchSubject && !matchNo && !matchRecipient && !matchSender) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canCreateOutgoing = _status.canCreateOutgoing || _status.isTenantAdmin;
    final canRegister = _status.canRegister || _status.isTenantAdmin;
    final kinds = _config.catalog.where((c) => c.kind == 'letter_type').toList();
    final books = _config.books.where((b) => b.direction == 'outgoing').toList();
    final filteredLetters = _getFilteredLetters();

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
            const Text(
              'Công văn đi',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Row(
              children: const [
                Icon(Icons.home_outlined, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text(
                  'Văn thư > Sổ công văn',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Nút Soạn công văn đi (Primary)
          if (canCreateOutgoing)
            IconButton(
              icon: const Icon(Icons.edit_document, color: Color(0xFF0284C7)),
              tooltip: 'Soạn công văn đi',
              onPressed: () => CorrespondenceOutgoingDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          // Nút Tiếp nhận công văn đến
          if (canRegister)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669)),
              tooltip: 'Tiếp nhận công văn đến',
              onPressed: () => CorrespondenceIntakeDialog.show(
                context,
                onCreated: _loadData,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Lớp nền: Danh sách công văn đi
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              _handleScrollNotification(notification);
              return false;
            },
            child: RefreshIndicator(
              color: const Color(0xFF0284C7),
              edgeOffset: 145, // Tránh che khuất bởi floating bar
              onRefresh: _loadData,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : filteredLetters.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 155, 14, 28),
                              itemCount: filteredLetters.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (ctx, index) {
                                final letter = filteredLetters[index];
                                return CorrespondenceLetterCard(
                                  letter: letter,
                                  today: _today,
                                  onTap: () {
                                    CorrespondenceLetterDetailBottomSheet.show(
                                      context,
                                      letter,
                                      _today,
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ),

          // Lớp nổi: Collapsible Floating Header (Rule 5.4)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: SlideTransition(
                position: _floatingOffsetAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CorrespondenceOutgoingFilterBar(
                    selectedStage: _selectedStage,
                    onStageChanged: _onStageSelected,
                    selectedMonthKey: _selectedMonthKey,
                    onMonthChanged: _onMonthSelected,
                    selectedKind: _selectedKind,
                    onKindChanged: _onKindSelected,
                    selectedBookId: _selectedBookId,
                    onBookChanged: _onBookSelected,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onSearchChanged: _onSearchChanged,
                    onExport: _onExport,
                    kinds: kinds,
                    books: books,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreateOutgoing
          ? FloatingActionButton.extended(
              onPressed: () => CorrespondenceOutgoingDialog.show(
                context,
                onCreated: _loadData,
              ),
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_document, size: 18),
              label: const Text(
                'Soạn công văn đi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_outlined,
                  size: 34,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chưa có công văn đi nào phù hợp với bộ lọc.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thử thay đổi bước xử lý, kỳ thời gian hoặc từ khoá tìm kiếm.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Đã có lỗi xảy ra',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
