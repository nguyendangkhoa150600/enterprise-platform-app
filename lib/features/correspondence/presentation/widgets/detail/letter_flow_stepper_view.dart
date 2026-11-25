import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Section 1: Tiến trình xử lý (FlowStepper matching Savina Web 1:1)
class LetterFlowStepperView extends StatelessWidget {
  final List<FlowNode> flow;
  final String? workflowName;

  const LetterFlowStepperView({
    super.key,
    required this.flow,
    this.workflowName,
  });

  @override
  Widget build(BuildContext context) {
    if (flow.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'correspondence.detail_view.flow_title'.tr(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (workflowName != null && workflowName!.isNotEmpty)
                Flexible(
                  child: Text(
                    'correspondence.detail_view.flow_workflow'.tr(args: {'name': workflowName}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper List
          Column(
            children: flow.asMap().entries.map((entry) {
              final index = entry.key;
              final node = entry.value;
              final isLast = index == flow.length - 1;
              return _buildStepRow(index + 1, node, isLast);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(int stepNo, FlowNode node, bool isLast) {
    Color iconBg = const Color(0xFFF1F5F9);
    Widget iconChild = Text(
      '$stepNo',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
    );

    if (node.state == 'done') {
      iconBg = const Color(0xFF10B981); // Emerald
      iconChild = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (node.state == 'current') {
      iconBg = const Color(0xFF2563EB); // Blue
      iconChild = Text(
        '$stepNo',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator column (circle + connector line)
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  boxShadow: node.state == 'current'
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: iconChild),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: node.state == 'done' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Step Details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          node.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: node.state == 'current' ? FontWeight.w700 : FontWeight.w600,
                            color: node.state == 'current' ? const Color(0xFF1E293B) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      if (node.state == 'current')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'correspondence.detail_view.flow_current'.tr(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (node.people != null && node.people!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      node.people!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                  if (node.at != null && node.at!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      CorrespondenceDateUtils.formatDateTime(node.at!),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
