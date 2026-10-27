import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/hrm_leave_balance_models.dart';

class LeaveAdjustmentCard extends StatelessWidget {
  final HrmLeaveTransactionItem tx;
  final String Function(DateTime) formatDateTime;

  const LeaveAdjustmentCard({
    super.key,
    required this.tx,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final isReversal = tx.safeTransactionType.toUpperCase() == 'REVERSAL' || tx.isReversed;
    final isNegative = tx.safeDaysChanged < 0;
    final isPositive = tx.safeDaysChanged > 0;
    final reasonText = (tx.reason ?? tx.note ?? '').trim();
    final actorName = tx.actorLabel ?? tx.createdByName ?? 'leave.actor.system'.tr();
    final actorEmail = tx.actorEmail?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Employee info on left, Badge & Days changed on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    tx.employeeInitials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.safeEmployeeName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${tx.safeEmployeeCode}${tx.department != null && tx.department!.isNotEmpty ? ' · ${tx.department}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isReversal ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isReversal ? const Color(0xFFDDD6FE) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        isReversal ? 'leave.adj.reversal'.tr() : 'leave.adj.adjustment'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isReversal ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'leave.days_changed'.tr(args: {'days': tx.formattedDaysChanged}),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isNegative
                            ? const Color(0xFFDC2626)
                            : (isPositive ? const Color(0xFF059669) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Compact Strip (Time · Năm · Còn lại sau)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    formatDateTime(tx.safeCreatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (tx.balanceYear != null) ...[
                    const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text(
                      'leave.year_label'.tr(args: {'year': tx.balanceYear}),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'leave.adj.balance_after'.tr(),
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'leave.days_changed'.tr(args: {'days': tx.formattedBalanceAfter}),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Row 3: Lý do (Reason)
            if (reasonText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                    children: [
                      TextSpan(
                        text: 'leave.adj.reason'.tr(),
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                      TextSpan(text: reasonText),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 5),

            // Row 4: Người thực hiện
            Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  'leave.adj.performed_by'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Expanded(
                  child: Text(
                    actorEmail != null && actorEmail.isNotEmpty
                        ? '$actorName ($actorEmail)'
                        : actorName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LeaveAdjustmentsView extends StatelessWidget {
  final List<HrmLeaveTransactionItem> adjustments;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final int selectedYear;
  final String selectedType;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(int) onYearChanged;
  final void Function(String) onTypeChanged;
  final VoidCallback onResetFilter;
  final String Function(DateTime) formatDateTime;

  const LeaveAdjustmentsView({
    super.key,
    required this.adjustments,
    required this.searchCtrl,
    required this.searchQuery,
    required this.selectedYear,
    required this.selectedType,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onYearChanged,
    required this.onTypeChanged,
    required this.onResetFilter,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Header Banner matching Web
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'leave.adj.title'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'leave.adj.subtitle'.tr(),
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'leave.adj.search_hint'.tr(),
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: onClearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Row: Year & Type Dropdowns matching Web
              Row(
                children: [
                  // Year Filter Dropdown
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          menuMaxHeight: 280,
                          borderRadius: BorderRadius.circular(10),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: [
                            DropdownMenuItem<int>(
                              value: 0,
                              child: Text('leave.adj.all_years'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            for (int y = DateTime.now().year + 1; y >= DateTime.now().year - 3; y--)
                              DropdownMenuItem<int>(
                                value: y,
                                child: Text('leave.year_label'.tr(args: {'year': y}), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) onYearChanged(val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type Filter Dropdown
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          menuMaxHeight: 280,
                          borderRadius: BorderRadius.circular(10),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          items: [
                            DropdownMenuItem(value: 'ALL', child: Text('leave.adj.all_types'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'ADJUSTMENT', child: Text('leave.adj.adjustment'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'REVERSAL', child: Text('leave.adj.reversal'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) onTypeChanged(val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Result count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Text(
                'leave.adj.count'.tr(args: {'count': adjustments.length}),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const Spacer(),
              if (searchQuery.isNotEmpty || selectedType != 'ALL' || selectedYear != 0)
                InkWell(
                  onTap: onResetFilter,
                  child: Text(
                    'leave.filter.reset'.tr(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List or Empty
        if (adjustments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text(
                  'leave.adj.empty_title'.tr(),
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (searchQuery.isNotEmpty || selectedType != 'ALL') ...[
                  const SizedBox(height: 6),
                  Text(
                    'leave.adj.empty_desc'.tr(),
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ],
            ),
          )
        else
          ...adjustments.map((tx) => LeaveAdjustmentCard(tx: tx, formatDateTime: formatDateTime)),
      ],
    );
  }
}
