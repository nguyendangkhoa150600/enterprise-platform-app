import 'package:flutter/material.dart';
import '../../../../../models/hrm_models.dart';
import '../../../../../models/hrm_personnel_decision_model.dart';
import '../../../../../services/hrm_service.dart';
import '../widgets/personnel_decision_card.dart';
import '../widgets/personnel_decision_detail_sheet.dart';
import '../widgets/personnel_decision_dialog.dart';
import '../../../../../utils/user_resolver.dart';
import '../../../../../core/i18n/app_i18n.dart';

class HrmPersonnelDecisionsView extends StatefulWidget {
  final List<HrmEmployeeItem> employees;
  final List<HrmPositionItem> positions;

  const HrmPersonnelDecisionsView({
    super.key,
    required this.employees,
    required this.positions,
  });

  @override
  State<HrmPersonnelDecisionsView> createState() => _HrmPersonnelDecisionsViewState();
}

class _HrmPersonnelDecisionsViewState extends State<HrmPersonnelDecisionsView> {
  final HrmService _service = HrmService();

  List<HrmPersonnelDecision> _decisions = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _unitFilter = 'ALL';
  String _typeFilter = 'ALL';
  String _statusFilter = 'ALL';

  Map<String, String> get _typeFilterLabels => {
    'ALL': 'hrm_decisions.type_all'.tr(),
    'APPOINT': 'hrm_decisions.type_appoint'.tr(),
    'PROMOTE': 'hrm_decisions.type_promote'.tr(),
    'TRANSFER': 'hrm_decisions.type_transfer'.tr(),
    'CONCURRENT': 'hrm_decisions.type_concurrent'.tr(),
    'DISMISS': 'hrm_decisions.type_dismiss'.tr(),
    'REVOKE': 'hrm_decisions.type_revoke'.tr(),
  };

  Map<String, String> get _statusFilterLabels => {
    'ALL': 'hrm_decisions.status_all'.tr(),
    'DRAFT': 'hrm_decisions.status_draft'.tr(),
    'APPROVED': 'hrm_decisions.status_approved'.tr(),
    'APPLY_PENDING': 'hrm_decisions.status_apply_pending'.tr(),
    'APPLIED': 'hrm_decisions.status_applied'.tr(),
    'REJECTED': 'common.reject'.tr(),
    'CANCELLED': 'hrm_decisions.status_cancelled'.tr(),
  };

  @override
  void initState() {
    super.initState();
    UserResolver.ensureLoaded();
    _loadDecisions();
  }

  Future<void> _loadDecisions({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getPersonnelDecisions(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _decisions = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- STATS COMPUTATION (1:1 Web) ---
  int get _totalCount => _decisions.length;
  int get _openCount => _decisions.where((d) => d.isOpen).length;
  int get _appliedCount => _decisions.where((d) => d.status == 'APPLIED').length;
  int get _closedCount => _decisions.where((d) => d.status == 'REJECTED' || d.status == 'CANCELLED').length;
  int get _unitCount => _decisions.map((d) => d.unitName).toSet().length;

  List<String> get _allUnits {
    final s = <String>{};
    for (final d in _decisions) {
      s.add(d.unitName);
    }
    final sorted = s.toList()..sort();
    return ['ALL', ...sorted];
  }

  // --- FILTERED ROWS ---
  List<HrmPersonnelDecision> get _filteredDecisions {
    var list = _decisions;

    if (_unitFilter != 'ALL') {
      list = list.where((d) => d.unitName == _unitFilter).toList();
    }
    if (_typeFilter != 'ALL') {
      list = list.where((d) => d.decisionType == _typeFilter).toList();
    }
    if (_statusFilter != 'ALL') {
      list = list.where((d) => d.status == _statusFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) =>
        d.decisionNo.toLowerCase().contains(q) ||
        (d.employeeName ?? '').toLowerCase().contains(q) ||
        (d.employeeCode ?? '').toLowerCase().contains(q) ||
        d.reason.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }


  // --- ACTIONS ---
  void _openDetail(HrmPersonnelDecision decision) {
    PersonnelDecisionDetailSheet.show(
      context,
      decision: decision,
      onEdit: () => _openDialog(decision),
      onApprove: () => _handleApprove(decision),
      onReject: () => _handleReject(decision),
      onCancel: () => _handleCancel(decision),
      onRetry: () => _handleRetry(decision),
    );
  }

  void _openDialog([HrmPersonnelDecision? decision]) {
    PersonnelDecisionDialog.show(
      context,
      decision: decision,
      employees: widget.employees,
      positions: widget.positions,
      onSuccess: () => _loadDecisions(forceRefresh: true),
    );
  }

  Future<void> _handleApprove(HrmPersonnelDecision d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hrm_decisions.approve_title'.tr()),
        content: Text('hrm_decisions.approve_msg'.tr(args: {'no': d.decisionNo})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.close'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('hrm_decisions.approve_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.approvePersonnelDecision(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Color(0xFF059669), content: Text('hrm_decisions.approve_success'.tr())),
        );
        _loadDecisions(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('hrm_decisions.approve_error'.tr(args: {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _handleReject(HrmPersonnelDecision d) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hrm_decisions.reject_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('hrm_decisions.reject_msg'.tr(args: {'no': d.decisionNo})),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'hrm_decisions.reject_reason_hint'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.close'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: Text('common.reject'.tr()),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    try {
      await _service.rejectPersonnelDecision(d.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Color(0xFFDC2626), content: Text('hrm_decisions.reject_success'.tr())),
        );
        _loadDecisions(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('hrm_decisions.reject_error'.tr(args: {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _handleCancel(HrmPersonnelDecision d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hrm_decisions.cancel_title'.tr()),
        content: Text('hrm_decisions.cancel_msg'.tr(args: {'no': d.decisionNo})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.back'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('hrm_decisions.cancel_decision'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.cancelPersonnelDecision(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('hrm_decisions.cancel_success'.tr())),
        );
        _loadDecisions(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('hrm_decisions.cancel_error'.tr(args: {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _handleRetry(HrmPersonnelDecision d) async {
    try {
      await _service.retryApplyPersonnelDecision(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Color(0xFFD97706), content: Text('hrm_decisions.retry_sent'.tr())),
        );
        _loadDecisions(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('hrm_decisions.retry_error'.tr(args: {'error': '$e'}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Overview & "+ Tạo quyết định"
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'hrm_decisions.header_title'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'hrm_decisions.header_desc'.tr(),
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _openDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308), // Yellow/Gold matching web
                foregroundColor: const Color(0xFF451A03),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('hrm_decisions.create_decision'.tr(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. 4 KPI Overview Cards (Matching Web 1:1)
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'hrm_decisions.stat_total'.tr(),
                count: '$_totalCount',
                subtitle: 'hrm_decisions.unit_count'.tr(args: {'count': _unitCount}),
                icon: Icons.file_copy_outlined,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'hrm_decisions.stat_processing'.tr(),
                count: '$_openCount',
                subtitle: 'hrm_decisions.stat_processing_sub'.tr(),
                icon: Icons.pending_actions_outlined,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'hrm_decisions.status_applied'.tr(),
                count: '$_appliedCount',
                subtitle: 'hrm_decisions.stat_applied_sub'.tr(),
                icon: Icons.check_circle_outline,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiCard(
                title: 'hrm_decisions.stat_rejected'.tr(),
                count: '$_closedCount',
                subtitle: 'hrm_decisions.stat_rejected_sub'.tr(),
                icon: Icons.cancel_outlined,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Search field
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'hrm_decisions.search_hint'.tr(),
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 10),

              // Filters Row (Dropdowns)
              Row(
                children: [
                  // Unit filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unitFilter,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      borderRadius: BorderRadius.circular(10),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: _allUnits.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(u == 'ALL' ? 'hrm_decisions.all_units'.tr() : u, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _unitFilter = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _typeFilter,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      borderRadius: BorderRadius.circular(10),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: _typeFilterLabels.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _typeFilter = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status Filter
              DropdownButtonFormField<String>(
                value: _statusFilter,
                isExpanded: true,
                menuMaxHeight: 280,
                borderRadius: BorderRadius.circular(10),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
                items: _statusFilterLabels.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Content List (Hiển thị dạng danh sách trực tiếp)
        if (_filteredDecisions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 10),
                Text('hrm_decisions.empty'.tr(), style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDecisions.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final d = _filteredDecisions[idx];
              return PersonnelDecisionCard(
                decision: d,
                onDetail: () => _openDetail(d),
                onEdit: d.canEdit ? () => _openDialog(d) : null,
                onApprove: d.canApprove ? () => _handleApprove(d) : null,
                onReject: d.canApprove ? () => _handleReject(d) : null,
                onCancel: d.canCancel ? () => _handleCancel(d) : null,
                onRetry: d.canRetry ? () => _handleRetry(d) : null,
              );
            },
          ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.15)),
                Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
