import 'package:flutter/material.dart';
import '../../../models/procedure_models.dart';
import '../../../theme/colors.dart';

class ProcedureFlowDiagramCard extends StatelessWidget {
  final List<ProcedureDefinition> definitions;
  final String? selectedDefinitionId;
  final VoidCallback onSelectProcedure;

  const ProcedureFlowDiagramCard({
    super.key,
    required this.definitions,
    required this.selectedDefinitionId,
    required this.onSelectProcedure,
  });

  @override
  Widget build(BuildContext context) {
    ProcedureDefinition? currentDef;
    if (definitions.isNotEmpty) {
      currentDef = definitions.firstWhere(
        (d) => d.id == selectedDefinitionId,
        orElse: () => definitions.first,
      );
    }
    final sortedSteps = currentDef != null
        ? ([...currentDef.steps]..sort((a, b) => a.order.compareTo(b.order)))
        : <ProcedureStepDefinition>[];

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
          const Text(
            'SƠ ĐỒ LUỒNG CÁC BƯỚC QUY TRÌNH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 14),

          // Dropdown selector
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSelectProcedure,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentDef?.displayName ?? 'Chưa có quy trình',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Flow step cards
          if (sortedSteps.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Chưa có bước thiết lập cho quy trình này',
                style: TextStyle(fontSize: 13, color: AppColors.slate400),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < sortedSteps.length; i++) ...[
                    _buildDynamicFlowStepCard(
                      stepNum: '${i + 1}',
                      stepName: sortedSteps[i].name,
                      roles: sortedSteps[i].roles,
                    ),
                    if (i < sortedSteps.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
                      ),
                  ],
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // RACI Legend: QUY TRÌNH · BƯỚC
          _buildRaciLegend(),
        ],
      ),
    );
  }

  Widget _buildRaciLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUY TRÌNH · BƯỚC',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildRaciLegendItem('S', 'khởi tạo', const Color(0xFFFEF9C3), const Color(0xFF854D0E), const Color(0xFFFEF08A))),
            Expanded(child: _buildRaciLegendItem('R', 'xem xét', const Color(0xFFDBEAFE), const Color(0xFF1E40AF), const Color(0xFFBFDBFE))),
            Expanded(child: _buildRaciLegendItem('E', 'thực thi', const Color(0xFFFFEDD5), const Color(0xFF9A3412), const Color(0xFFFED7AA))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildRaciLegendItem('C', 'kiểm soát', const Color(0xFFF3E8FF), const Color(0xFF6B21A8), const Color(0xFFE9D5FF))),
            Expanded(child: _buildRaciLegendItem('A', 'phê duyệt', const Color(0xFFDCFCE7), const Color(0xFF166534), const Color(0xFFBBF7D0))),
            Expanded(child: _buildRaciLegendItem('I', 'nhận thông tin', const Color(0xFFF1F5F9), const Color(0xFF475569), const Color(0xFFE2E8F0))),
          ],
        ),
      ],
    );
  }

  Widget _buildRaciLegendItem(String code, String label, Color bg, Color text, Color border) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: text,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFlowStepCard({
    required String stepNum,
    required String stepName,
    required List<String> roles,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNum,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stepName,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (roles.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: roles.map((r) => _buildRoleBadge(r)).toList(),
            )
          else
            const Text('-', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color text;
    Color border;

    switch (role.toUpperCase()) {
      case 'S':
        bg = const Color(0xFFFEF9C3);
        text = const Color(0xFF854D0E);
        border = const Color(0xFFFEF08A);
        break;
      case 'R':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        border = const Color(0xFFBFDBFE);
        break;
      case 'E':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFF9A3412);
        border = const Color(0xFFFED7AA);
        break;
      case 'C':
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF6B21A8);
        border = const Color(0xFFE9D5FF);
        break;
      case 'A':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        border = const Color(0xFFBBF7D0);
        break;
      case 'I':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        border = const Color(0xFFE2E8F0);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        border = const Color(0xFFCBD5E1);
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        role,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: text),
      ),
    );
  }
}
