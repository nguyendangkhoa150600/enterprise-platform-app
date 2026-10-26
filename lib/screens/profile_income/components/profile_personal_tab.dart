import 'package:flutter/material.dart';
import 'profile_common_widgets.dart';

class ProfilePersonalTabContent extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String userFullName;
  final String employeeCode;
  final TextEditingController personalEmailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController permanentAddressCtrl;
  final TextEditingController currentAddressCtrl;
  final TextEditingController emergencyNameCtrl;
  final TextEditingController emergencyRelationCtrl;
  final TextEditingController emergencyPhoneCtrl;
  final bool isSavingContact;
  final Map<String, dynamic> uploadedDocs;
  final VoidCallback onSaveContact;
  final VoidCallback onShowProfileCorrectionDialog;
  final void Function(String docKey, String docLabel) onPickDocument;
  final String Function(dynamic raw) formatDate;

  const ProfilePersonalTabContent({
    super.key,
    required this.profile,
    required this.userFullName,
    required this.employeeCode,
    required this.personalEmailCtrl,
    required this.phoneCtrl,
    required this.permanentAddressCtrl,
    required this.currentAddressCtrl,
    required this.emergencyNameCtrl,
    required this.emergencyRelationCtrl,
    required this.emergencyPhoneCtrl,
    required this.isSavingContact,
    required this.uploadedDocs,
    required this.onSaveContact,
    required this.onShowProfileCorrectionDialog,
    required this.onPickDocument,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final gender = profile?['gender']?.toString() == 'FEMALE'
        ? 'Nữ'
        : (profile?['gender']?.toString() == 'MALE' ? 'Nam' : (profile?['gender']?.toString() ?? '----'));

    final dateOfBirth = formatDate(profile?['dateOfBirth'] ?? profile?['date_of_birth']);
    final idCard = profile?['identityCardNumber']?.toString() ?? profile?['identity_card_number']?.toString() ?? '----';
    final idDate = formatDate(profile?['identityCardIssuedDate'] ?? profile?['identity_card_issued_date']);
    final idPlace = profile?['identityCardIssuedPlace']?.toString() ?? '----';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Khối nhận diện nhân sự (Chỉ đọc - Core)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'KHỐI NHẬN DIỆN NHÂN SỰ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onShowProfileCorrectionDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('Khóa sửa trực tiếp · Đề xuất chỉnh sửa', style: TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    buildWebDataRow(context, 'Họ và tên', userFullName),
                    buildWebDataRow(context, 'Mã nhân viên', employeeCode, canCopy: true),
                    buildWebDataRow(context, 'Giới tính', gender),
                    buildWebDataRow(context, 'Ngày sinh', dateOfBirth),
                    buildWebDataRow(context, 'Số CCCD / Định danh', idCard, canCopy: true),
                    buildWebDataRow(context, 'Ngày cấp', idDate),
                    buildWebDataRow(context, 'Nơi cấp', idPlace),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Thông tin liên hệ & người thân
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Liên hệ & người thân',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Được phép cập nhật', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildProfileInputField(
                      label: 'Email cá nhân',
                      controller: personalEmailCtrl,
                      hintText: 'Chưa cập nhật email cá nhân',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'Số điện thoại di động',
                      controller: phoneCtrl,
                      hintText: 'Chưa cập nhật số điện thoại',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'Địa chỉ thường trú',
                      controller: permanentAddressCtrl,
                      hintText: 'Chưa cập nhật địa chỉ thường trú',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'Địa chỉ tạm trú / Nơi ở hiện tại',
                      controller: currentAddressCtrl,
                      hintText: 'Chưa cập nhật địa chỉ nơi ở hiện tại',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 18),

                    // Sub-section: Người liên hệ khẩn cấp
                    const Row(
                      children: [
                        Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Người liên hệ khẩn cấp',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    buildProfileInputField(
                      label: 'Họ và tên',
                      controller: emergencyNameCtrl,
                      hintText: 'Chưa có thông tin người liên hệ',
                      prefixIcon: Icons.person_outline_rounded,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),

                    buildProfileRelationshipDropdown(
                      relationController: emergencyRelationCtrl,
                      onChanged: (val) {
                        emergencyRelationCtrl.text = val;
                      },
                    ),
                    const SizedBox(height: 12),

                    buildProfileInputField(
                      label: 'Số điện thoại',
                      controller: emergencyPhoneCtrl,
                      hintText: 'Chưa có SĐT khẩn cấp',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isSavingContact ? null : onSaveContact,
                        icon: isSavingContact
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 15),
                        label: Text(isSavingContact ? 'Đang lưu...' : 'Lưu thông tin liên hệ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Ảnh và giấy tờ (Web 1:1)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ảnh và giấy tờ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              const Text(
                'Bổ sung các giấy tờ bắt buộc để hoàn thiện hồ sơ cá nhân: Ảnh CCCD mặt trước, mặt sau và ảnh thẻ. Mọi thay đổi được gửi thành đơn và chỉ có hiệu lực sau khi HR duyệt.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 12),

              // Alert Missing Required Docs Banner (Dynamic calculation)
              () {
                final hasFront = uploadedDocs['id_card_front'] != null;
                final hasBack = uploadedDocs['id_card_back'] != null;
                final idNum = profile?['identityCardNumber']?.toString().trim();
                final hasIdNum = idNum != null && idNum.isNotEmpty && idNum != '----';

                final missingDocs = <String>[];
                if (!hasIdNum) missingDocs.add('số CCCD');
                if (!hasFront) missingDocs.add('ảnh CCCD mặt trước');
                if (!hasBack) missingDocs.add('ảnh CCCD mặt sau');

                if (missingDocs.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hồ sơ đã đầy đủ tất cả giấy tờ định danh bắt buộc.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hồ sơ chưa đủ giấy tờ bắt buộc, còn thiếu: ${missingDocs.join(', ')}.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              }(),

              // 3 Document Upload Cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: buildWebDocumentCard(
                      title: 'Ảnh thẻ',
                      docKey: 'photo_card',
                      uploadedDoc: uploadedDocs['photo_card'] as Map<String, dynamic>?,
                      isRequired: false,
                      onPickDocument: () => onPickDocument('photo_card', 'Ảnh thẻ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildWebDocumentCard(
                      title: 'CCCD mặt trước',
                      docKey: 'id_card_front',
                      uploadedDoc: uploadedDocs['id_card_front'] as Map<String, dynamic>?,
                      isRequired: true,
                      onPickDocument: () => onPickDocument('id_card_front', 'CCCD mặt trước'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildWebDocumentCard(
                      title: 'CCCD mặt sau',
                      docKey: 'id_card_back',
                      uploadedDoc: uploadedDocs['id_card_back'] as Map<String, dynamic>?,
                      isRequired: true,
                      onPickDocument: () => onPickDocument('id_card_back', 'CCCD mặt sau'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ngày hết hạn CCCD
              Row(
                children: [
                  const Text('Ngày hết hạn CCCD: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                  Text(
                    formatDate(profile?['identityCardExpiryDate']),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
