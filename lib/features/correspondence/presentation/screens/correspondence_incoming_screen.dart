import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/correspondence_incoming_filter_bar.dart';
import '../widgets/correspondence_letter_card.dart';
import '../widgets/correspondence_letter_detail_bottom_sheet.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';
import '../../utils/correspondence_register_exporter.dart';
import 'correspondence_tracking_screen.dart';
import '../utils/correspondence_error.dart';

/// Screen "Công văn đến" (Incoming Letters) matching Savina ERP Web 1:1
class CorrespondenceIncomingScreen extends StatefulWidget {
  final String? initialStage;

  const CorrespondenceIncomingScreen({
    super.key,
    this.initialStage,
  });

  @override
  State<CorrespondenceIncomingScreen> createState() => _CorrespondenceIncomingScreenState();
}

class _CorrespondenceIncomingScreenState extends State<CorrespondenceIncomingScreen>
    with SingleTickerProviderStateMixin {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final AnimationController _floatingController;
  late final Animation<Offset> _headerSlideAnimation;

  bool _isLoading = true;
  String? _errorMessage;
  List<LetterSummary> _allLetters = [];
  CorrespondenceConfig _config = const CorrespondenceConfig();
  CorrespondenceStatus _status = const CorrespondenceStatus();

  String _selectedStage = '';
  String _selectedMonthKey = 'this_month';
  String? _selectedKind;
  String? _selectedBookId;
  String _searchQuery = '';
  Timer? _debounceTimer;
  late final String _today;

  @override
  void initState() {
    super.initState();
    _today = CorrespondenceDateUtils.localToday();
    if (widget.initialStage != null && widget.initialStage!.isNotEmpty) {
      _selectedStage = widget.initialStage!;
    }

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1.0,
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeOutCubic,
    ));

    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _floatingController.dispose();
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
        _repository.getLetters(
          box: 'incoming',
          search: _searchQuery,
          stage: (_selectedStage.isNotEmpty && _selectedStage != 'overdue') ? _selectedStage : null,
          kind: _selectedKind,
          bookId: _selectedBookId,
        ),
        _repository.getConfig(),
        _repository.getStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _allLetters = results[0] as List<LetterSummary>;
        _config = results[1] as CorrespondenceConfig;
        _status = results[2] as CorrespondenceStatus;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'correspondence.list.incoming_load_failed'.tr();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadData();
    });
  }

  void _onStageSelected(String stage) {
    setState(() {
      _selectedStage = stage;
    });
    // Auto-scroll to top and restore floating bar
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _floatingController.forward();
    _loadData();
  }

  void _onMonthSelected(String monthKey) {
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

  Future<void> _onExport() async {
    final filtered = _getFilteredLetters();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.list.export_empty'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'correspondence.list.export_preparing_incoming'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 15),
      ),
    );

    try {
      final count = await CorrespondenceRegisterExporter.exportRegisterExcel(
        direction: 'incoming',
        letters: filtered,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.list.export_done'.tr(args: {'count': count})),
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
          content: Text('correspondence.list.export_failed'.tr(args: {'error': correspondenceErrorMessage(e, 'common.error_generic'.tr())})),
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
      if (_selectedStage == 'overdue') {
        if (!CorrespondenceDateUtils.isOverdue(letter.dueOn, letter.stage, _today)) {
          return false;
        }
      } else if (_selectedStage.isNotEmpty && letter.stage != _selectedStage) {
        return false;
      }
      // 2. Kind filter
      if (_selectedKind != null && _selectedKind!.isNotEmpty && letter.kind != _selectedKind) {
        return false;
      }
      // 3. Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSubject = letter.subject.toLowerCase().contains(q);
        final matchNo = letter.displayNo.toLowerCase().contains(q) ||
            letter.incomingNo.toLowerCase().contains(q);
        final matchOrg = letter.senderOrg.toLowerCase().contains(q);
        if (!matchSubject && !matchNo && !matchOrg) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canRegister = _status.canRegister;
    final canCreateOutgoing = _status.canCreateOutgoing;
    final kinds = _config.catalog.where((c) => c.kind == 'letter_type').toList();
    final books = _config.books.where((b) => b.direction == 'incoming').toList();
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
            Text(
              'correspondence.list.incoming'.tr(),
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
                  'correspondence.list.breadcrumb_registers'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Soạn công văn đi button
          if (canCreateOutgoing)
            IconButton(
              icon: const Icon(Icons.edit_document, size: 20, color: Color(0xFF0284C7)),
              tooltip: 'correspondence.list.compose_outgoing'.tr(),
              onPressed: () => CorrespondenceOutgoingDialog.show(context, onCreated: _loadData),
            ),
          // Tiếp nhận công văn đến button
          if (canRegister)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Color(0xFF0284C7)),
              tooltip: 'correspondence.list.register_incoming'.tr(),
              onPressed: () => CorrespondenceIntakeDialog.show(context, onCreated: _loadData),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(kinds, books, filteredLetters),
    );
  }

  Widget _buildBody(
    List<CatalogItem> kinds,
    List<RegisterBookModel> books,
    List<LetterSummary> filteredLetters,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
            const SizedBox(height: 14),
            Text(
              'correspondence.list.incoming_loading'.tr(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
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

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        children: [
          // List of Letters (Base Layer)
          RefreshIndicator(
            edgeOffset: 155,
            color: const Color(0xFF0284C7),
            onRefresh: _loadData,
            child: filteredLetters.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 150, 14, 30),
                    itemCount: filteredLetters.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final letter = filteredLetters[index];
                      return CorrespondenceLetterCard(
                        letter: letter,
                        today: _today,
                        onTap: () {
                          CorrespondenceLetterDetailBottomSheet.show(context, letter, _today);
                        },
                      );
                    },
                  ),
          ),

          // Collapsible Floating Filter Header (Top Layer)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CorrespondenceIncomingFilterBar(
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
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 32,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _selectedStage == 'overdue'
                    ? 'correspondence.list.incoming_empty_overdue'.tr()
                    : 'correspondence.list.incoming_empty'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedStage == 'overdue'
                    ? 'correspondence.list.incoming_empty_overdue_hint'.tr()
                    : 'correspondence.list.incoming_empty_hint'.tr(),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              if (_selectedStage == 'overdue') ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CorrespondenceTrackingScreen(initialFilter: 'overdue'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text('correspondence.list.view_all_overdue'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (_selectedStage.isNotEmpty || _searchQuery.isNotEmpty || _selectedKind != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedStage = '';
                      _selectedKind = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: Text('correspondence.list.clear_filters'.tr()),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    foregroundColor: const Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
