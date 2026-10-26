import 'package:flutter/material.dart';
import '../../../models/hrm_leave_balance_models.dart';
import '../../../services/hrm_service.dart';

void showLeaveBalanceDetailSheet(
  BuildContext context, {
  required HrmLeaveBalanceItem balance,
  required HrmService hrmService,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LeaveBalanceDetailSheet(
      balance: balance,
      hrmService: hrmService,
    ),
  );
}

class LeaveBalanceDetailSheet extends StatefulWidget {
  final HrmLeaveBalanceItem balance;
  final HrmService hrmService;

  const LeaveBalanceDetailSheet({
    super.key,
    required this.balance,
    required this.hrmService,
  });

  @override
  State<LeaveBalanceDetailSheet> createState() => _LeaveBalanceDetailSheetState();
}

class _LeaveBalanceDetailSheetState extends State<LeaveBalanceDetailSheet> {
  bool _isLoading = true;
  List<HrmLeaveTransactionItem> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final raw = await widget.hrmService.getLeaveTransactions(
        employeeId: widget.balance.employeeId,
        year: widget.balance.year,
        leaveTypeId: widget.balance.leaveTypeId,
      );
      if (mounted) {
        setState(() {
          _transactions = raw.map((e) => HrmLeaveTransactionItem.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.employeeName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${b.employeeCode} · ${b.department ?? 'Chưa có phòng ban'} · Năm ${b.year}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Balance Overview Strip
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderMetric('Định mức', _formatNumber(b.entitlement)),
                _buildHeaderMetric('Thâm niên', '+${_formatNumber(b.seniorityDays)}', color: const Color(0xFF059669)),
                _buildHeaderMetric('Chuyển tiếp', _formatNumber(b.carryover)),
                _buildHeaderMetric('Đã dùng', _formatNumber(b.used), color: const Color(0xFFDC2626)),
                _buildHeaderMetric('Còn lại', '${_formatNumber(b.remaining)} ngày',
                    color: b.remaining > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), isBold: true),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Transactions title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                const Text(
                  'Lịch sử giao dịch quỹ phép',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Text(
                  '${_transactions.length} giao dịch',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD9AB00)))
                : _transactions.isEmpty
                    ? const Center(
                        child: Text('Chưa có phát sinh giao dịch nào', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final tx = _transactions[idx];
                          final isPositive = tx.isPositive;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  child: Icon(
                                    isPositive ? Icons.add : Icons.remove,
                                    size: 14,
                                    color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.typeLabel,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      if (tx.reason != null && tx.reason!.isNotEmpty)
                                        Text(
                                          tx.reason!,
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.safeCreatedAt.day.toString().padLeft(2, '0')}/${tx.safeCreatedAt.month.toString().padLeft(2, '0')}/${tx.safeCreatedAt.year}'
                                        '${tx.createdByName != null ? ' · ${tx.createdByName}' : ''}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isPositive ? '+' : ''}${_formatNumber(tx.safeAmount)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    Text(
                                      'Dư: ${_formatNumber(tx.safeBalanceAfter)}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value, {Color? color, bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
