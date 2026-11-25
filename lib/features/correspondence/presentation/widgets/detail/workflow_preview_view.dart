import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';

/// Ô chọn quy trình và xem trước các bước theo thứ tự đồng bộ 1:1 với Savina Web WorkflowPicker
class WorkflowPreviewView extends StatelessWidget {
  final CorrespondenceConfig config;
  final String direction;
  final String kind;
  final String selectedWorkflowId;
  final CorrespondenceDirectory directory;
  final ValueChanged<String> onWorkflowChanged;

  const WorkflowPreviewView({
    super.key,
    required this.config,
    required this.direction,
    required this.kind,
    required this.selectedWorkflowId,
    required this.directory,
    required this.onWorkflowChanged,
  });

  WorkflowModel? _autoWorkflow() {
    final usable = config.workflows.where((w) => w.isActive && w.direction == direction).toList();
    final typeCatalog = config.catalog.where((c) => c.kind == 'letter_type' && c.code == kind).firstOrNull;
    final wantedId = direction == 'incoming' ? typeCatalog?.workflowId : typeCatalog?.outgoingWorkflowId;
    if (wantedId != null && wantedId.isNotEmpty) {
      final found = usable.where((w) => w.id == wantedId).firstOrNull;
      if (found != null) return found;
    }
    return usable.where((w) => w.isDefault).firstOrNull ?? usable.firstOrNull;
  }

  WorkflowModel? _resolvedWorkflow() {
    final usable = config.workflows.where((w) => w.isActive && w.direction == direction).toList();
    if (selectedWorkflowId.isNotEmpty) {
      final found = usable.where((w) => w.id == selectedWorkflowId).firstOrNull;
      if (found != null) return found;
    }
    return _autoWorkflow();
  }

  @override
  Widget build(BuildContext context) {
    final usable = config.workflows.where((w) => w.isActive && w.direction == direction).toList();
    final auto = _autoWorkflow();
    final workflow = _resolvedWorkflow();
    final isExplicit = selectedWorkflowId.isNotEmpty;

    final startLabel = workflow?.startName?.trim().isNotEmpty == true
        ? workflow!.startName!.trim()
        : (direction == 'incoming' ? 'correspondence.workflow.start_incoming'.tr() : 'correspondence.workflow.start_outgoing'.tr());
    final endLabel = workflow?.endName?.trim().isNotEmpty == true
        ? workflow!.endName!.trim()
        : (direction == 'incoming' ? 'correspondence.workflow.end_incoming'.tr() : 'correspondence.workflow.end_outgoing'.tr());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'correspondence.workflow.label'.tr(),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),

        // Dropdown Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedWorkflowId.isNotEmpty ? selectedWorkflowId : null,
              hint: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auto != null ? 'correspondence.workflow.by_config'.tr(args: {'name': auto.name}) : 'correspondence.workflow.none_active'.tr(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedWorkflowId.isNotEmpty)
                    GestureDetector(
                      onTap: () => onWorkflowChanged(''),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                ],
              ),
              items: usable.map((w) {
                return DropdownMenuItem<String>(
                  value: w.id,
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => onWorkflowChanged(val ?? ''),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Hint Text
        Text(
          isExplicit
              ? 'correspondence.workflow.explicit_note'.tr()
              : 'correspondence.workflow.default_note'.tr(),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        // Step Preview Box (Matching Web .workflowPreview 1:1)
        if (workflow != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Start
                _buildStepItem(1, startLabel, 'correspondence.workflow.at_start'.tr()),
                const SizedBox(height: 8),

                // Intermediate Steps
                for (int i = 0; i < workflow.steps.length; i++) ...[
                  _buildStepItem(
                    i + 2,
                    workflow.steps[i].name,
                    workflow.steps[i].formatSubtitle(directory),
                  ),
                  const SizedBox(height: 8),
                ],

                // Step End
                _buildStepItem(workflow.steps.length + 2, endLabel, 'correspondence.workflow.at_end'.tr()),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              'correspondence.workflow.none_for_flow'.tr(),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
            ),
          ),
      ],
    );
  }

  Widget _buildStepItem(int seq, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$seq. $title',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
