import 'package:flutter/material.dart';
import 'profile_common_widgets.dart';
import '../../../core/i18n/app_i18n.dart';

class BankTaxTabContent extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final List<dynamic> dependents;
  final VoidCallback onAddDependent;
  final void Function(String id, String name) onDeleteDependent;

  const BankTaxTabContent({
    super.key,
    required this.profile,
    required this.dependents,
    required this.onAddDependent,
    required this.onDeleteDependent,
  });

  @override
  Widget build(BuildContext context) {
    final userFullName = profile?['fullName']?.toString() ??
        profile?['full_name']?.toString() ??
        'Nguyễn Trần Như Quỳnh';

    final bankName = profile?['bankName']?.toString() ?? profile?['bank_name']?.toString();
    final bankBranch = profile?['bankBranch']?.toString() ?? profile?['bank_branch']?.toString();
    final bankAccount = profile?['bankAccountNumber']?.toString() ?? profile?['bank_account_number']?.toString();
    final taxCode = profile?['taxCode']?.toString() ?? profile?['tax_code']?.toString();
    final bhxh = profile?['socialInsuranceNumber']?.toString() ?? profile?['social_insurance_number']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thông tin ngân hàng nhận lương (Web 1:1)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF4338CA)),
                  const SizedBox(width: 8),
                  Text(
                    'profile.bank.title'.tr(),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 1: Ngân hàng & Số tài khoản
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWebInputDisplayField('profile.bank.bank_name'.tr(), bankName)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('profile.bank.account_number'.tr(), bankAccount, icon: Icons.credit_card_outlined)),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Chủ tài khoản & Chi nhánh
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWebInputDisplayField('profile.bank.account_holder'.tr(), userFullName, icon: Icons.person_outline_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('profile.bank.branch'.tr(), bankBranch, icon: Icons.place_outlined)),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Mã số thuế cá nhân & Số sổ BHXH
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWebInputDisplayField('profile.bank.tax_code'.tr(), taxCode)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('profile.bank.social_insurance_no'.tr(), bhxh)),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.shield_outlined, size: 15, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'profile.bank.security_note'.tr(),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Người thân và gia đình (Family & Dependents)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('profile.bank.dependents_title'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    onPressed: onAddDependent,
                    icon: const Icon(Icons.add, size: 13),
                    label: Text('profile.bank.add_dependent'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'profile.bank.dependents_note'.tr(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),

              if (dependents.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'profile.bank.no_dependents'.tr(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dependents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final dep = dependents[idx];
                    final name = dep['fullName']?.toString() ?? dep['full_name']?.toString() ?? 'profile.bank.default_dependent_name'.tr();
                    final relation = dep['relationship']?.toString() ?? 'profile.bank.default_relation'.tr();
                    final dob = dep['dateOfBirth']?.toString() ?? dep['date_of_birth']?.toString() ?? '----';
                    final phone = dep['phone']?.toString() ?? '----';
                    final tax = dep['taxCode']?.toString() ?? dep['tax_code']?.toString() ?? '----';
                    final id = dep['id']?.toString() ?? idx.toString();

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(profileRelationLabel(relation), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'profile.bank.dependent_info'.tr(args: {'dob': dob, 'phone': phone, 'tax': tax != '----' ? '• ${'profile.bank.tax_short'.tr()}: $tax' : ''}),
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => onDeleteDependent(id, name),
                            tooltip: 'profile.bank.delete_dependent'.tr(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
