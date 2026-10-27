import 'package:flutter/material.dart';
import '../../../models/procedure_models.dart';
import '../../../theme/colors.dart';
import '../../../core/i18n/app_i18n.dart';

// 1. Thống kê 4 thẻ trên cùng
class ProcedureTopMetrics extends StatelessWidget {
  final List<ProcedureInstance> instances;
  final List<ProcedureDefinition> definitions;

  const ProcedureTopMetrics({
    super.key,
    required this.instances,
    required this.definitions,
  });

  @override
  Widget build(BuildContext context) {
    final actionableCount = instances.where((i) => i.isActionable).length;
    final runningCount = instances.where((i) => i.isRunning).length;
    final completedCount = instances.where((i) => i.isCompleted).length;
    final publishedCount = definitions.where((d) => d.status.toLowerCase() == 'published').length;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricBox(
                title: 'procedure.overview.metric_awaiting_me'.tr(),
                value: '$actionableCount',
                icon: Icons.access_time_rounded,
                bgColor: actionableCount > 0 ? const Color(0xFFFFFBEB) : Colors.white,
                borderColor: actionableCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                iconColor: actionableCount > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                textColor: actionableCount > 0 ? const Color(0xFFB45309) : const Color(0xFF0F172A),
              ),
              const SizedBox(height: 10),
              _buildMetricBox(
                title: 'procedure.overview.metric_running'.tr(),
                value: '$runningCount',
                icon: Icons.play_circle_outline_rounded,
                bgColor: Colors.white,
                borderColor: const Color(0xFFE2E8F0),
                iconColor: const Color(0xFF2563EB),
                textColor: const Color(0xFF0F172A),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _buildMetricBox(
                title: 'procedure.overview.metric_completed'.tr(),
                value: '$completedCount',
                icon: Icons.check_circle_outline_rounded,
                bgColor: Colors.white,
                borderColor: const Color(0xFFE2E8F0),
                iconColor: const Color(0xFF059669),
                textColor: const Color(0xFF0F172A),
              ),
              const SizedBox(height: 10),
              _buildMetricBox(
                title: 'procedure.overview.metric_published'.tr(),
                value: '$publishedCount',
                icon: Icons.verified_outlined,
                bgColor: Colors.white,
                borderColor: const Color(0xFFE2E8F0),
                iconColor: const Color(0xFF6366F1),
                textColor: const Color(0xFF0F172A),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }
}

// 2. Việc cần làm
class ProcedureActionRequiredCard extends StatefulWidget {
  final List<ProcedureInstance> instances;
  final ValueChanged<ProcedureInstance> onItemTap;

  const ProcedureActionRequiredCard({
    super.key,
    required this.instances,
    required this.onItemTap,
  });

  @override
  State<ProcedureActionRequiredCard> createState() => _ProcedureActionRequiredCardState();
}

class _ProcedureActionRequiredCardState extends State<ProcedureActionRequiredCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingTasks = widget.instances.where((i) => i.isActionable).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'procedure.overview.todo_title'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.slate600,
                ),
              ),
              const Spacer(),
              if (pendingTasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'procedure.overview.todo_count'.tr(args: {'count': pendingTasks.length}),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingTasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'procedure.overview.todo_empty'.tr(),
                style: const TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
            )
          else if (pendingTasks.length <= 3)
            Column(
              children: pendingTasks.map((task) => _buildTaskItem(task)).toList(),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 6),
                  itemCount: pendingTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskItem(pendingTasks[index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(ProcedureInstance task) {
    return InkWell(
      onTap: () => widget.onItemTap(task),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.code} · ${task.currentStepOnlyName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (task.slaCountdownText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: task.isSlaBreached
                      ? const Color(0xFFFEE2E2)
                      : (task.isSlaWarning ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.isSlaBreached
                        ? const Color(0xFFFCA5A5)
                        : (task.isSlaWarning ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC)),
                  ),
                ),
                child: Text(
                  task.slaCountdownText!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: task.isSlaBreached
                        ? const Color(0xFFB91C1C)
                        : (task.isSlaWarning ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text(
                  '—',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Text(
                'procedure.overview.role_prefix'.tr(args: {'role': task.currentRole}),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

// 3. Hồ sơ theo trạng thái + SLA + Vai trò
class ProcedureStatusDonutCard extends StatelessWidget {
  final List<ProcedureInstance> instances;

  const ProcedureStatusDonutCard({super.key, required this.instances});

  @override
  Widget build(BuildContext context) {
    final total = instances.length;
    final running = instances.where((i) => i.isRunning).length;
    final completed = instances.where((i) => i.isCompleted).length;
    final rejected = instances.where((i) => i.isRejected).length;
    final cancelled = instances.where((i) => i.isCancelled).length;

    final percentRunning = total > 0 ? ((running / total) * 100).round() : 0;
    final percentCompleted = total > 0 ? ((completed / total) * 100).round() : 0;
    final percentRejected = total > 0 ? ((rejected / total) * 100).round() : 0;
    final percentCancelled = total > 0 ? ((cancelled / total) * 100).round() : 0;

    // SLA breakdown for running instances (ok, warning, breached, none)
    final runningInstances = instances.where((i) => i.isRunning).toList();
    int conHan = 0;
    int sapHetHan = 0;
    int quaHan = 0;
    int khongCai = 0;
    for (final inst in runningInstances) {
      switch (inst.slaState) {
        case ProcedureSlaState.ok:
          conHan++;
          break;
        case ProcedureSlaState.warning:
          sapHetHan++;
          break;
        case ProcedureSlaState.breached:
          quaHan++;
          break;
        case ProcedureSlaState.none:
          khongCai++;
          break;
      }
    }

    // Role stage breakdown for running instances
    final Map<String, int> byStage = {};
    for (final inst in runningInstances) {
      final stage = inst.authorization?.currentRoleStage ?? inst.currentRole;
      byStage[stage] = (byStage[stage] ?? 0) + 1;
    }
    const stageOrder = ['S', 'R', 'E', 'C', 'A', 'I'];
    final stageLabels = {
      'S': 'procedure.overview.stage_s'.tr(),
      'R': 'procedure.overview.stage_r'.tr(),
      'E': 'procedure.overview.stage_e'.tr(),
      'C': 'procedure.overview.stage_c'.tr(),
      'A': 'procedure.overview.stage_a'.tr(),
      'I': 'procedure.overview.stage_i'.tr(),
    };
    const stageColors = {
      'S': Color(0xFF2563EB),
      'R': Color(0xFF0D9488),
      'E': Color(0xFF4F46E5),
      'C': Color(0xFF7C3AED),
      'A': Color(0xFFD97706),
      'I': Color(0xFF64748B),
    };

    final activeStages = stageOrder.where((s) => (byStage[s] ?? 0) > 0).toList();
    final int maxRoleCount = byStage.values.fold(0, (max, v) => v > max ? v : max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'procedure.overview.by_status_title'.tr(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: total > 0 ? (running + completed) / total : 0,
                        strokeWidth: 9,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'procedure.overview.cases_unit'.tr(),
                          style: const TextStyle(fontSize: 9, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildStatusLegendRow('procedure.status.running'.tr(), running, const Color(0xFF2563EB), '$percentRunning%'),
                    const SizedBox(height: 6),
                    _buildStatusLegendRow('procedure.status.completed'.tr(), completed, const Color(0xFF059669), '$percentCompleted%'),
                    const SizedBox(height: 6),
                    _buildStatusLegendRow('procedure.status.rejected'.tr(), rejected, const Color(0xFFDC2626), '$percentRejected%'),
                    const SizedBox(height: 6),
                    _buildStatusLegendRow('procedure.status.cancelled'.tr(), cancelled, const Color(0xFFEA580C), '$percentCancelled%'),
                    const SizedBox(height: 6),
                    _buildStatusLegendRow('procedure.status.reversed'.tr(), 0, const Color(0xFF94A3B8), '0%'),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // Sub-section: 9 HỒ SƠ ĐANG XỬ LÝ - THEO HẠN SLA
          Text(
            'procedure.overview.sla_title'.tr(args: {'count': running}),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 10),

          // 4-color SLA bar matching web
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (conHan > 0)
                    Expanded(
                      flex: conHan,
                      child: Container(color: const Color(0xFF16845E)),
                    ),
                  if (sapHetHan > 0)
                    Expanded(
                      flex: sapHetHan,
                      child: Container(color: const Color(0xFFE0A83A)),
                    ),
                  if (quaHan > 0)
                    Expanded(
                      flex: quaHan,
                      child: Container(color: const Color(0xFFB23B3B)),
                    ),
                  if (khongCai > 0)
                    Expanded(
                      flex: khongCai,
                      child: Container(color: const Color(0xFF8494A8)),
                    ),
                  if (conHan == 0 && sapHetHan == 0 && quaHan == 0 && khongCai == 0)
                    Expanded(child: Container(color: const Color(0xFFE2E8F0))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // SLA legend row matching web
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (conHan > 0) _buildDotIndicator(const Color(0xFF16845E), 'procedure.overview.sla_on_time'.tr(args: {'count': conHan})),
              if (sapHetHan > 0) _buildDotIndicator(const Color(0xFFE0A83A), 'procedure.overview.sla_warning'.tr(args: {'count': sapHetHan})),
              if (quaHan > 0) _buildDotIndicator(const Color(0xFFB23B3B), 'procedure.overview.sla_breached'.tr(args: {'count': quaHan})),
              if (khongCai > 0) _buildDotIndicator(const Color(0xFF8494A8), 'procedure.overview.sla_none'.tr(args: {'count': khongCai})),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // Sub-section: ĐANG CHỜ VAI NÀO
          Text(
            'procedure.overview.waiting_role_title'.tr(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 10),
          ...activeStages.map((stage) {
            final count = byStage[stage] ?? 0;
            final label = stageLabels[stage] ?? 'procedure.overview.stage_unknown'.tr(args: {'stage': stage});
            final color = stageColors[stage] ?? const Color(0xFF2563EB);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildRoleBar(label, count, maxRoleCount, color),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRoleBar(String title, int count, int max, Color color) {
    final double ratio = max > 0 ? (count / max).clamp(0.05, 1.0) : 0.1;
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.slate700),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 18,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusLegendRow(String title, int count, Color color, String percent) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.slate700),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 6),
        Text(
          percent,
          style: const TextStyle(fontSize: 10, color: AppColors.slate400),
        ),
      ],
    );
  }
}

// 4. Hồ sơ theo quy trình
class ProcedureByDefinitionCard extends StatelessWidget {
  final List<ProcedureInstance> instances;

  const ProcedureByDefinitionCard({super.key, required this.instances});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = {};
    for (final inst in instances) {
      final name = inst.definitionName.isNotEmpty ? inst.definitionName : inst.category;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayEntries = sortedEntries.take(6).toList();
    final maxCount = displayEntries.isNotEmpty ? displayEntries.first.value : 1;

    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF0D9488),
      const Color(0xFFEA580C),
      const Color(0xFF7C3AED),
      const Color(0xFFE11D48),
      const Color(0xFF0284C7),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'procedure.overview.by_procedure_title'.tr(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 16),
          if (displayEntries.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text('procedure.overview.no_cases'.tr(), style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
            )
          else
            Column(
              children: displayEntries.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDefinitionBar(e.key, e.value, maxCount, colors[idx % colors.length]),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDefinitionBar(String title, int count, int max, Color color) {
    final double ratio = max > 0 ? (count / max).clamp(0.05, 1.0) : 0.1;
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.slate700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}
