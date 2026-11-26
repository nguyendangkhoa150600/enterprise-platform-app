import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Section 6: Tệp của hồ sơ (Attachments) matching Savina Web 1:1
/// Như web: chỉ hiện tệp của hồ sơ (kết quả từng phòng ban nằm ở mục Phòng ban xử lý)
/// và chỉ hiện nút tải những loại tệp máy chủ cho phép ở bước này (`actions.attachKinds`).
class LetterAttachmentsView extends StatelessWidget {
  final LetterDetail letter;
  final void Function(String kind)? onUpload;

  const LetterAttachmentsView({
    super.key,
    required this.letter,
    this.onUpload,
  });

  static const Map<String, String> _uploadLabelKeys = {
    'incoming': 'correspondence.attachments.upload_incoming',
    'draft': 'correspondence.attachments.upload_draft',
    'outgoing': 'correspondence.attachments.upload_outgoing',
    'reference': 'correspondence.attachments.upload_reference',
  };

  static const Map<String, IconData> _uploadIcons = {
    'incoming': Icons.upload_file_outlined,
    'draft': Icons.edit_document,
    'outgoing': Icons.verified_outlined,
    'reference': Icons.note_add_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final attachments = letter.attachments.where((item) => item.assignmentId == null || item.assignmentId!.isEmpty).toList();
    // Kết quả của phòng ban tải ở mục phòng ban; công văn đi thì dự thảo tải ở đây.
    final kinds = letter.actions.attachKinds
        .where((kind) => _uploadLabelKeys.containsKey(kind))
        .where((kind) => kind != 'draft' || letter.direction == 'outgoing')
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'correspondence.detail_view.attachments_title'.tr(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'correspondence.detail_view.attachments_subtitle'.tr(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // File Items List
          if (attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                letter.direction == 'incoming'
                    ? 'correspondence.attachments.empty_incoming'.tr()
                    : 'correspondence.attachments.empty'.tr(),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attachments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final att = attachments[index];
                return _buildAttachmentCard(context, att);
              },
            ),

          if (kinds.isNotEmpty && onUpload != null) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                // 2 nút một hàng; lẻ thì nút cuối chiếm cả hàng.
                final half = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < kinds.length; i++)
                      SizedBox(
                        width: (kinds.length.isOdd && i == kinds.length - 1) ? constraints.maxWidth : half,
                        child: _buildUploadButton(kinds[i]),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadButton(String kind) {
    return OutlinedButton.icon(
      onPressed: () => onUpload?.call(kind),
      icon: Icon(_uploadIcons[kind] ?? Icons.upload_file_outlined, size: 16, color: const Color(0xFF475569)),
      label: Text(
        (_uploadLabelKeys[kind] ?? 'correspondence.attachments.upload_generic').tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, LetterAttachment att) {
    final isPdf = att.fileName.toLowerCase().endsWith('.pdf');
    final isWord = att.fileName.toLowerCase().endsWith('.doc') || att.fileName.toLowerCase().endsWith('.docx');

    final meta = [
      _kindLabel(att.kind),
      if (att.sizeBytes > 0) att.formattedSize,
      if (att.uploadedByName.isNotEmpty) att.uploadedByName,
      if (att.createdAt.isNotEmpty) CorrespondenceDateUtils.formatDateTime(att.createdAt),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPdf ? Icons.picture_as_pdf_outlined : (isWord ? Icons.description_outlined : Icons.insert_drive_file_outlined),
                size: 22,
                color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      att.fileName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Xem button
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('correspondence.detail_view.attachment_opening'.tr(args: {'name': att.fileName})), behavior: SnackBarBehavior.floating),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text('correspondence.detail_view.attachment_view'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Tải về button
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('correspondence.detail_view.attachment_downloading'.tr(args: {'name': att.fileName})), behavior: SnackBarBehavior.floating),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'incoming':
        return 'correspondence.detail_view.attachment_kind_incoming'.tr();
      case 'draft':
        return 'correspondence.detail_view.attachment_kind_draft'.tr();
      case 'outgoing':
        return 'correspondence.detail_view.attachment_kind_outgoing'.tr();
      case 'reference':
        return 'correspondence.detail_view.attachment_kind_reference'.tr();
      default:
        return 'correspondence.detail_view.attachment_kind_other'.tr();
    }
  }
}
