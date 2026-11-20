import 'package:flutter/material.dart';
import '../../../domain/models/correspondence_models.dart';

/// Section 6: Tệp của hồ sơ (Attachments) matching Savina Web 1:1
class LetterAttachmentsView extends StatelessWidget {
  final List<LetterAttachment> attachments;
  final VoidCallback? onUploadScan;
  final VoidCallback? onUploadRef;

  const LetterAttachmentsView({
    super.key,
    required this.attachments,
    this.onUploadScan,
    this.onUploadRef,
  });

  @override
  Widget build(BuildContext context) {
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
            children: const [
              Text(
                'Tệp của hồ sơ',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Lưu tại Hệ dùng chung, có phiên bản',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // File Items List
          if (attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có tệp đính kèm nào.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
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

          const SizedBox(height: 14),

          // Action Buttons: Tải bản quét & Tải tài liệu kèm theo
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUploadScan,
                  icon: const Icon(Icons.upload_file_outlined, size: 16, color: Color(0xFF475569)),
                  label: const Text(
                    'Tải bản quét công văn đến',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUploadRef,
                  icon: const Icon(Icons.note_add_outlined, size: 16, color: Color(0xFF475569)),
                  label: const Text(
                    'Tải tài liệu kèm theo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                    SnackBar(content: Text('Đang mở xem tệp "${att.fileName}"...'), behavior: SnackBarBehavior.floating),
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
                    children: const [
                      Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF475569)),
                      SizedBox(width: 4),
                      Text('Xem', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Tải về button
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đang tải xuống "${att.fileName}"...'), behavior: SnackBarBehavior.floating),
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
        return 'Công văn đến';
      case 'draft':
        return 'Dự thảo, kết quả xử lý';
      case 'outgoing':
        return 'Bản ban hành';
      case 'reference':
        return 'Tài liệu kèm theo';
      default:
        return 'Tài liệu';
    }
  }
}
