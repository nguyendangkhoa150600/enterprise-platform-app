import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../../models/hrm_models.dart';

class HrmDependentsView extends StatelessWidget {
  final List<HrmDependentItem> dependents;
  final String Function(double?) formatCurrency;
  final String Function(DateTime?) formatDate;
  final VoidCallback onAddDependent;

  const HrmDependentsView({
    super.key,
    required this.dependents,
    required this.formatCurrency,
    required this.formatDate,
    required this.onAddDependent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('hrm_screens.dependents.title'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('hrm_screens.dependents.subtitle'.tr(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onAddDependent,
                icon: const Icon(Icons.add, size: 16),
                label: Text('hrm_screens.dependents.register_new'.tr(), style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Deduction Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('hrm_screens.dependents.current_deduction'.tr(), style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                      const SizedBox(height: 2),
                      Text(
                        'hrm_screens.dependents.per_month'.tr(args: {'amount': formatCurrency(dependents.where((d) => d.status == 'VERIFIED').length * 4400000.0)}),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      Text('hrm_screens.dependents.registered_count'.tr(args: {'count': dependents.length}), style: const TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List of Dependents
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dependents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dep = dependents[index];
              final isVerified = dep.status == 'VERIFIED';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dep.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isVerified ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            isVerified ? 'hrm_screens.dependents.verified'.tr() : 'hrm_screens.dependents.pending'.tr(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('hrm_screens.dependents.relationship'.tr(args: {'value': dep.relationship}), style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        const SizedBox(width: 12),
                        Text('hrm_screens.dependents.dob'.tr(args: {'value': formatDate(dep.dateOfBirth)}), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('hrm_screens.dependents.id_tax'.tr(args: {'id': dep.idNumber, 'tax': dep.taxCode}), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
