import 'package:flutter/material.dart';
import '../../data/repositories/correspondence_repository_impl.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../widgets/correspondence_kpi_cards.dart';
import '../widgets/correspondence_stepper_flow_card.dart';
import '../widgets/correspondence_urgent_letters_view.dart';
import '../widgets/correspondence_outgoing_dialog.dart';
import '../widgets/correspondence_intake_dialog.dart';
import 'correspondence_mine_screen.dart';
import 'correspondence_incoming_screen.dart';
import 'correspondence_outgoing_screen.dart';
import 'correspondence_archive_screen.dart';

class CorrespondenceOverviewScreen extends StatefulWidget {
  const CorrespondenceOverviewScreen({super.key});

  @override
  State<CorrespondenceOverviewScreen> createState() => _CorrespondenceOverviewScreenState();
}

class _CorrespondenceOverviewScreenState extends State<CorrespondenceOverviewScreen> {
  final ICorrespondenceRepository _repository = CorrespondenceRepositoryImpl();

  bool _isLoading = true;
  String? _errorMessage;
  CorrespondenceOverview _overview = const CorrespondenceOverview();
  CorrespondenceStatus _status = const CorrespondenceStatus();
  late final String _today;

  @override
  void initState() {
    super.initState();
    _today = CorrespondenceDateUtils.localToday();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getOverview(),
        _repository.getStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _overview = results[0] as CorrespondenceOverview;
        _status = results[1] as CorrespondenceStatus;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được dữ liệu Tổng quan Văn thư. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
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
        content: Text('Tính năng "$action" đang được chuẩn bị khởi chạy trên di động.'),
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
            const Text(
              'Tổng quan Văn thư',
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
                  'Văn thư',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
            Text(
              'Đang tải tổng quan văn thư...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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

    return RefreshIndicator(
      color: const Color(0xFF0284C7),
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Buttons matching Web
            _buildTopActions(),
            const SizedBox(height: 14),

            // 1. KPI Cards (6 metrics)
            CorrespondenceKpiCards(
              overview: _overview,
              onSelectFilter: (key) {
                if (key == 'mine') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CorrespondenceMineScreen()),
                  );
                } else if (key == 'incoming') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CorrespondenceIncomingScreen()),
                  );
                } else if (key == 'outgoing') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CorrespondenceOutgoingScreen()),
                  );
                } else if (key == 'archived') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CorrespondenceArchiveScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // 2. Stepper Flow Cards (Công văn đến theo bước & Công văn đi theo bước)
            CorrespondenceStepperFlowCards(
              overview: _overview,
              onSelectStage: (direction, stage) {
                if (direction == 'incoming') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CorrespondenceIncomingScreen(initialStage: stage)),
                  );
                } else if (direction == 'outgoing') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CorrespondenceOutgoingScreen(initialStage: stage)),
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // 3. Urgent Letters Table/List (Cần xử lý gấp)
            CorrespondenceUrgentLettersView(
              letters: _overview.urgent,
              today: _today,
            ),
            const SizedBox(height: 24),
          ],
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
          // Soạn công văn đi (Outline Button)
          if (canCreateOutgoing) ...[
            OutlinedButton.icon(
              onPressed: () => _onActionTap('Soạn công văn đi'),
              icon: const Icon(Icons.edit_document, size: 16, color: Color(0xFF0284C7)),
              label: const Text(
                'Soạn công văn đi',
                style: TextStyle(
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
              label: const Text(
                'Tiếp nhận công văn đến',
                style: TextStyle(
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
}
