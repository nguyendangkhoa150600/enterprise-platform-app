import 'package:flutter/material.dart';
import '../../../models/procedure_models.dart';
import '../../../theme/colors.dart';
import '../../../core/i18n/app_i18n.dart';

// Thanh tìm kiếm và bộ lọc trạng thái (Đồng bộ 100% với Web)
class ProcedureSearchFilterControls extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final String selectedSlaFilter;
  final ValueChanged<String> onSlaFilterChanged;
  final String selectedSourceFilter;
  final ValueChanged<String> onSourceFilterChanged;
  final List<ProcedureInstance> instances;

  const ProcedureSearchFilterControls({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.selectedSlaFilter,
    required this.onSlaFilterChanged,
    required this.selectedSourceFilter,
    required this.onSourceFilterChanged,
    required this.instances,
  });

  @override
  Widget build(BuildContext context) {
    final runningCount = instances.where((i) => i.isRunning).length;
    final slaRiskCount = instances.where((i) =>
        i.isSlaWarning ||
        i.isSlaBreached ||
        i.slaStatus == 'AT_RISK' ||
        i.slaStatus == 'BREACHED').length;
    final completedCount = instances.where((i) => i.isCompleted).length;
    final rejectedCount = instances.where((i) => i.status == 'rejected').length;
    final cancelledCount = instances.where((i) => i.status == 'cancelled').length;
    final reversedCount = instances.where((i) => i.status == 'reversed').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dải tabs trạng thái ngang giống Web
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusTab('procedure.status.running'.tr(), 'RUNNING', runningCount),
                _buildStatusTab('procedure.status.sla_risk'.tr(), 'SLA_RISK', slaRiskCount, isSlaRisk: true),
                _buildStatusTab('procedure.status.completed'.tr(), 'COMPLETED', completedCount),
                _buildStatusTab('procedure.status.rejected'.tr(), 'REJECTED', rejectedCount),
                _buildStatusTab('procedure.status.cancelled'.tr(), 'CANCELLED', cancelledCount),
                _buildStatusTab('procedure.status.reversed'.tr(), 'REVERSED', reversedCount),
                _buildStatusTab('procedure.status.all'.tr(), 'ALL', instances.length),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Ô tìm kiếm
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'procedure.filter.search_hint'.tr(),
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Dropdowns: SLA & Nguồn
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: _getSlaLabel(selectedSlaFilter),
                  value: selectedSlaFilter,
                  items: [
                    DropdownMenuItem(value: 'ALL', child: Text('procedure.filter.sla_all'.tr(), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'ON_TIME', child: Text('procedure.filter.sla_on_time'.tr(), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'AT_RISK', child: Text('procedure.filter.sla_at_risk'.tr(), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'BREACHED', child: Text('procedure.filter.sla_breached'.tr(), style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) onSlaFilterChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  label: _getSourceLabel(selectedSourceFilter),
                  value: selectedSourceFilter,
                  items: [
                    DropdownMenuItem(value: 'ALL', child: Text('procedure.filter.source_all'.tr(), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'MANUAL', child: Text('procedure.filter.source_manual'.tr(), style: const TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'SYSTEM', child: Text('procedure.filter.source_system'.tr(), style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) onSourceFilterChanged(val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String value, int count, {bool isSlaRisk = false}) {
    final isSelected = selectedStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onStatusFilterChanged(value),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFBBF24) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF59E0B)
                        : (isSlaRisk ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF78350F)
                          : (isSlaRisk ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
          items: items,
          onChanged: onChanged,
          selectedItemBuilder: (ctx) => items.map((item) {
            return Row(
              children: [
                const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getSlaLabel(String val) {
    switch (val) {
      case 'ON_TIME':
        return 'procedure.filter.sla_on_time'.tr();
      case 'AT_RISK':
        return 'procedure.filter.sla_at_risk'.tr();
      case 'BREACHED':
        return 'procedure.filter.sla_breached'.tr();
      default:
        return 'procedure.filter.sla_all'.tr();
    }
  }

  String _getSourceLabel(String val) {
    switch (val) {
      case 'MANUAL':
        return 'procedure.filter.source_manual'.tr();
      case 'SYSTEM':
        return 'procedure.filter.source_system'.tr();
      default:
        return 'procedure.filter.source_all'.tr();
    }
  }
}

// Thẻ hồ sơ quy trình trong danh sách
class ProcedureInstanceCard extends StatelessWidget {
  final ProcedureInstance item;
  final VoidCallback onTap;

  const ProcedureInstanceCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusBg = const Color(0xFFEFF6FF);
    Color statusColor = const Color(0xFF2563EB);
    String statusText = 'procedure.status.running'.tr();

    if (item.isCompleted) {
      statusBg = const Color(0xFFECFDF5);
      statusColor = const Color(0xFF059669);
      statusText = 'procedure.status.completed'.tr();
    } else if (item.isRejected) {
      statusBg = const Color(0xFFFEF2F2);
      statusColor = const Color(0xFFDC2626);
      statusText = 'procedure.status.rejected'.tr();
    } else if (item.isCancelled) {
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF64748B);
      statusText = 'procedure.card.status_cancelled'.tr();
    }

    Color slaBg = const Color(0xFFECFDF5);
    Color slaColor = const Color(0xFF059669);
    String slaText = item.slaCountdownText ?? 'procedure.sla.on_time'.tr();

    switch (item.slaState) {
      case ProcedureSlaState.none:
        slaBg = const Color(0xFFF1F5F9);
        slaColor = const Color(0xFF94A3B8);
        slaText = '—';
        break;
      case ProcedureSlaState.ok:
        slaBg = const Color(0xFFECFDF5);
        slaColor = const Color(0xFF059669);
        slaText = item.slaCountdownText ?? 'procedure.sla.on_time'.tr();
        break;
      case ProcedureSlaState.warning:
        slaBg = const Color(0xFFFFFBEB);
        slaColor = const Color(0xFFD97706);
        slaText = item.slaCountdownText ?? 'procedure.sla.warning'.tr();
        break;
      case ProcedureSlaState.breached:
        slaBg = const Color(0xFFFEF2F2);
        slaColor = const Color(0xFFDC2626);
        slaText = item.slaCountdownText ?? 'procedure.sla.breached'.tr();
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isActionable ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
            width: item.isActionable ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code + Status + SLA
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: AppColors.slate700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: slaBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: slaColor),
                      const SizedBox(width: 4),
                      Text(
                        slaText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: slaColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Current Step & Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.linear_scale_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.currentStepLabel,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Definition & Creator
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 13, color: AppColors.slate400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.definitionName,
                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.person_outline, size: 13, color: AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  item.submitterDisplayName,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),

            if (item.isActionable) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 3),
                        Text(
                          'procedure.card.awaiting_you'.tr(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.touch_app_outlined, size: 14),
                    label: Text('procedure.card.process_now'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Trạng thái rỗng khi không có kết quả tìm kiếm hoặc danh sách trống
class ProcedureEmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;

  const ProcedureEmptyState({
    super.key,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.slate300),
          const SizedBox(height: 12),
          Text(
            title ?? 'procedure.empty.title'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'procedure.empty.subtitle'.tr(),
            style: const TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}
