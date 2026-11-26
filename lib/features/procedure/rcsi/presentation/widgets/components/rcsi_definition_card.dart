import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/rcsi_definition_models.dart';
import 'rcsi_common.dart';

/// "{n} bước · {g} rẽ nhánh · v{x}" — dòng phụ dưới tên quy trình như web.
String rcsiDefinitionSubtitle(ProcedureDefinition definition) {
  final gateways = definition.gateways?.length ?? 0;
  final parts = [
    'procedure.rcsi.common.step_count'.tr(args: {'count': definition.steps.length}),
    if (gateways > 0) 'procedure.rcsi.common.gateway_count'.tr(args: {'count': gateways}),
    'v${definition.versionNumber}',
  ];
  return parts.join(' · ');
}

/// Một dòng quy trình trên danh sách Ma trận RCSI.
class RcsiDefinitionCard extends StatelessWidget {
  final ProcedureDefinition definition;
  final String? groupLabel;
  final bool highlighted;
  final VoidCallback onTap;

  const RcsiDefinitionCard({
    super.key,
    required this.definition,
    required this.onTap,
    this.groupLabel,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: highlighted ? AppColors.primaryBorder : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            definition.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RcsiStatusBadge(definition.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rcsiDefinitionSubtitle(definition),
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                    if (groupLabel != null) ...[
                      const SizedBox(height: 6),
                      RcsiTag(groupLabel!, icon: Icons.folder_outlined),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
