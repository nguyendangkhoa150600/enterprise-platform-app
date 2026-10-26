import 'package:flutter/material.dart';
import 'profile_common_widgets.dart';

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
              const Row(
                children: [
                  Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF4338CA)),
                  SizedBox(width: 8),
                  Text(
                    'Thông tin ngân hàng nhận lương',
                    style: TextStyle(
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
                  Expanded(child: buildWebInputDisplayField('Ngân hàng', bankName)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('Số tài khoản', bankAccount, icon: Icons.credit_card_outlined)),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Chủ tài khoản & Chi nhánh
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWebInputDisplayField('Chủ tài khoản', userFullName, icon: Icons.person_outline_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('Chi nhánh', bankBranch, icon: Icons.place_outlined)),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Mã số thuế cá nhân & Số sổ BHXH
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildWebInputDisplayField('Mã số thuế cá nhân', taxCode)),
                  const SizedBox(width: 12),
                  Expanded(child: buildWebInputDisplayField('Số sổ BHXH', bhxh)),
                ],
              ),
              const SizedBox(height: 16),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.shield_outlined, size: 15, color: Color(0xFF64748B)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thông tin tài khoản ngân hàng được bảo mật và chỉ hiển thị cho các vai trò có thẩm quyền. Cần thay đổi vui lòng liên hệ phòng Nhân sự.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
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
                  const Text('Người thân và gia đình', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    onPressed: onAddDependent,
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('Thêm người thân', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              const Text(
                'Thông tin tự khai. Giảm trừ chỉ áp dụng sau khi HR xác minh đăng ký.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),

              if (dependents.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có thông tin người thân',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                    final name = dep['fullName']?.toString() ?? dep['full_name']?.toString() ?? 'Người thân';
                    final relation = dep['relationship']?.toString() ?? 'Quan hệ';
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
                                      child: Text(relation, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ngày sinh: $dob • SĐT: $phone ${tax != '----' ? '• MST: $tax' : ''}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => onDeleteDependent(id, name),
                            tooltip: 'Xóa người thân',
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
