import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../core/utils/file_download_helper.dart';
import '../../../domain/models/correspondence_models.dart';
import '../../../domain/repositories/i_correspondence_repository.dart';
import '../../../data/repositories/correspondence_repository_impl.dart';
import '../correspondence_letter_detail_bottom_sheet.dart';
import '../../utils/correspondence_error.dart';

/// BottomSheet hiển thị chi tiết hồ sơ lưu trữ và danh sách tệp đính kèm (matching Web DossierView 1:1)
class ArchiveDossierSheet extends StatelessWidget {
  final ArchiveDossier dossier;
  final String today;
  final VoidCallback? onRefresh;

  const ArchiveDossierSheet({
    super.key,
    required this.dossier,
    required this.today,
    this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required ArchiveDossier dossier,
    required String today,
    VoidCallback? onRefresh,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArchiveDossierSheet(
        dossier: dossier,
        today: today,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = dossier.direction == 'incoming';
    final isArchived = dossier.stage == 'archived';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stage badge / Mã hồ sơ
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isArchived ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isArchived ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Text(
                          dossier.archiveCode != null && dossier.archiveCode!.isNotEmpty
                              ? 'correspondence.archive.dossier_code'.tr(args: {'code': dossier.archiveCode})
                              : (dossier.stageLabel.isNotEmpty ? dossier.stageLabel : 'correspondence.archive.in_progress'.tr()),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isArchived ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Folder Name
                      Text(
                        dossier.folderName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Meta info
                      Text(
                        '${(isIncoming ? 'correspondence.archive.dossier_meta_incoming' : 'correspondence.archive.dossier_meta_outgoing').tr(args: {'no': dossier.displayNo})}${dossier.partner != null && dossier.partner!.isNotEmpty ? " · ${dossier.partner}" : ""} · ${CorrespondenceDateUtils.formatDay(dossier.receivedOn)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // "Mở công văn" Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openLetterDetail(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF0284C7)),
                label: Text(
                  'correspondence.archive.open_letter'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.6, color: Color(0xFFE2E8F0)),

          // File List
          Flexible(
            child: dossier.files.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'correspondence.archive.dossier_no_files'.tr(),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    itemCount: dossier.files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final file = dossier.files[index];
                      return _buildFileItem(context, file);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, ArchiveFile file) {
    final isPdf = file.fileName.toLowerCase().endsWith('.pdf');
    final isWord = file.fileName.toLowerCase().endsWith('.doc') ||
        file.fileName.toLowerCase().endsWith('.docx');

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
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : (isWord ? Icons.description_outlined : Icons.insert_drive_file_outlined),
                size: 24,
                color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.kindLabel}${file.unitName != null ? " · ${file.unitName}" : ""}${file.versionNo > 1 ? " · v${file.versionNo}" : ""} · ${file.formattedSize}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // File Action Buttons (Xem & Tải về)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Xem (Preview)
              InkWell(
                onTap: () => _previewFile(context, file),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
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
                      Text(
                        'Xem',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tải về (Download)
              InkWell(
                onTap: () => _downloadFile(context, file),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        'correspondence.archive.download'.tr(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openLetterDetail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ICorrespondenceRepository repo = CorrespondenceRepositoryImpl();

    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text('correspondence.archive.opening_letter'.tr()),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final detail = await repo.getLetter(dossier.letterId);
      if (!context.mounted) return;

      Navigator.pop(context); // Đóng Dossier sheet
      CorrespondenceLetterDetailBottomSheet.show(context, detail, today);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('correspondence.archive.open_letter_failed'.tr(args: {'error': correspondenceErrorMessage(e, 'common.error_generic'.tr())})),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _previewFile(BuildContext context, ArchiveFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final ICorrespondenceRepository repo = CorrespondenceRepositoryImpl();

    try {
      final ticket = await repo.getAttachmentTicket(dossier.letterId, file.id, mode: 'preview');
      final uri = Uri.tryParse(ticket.downloadUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('correspondence.archive.preview_link_failed'.tr());
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('correspondence.archive.preview_failed'.tr(args: {'error': correspondenceErrorMessage(e, 'common.error_generic'.tr())})),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context, ArchiveFile file) async {
    final ICorrespondenceRepository repo = CorrespondenceRepositoryImpl();

    await FileDownloadHelper.downloadDocument(
      context: context,
      docName: file.fileName,
      fileName: file.fileName,
      fetchDownloadUrl: () async {
        final ticket = await repo.getAttachmentTicket(dossier.letterId, file.id, mode: 'download');
        return ticket.downloadUrl;
      },
    );
  }
}
