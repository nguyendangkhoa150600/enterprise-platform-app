import 'package:flutter/material.dart';

class DecisionCompareCard extends StatelessWidget {
  final String beforePosition;
  final String afterPosition;
  final bool isPosChanged;
  final String beforeUnit;
  final String afterUnit;
  final bool isUnitChanged;
  final String beforeSalary;
  final String afterSalary;
  final bool isSalaryChanged;

  const DecisionCompareCard({
    super.key,
    required this.beforePosition,
    required this.afterPosition,
    required this.isPosChanged,
    required this.beforeUnit,
    required this.afterUnit,
    required this.isUnitChanged,
    required this.beforeSalary,
    required this.afterSalary,
    required this.isSalaryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRƯỚC / SAU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
            },
            children: [
              // Table Header
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: SizedBox.shrink(),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'TRƯỚC',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'SAU',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
              // Chức danh
              _buildRow(
                label: 'Chức danh',
                before: beforePosition,
                after: afterPosition,
                isChanged: isPosChanged,
              ),
              // Đơn vị
              _buildRow(
                label: 'Đơn vị',
                before: beforeUnit,
                after: afterUnit,
                isChanged: isUnitChanged,
              ),
              // Lương cơ bản
              _buildRow(
                label: 'Lương cơ bản',
                before: beforeSalary,
                after: afterSalary,
                isChanged: isSalaryChanged,
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildRow({
    required String label,
    required String before,
    required String after,
    required bool isChanged,
    bool isLast = false,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: isLast ? 4 : 6),
          child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: isLast ? 4 : 6),
          child: Text(
            before,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: isLast ? 4 : 6),
          child: Text(
            after,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isChanged ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
