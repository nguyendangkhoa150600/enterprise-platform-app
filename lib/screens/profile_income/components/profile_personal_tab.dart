import 'package:flutter/material.dart';
import 'profile_common_widgets.dart';
import '../../../core/i18n/app_i18n.dart';

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
        ? 'profile.personal.gender_female'.tr()
        : (profile?['gender']?.toString() == 'MALE' ? 'profile.personal.gender_male'.tr() : (profile?['gender']?.toString() ?? '----'));

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
                          Expanded(
                            child: Text(
                              'profile.personal.identity_block_title'.tr(),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('profile.personal.locked_badge'.tr(), style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
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
                    buildWebDataRow(context, 'profile.personal.full_name'.tr(), userFullName),
                    buildWebDataRow(context, 'profile.personal.employee_code'.tr(), employeeCode, canCopy: true),
                    buildWebDataRow(context, 'profile.personal.gender'.tr(), gender),
                    buildWebDataRow(context, 'profile.personal.date_of_birth'.tr(), dateOfBirth),
                    buildWebDataRow(context, 'profile.personal.id_number'.tr(), idCard, canCopy: true),
                    buildWebDataRow(context, 'profile.personal.id_issued_date'.tr(), idDate),
                    buildWebDataRow(context, 'profile.personal.id_issued_place'.tr(), idPlace),
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
                    Expanded(
                      child: Text(
                        'profile.personal.contact_title'.tr(),
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('profile.personal.editable_badge'.tr(), style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
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
                      label: 'profile.personal.personal_email'.tr(),
                      controller: personalEmailCtrl,
                      hintText: 'profile.personal.personal_email_hint'.tr(),
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'profile.personal.mobile_phone'.tr(),
                      controller: phoneCtrl,
                      hintText: 'profile.personal.mobile_phone_hint'.tr(),
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'profile.personal.permanent_address'.tr(),
                      controller: permanentAddressCtrl,
                      hintText: 'profile.personal.permanent_address_hint'.tr(),
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    buildProfileInputField(
                      label: 'profile.personal.current_address'.tr(),
                      controller: currentAddressCtrl,
                      hintText: 'profile.personal.current_address_hint'.tr(),
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 18),

                    // Sub-section: Người liên hệ khẩn cấp
                    Row(
                      children: [
                        Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'profile.personal.emergency_contact'.tr(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    buildProfileInputField(
                      label: 'profile.personal.full_name'.tr(),
                      controller: emergencyNameCtrl,
                      hintText: 'profile.personal.emergency_name_hint'.tr(),
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
                      label: 'profile.personal.phone_number'.tr(),
                      controller: emergencyPhoneCtrl,
                      hintText: 'profile.personal.emergency_phone_hint'.tr(),
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
                        label: Text(isSavingContact ? 'profile.personal.saving'.tr() : 'profile.personal.save_contact'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              Text('profile.personal.docs_title'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              Text(
                'profile.personal.docs_subtitle'.tr(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 12),

              // Alert Missing Required Docs Banner (Dynamic calculation)
              () {
                final hasFront = uploadedDocs['id_card_front'] != null;
                final hasBack = uploadedDocs['id_card_back'] != null;
                final idNum = profile?['identityCardNumber']?.toString().trim();
                final hasIdNum = idNum != null && idNum.isNotEmpty && idNum != '----';

                final missingDocs = <String>[];
                if (!hasIdNum) missingDocs.add('profile.personal.missing_id_number'.tr());
                if (!hasFront) missingDocs.add('profile.personal.missing_id_front'.tr());
                if (!hasBack) missingDocs.add('profile.personal.missing_id_back'.tr());

                if (missingDocs.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'profile.personal.docs_complete'.tr(),
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
                          'profile.personal.docs_missing'.tr(args: {'docs': missingDocs.join(', ')}),
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
                      title: 'profile.personal.doc_photo_card'.tr(),
                      docKey: 'photo_card',
                      uploadedDoc: uploadedDocs['photo_card'] as Map<String, dynamic>?,
                      isRequired: false,
                      onPickDocument: () => onPickDocument('photo_card', 'profile.personal.doc_photo_card'.tr()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildWebDocumentCard(
                      title: 'profile.personal.doc_id_front'.tr(),
                      docKey: 'id_card_front',
                      uploadedDoc: uploadedDocs['id_card_front'] as Map<String, dynamic>?,
                      isRequired: true,
                      onPickDocument: () => onPickDocument('id_card_front', 'profile.personal.doc_id_front'.tr()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildWebDocumentCard(
                      title: 'profile.personal.doc_id_back'.tr(),
                      docKey: 'id_card_back',
                      uploadedDoc: uploadedDocs['id_card_back'] as Map<String, dynamic>?,
                      isRequired: true,
                      onPickDocument: () => onPickDocument('id_card_back', 'profile.personal.doc_id_back'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ngày hết hạn CCCD
              Row(
                children: [
                  Text('profile.personal.id_expiry_label'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
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
