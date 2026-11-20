import 'package:flutter/material.dart';
import '../../domain/models/correspondence_models.dart';

class CorrespondenceStepperFlowCards extends StatelessWidget {
  final CorrespondenceOverview overview;
  final Function(String direction, String stage)? onSelectStage;

  const CorrespondenceStepperFlowCards({
    super.key,
    required this.overview,
    this.onSelectStage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDirectionFlowCard(
          direction: 'incoming',
          title: 'Công văn đến theo bước',
          stages: CorrespondenceConstants.incomingStages,
        ),
        const SizedBox(height: 12),
        _buildDirectionFlowCard(
          direction: 'outgoing',
          title: 'Công văn đi theo bước',
          stages: CorrespondenceConstants.outgoingStages,
        ),
      ],
    );
  }

  Widget _buildDirectionFlowCard({
    required String direction,
    required String title,
    required List<String> stages,
  }) {
    final stageCounts = overview.byStage[direction] ?? {};
    final total = stages.fold<int>(0, (sum, st) => sum + (stageCounts[st] ?? 0));
    final statusText = total == 0 ? 'Không có công văn đang mở' : '$total công văn đang mở';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Total status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stepper Flow Row with connecting lines
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Connecting horizontal line positioned behind step circles
                  Positioned(
                    top: 13,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),

                  // Steps
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(stages.length, (index) {
                      final stage = stages[index];
                      final count = stageCounts[stage] ?? 0;
                      final isBusy = count > 0;
                      final label = CorrespondenceConstants.stageLabelOf(stage);

                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            if (onSelectStage != null) {
                              onSelectStage!(direction, stage);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Step circle indicator: solid blue if has items, light grey if 0
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isBusy ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isBusy ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                    boxShadow: isBusy
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isBusy ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Count
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isBusy ? const Color(0xFF2563EB) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Stage Label
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isBusy ? FontWeight.w700 : FontWeight.w500,
                                    color: isBusy ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
