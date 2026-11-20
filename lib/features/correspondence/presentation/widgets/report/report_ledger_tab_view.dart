import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../domain/repositories/i_correspondence_repository.dart';
import '../../../data/repositories/correspondence_repository_impl.dart';
import '../correspondence_letter_card.dart';
import '../correspondence_letter_detail_bottom_sheet.dart';
import '../../../utils/correspondence_register_exporter.dart';

/// Tab hiển thị "Sổ công văn đến" hoặc "Sổ công văn đi" theo năm (matching LedgerView 1:1)
class ReportLedgerTabView extends StatefulWidget {
  final String direction; // 'incoming' | 'outgoing'
  final int year;
  final String today;

  const ReportLedgerTabView({
    super.key,
    required this.direction,
    required this.year,
    required this.today,
  });

  @override
  State<ReportLedgerTabView> createState() => _ReportLedgerTabViewState();
}

class _ReportLedgerTabViewState extends State<ReportLedgerTabView> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<LetterSummary> _letters = [];

  String _selectedMonth = ''; // '' = Tất cả các tháng
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ReportLedgerTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction || oldWidget.year != widget.year) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.getLedger(widget.direction, widget.year);
      if (!mounted) return;
      setState(() {
        _letters = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được sổ theo dõi công văn. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  List<LetterSummary> _getFilteredLetters() {
    return _letters.where((letter) {
      // 1. Lọc theo tháng
      if (_selectedMonth.isNotEmpty) {
        final date = (widget.direction == 'outgoing' &&
                letter.publishedOn != null &&
                letter.publishedOn!.isNotEmpty)
            ? letter.publishedOn!
            : letter.receivedOn;
        final targetPrefix = '${widget.year}-$_selectedMonth';
        if (!date.startsWith(targetPrefix)) {
          return false;
        }
      }

      // 2. Lọc theo từ khóa tìm kiếm
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchSubject = letter.subject.toLowerCase().contains(q);
        final matchNo = letter.displayNo.toLowerCase().contains(q) ||
            letter.incomingNo.toLowerCase().contains(q) ||
            (letter.outgoingNo != null && letter.outgoingNo!.toLowerCase().contains(q));
        final matchOrg = letter.senderOrg.toLowerCase().contains(q);
        final matchRecipient = (letter.recipient ?? '').toLowerCase().contains(q);
        if (!matchSubject && !matchNo && !matchOrg && !matchRecipient) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _exportExcel(List<LetterSummary> filtered) async {
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có văn bản nào để xuất sổ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang chuẩn bị xuất tệp Excel...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final count = await CorrespondenceRegisterExporter.exportRegisterExcel(
        direction: widget.direction,
        letters: filtered,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất sổ theo dõi: $count văn bản.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không xuất được sổ: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
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

    final filtered = _getFilteredLetters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter toolbar
        Row(
          children: [
            // Month Dropdown
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedMonth = val ?? '';
                    });
                  },
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tất cả các tháng')),
                    ...List.generate(12, (index) {
                      final m = (index + 1).toString().padLeft(2, '0');
                      return DropdownMenuItem(value: m, child: Text('Tháng ${index + 1}'));
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Export Excel Button
            InkWell(
              onTap: () => _exportExcel(filtered),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.assignment_outlined, size: 15, color: Color(0xFF475569)),
                    SizedBox(width: 5),
                    Text(
                      'Xuất Excel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search Input
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm theo số, trích yếu, cơ quan...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      child: const Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Letters List
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'Không có công văn nào trong sổ theo dõi.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final letter = filtered[index];
              return CorrespondenceLetterCard(
                letter: letter,
                today: widget.today,
                onTap: () {
                  CorrespondenceLetterDetailBottomSheet.show(
                    context,
                    letter,
                    widget.today,
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
