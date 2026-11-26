import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../features/workspace/data/datasources/workspace_documents_api.dart';
import '../../../../utils/app_toast.dart';

/// Tiện ích dùng chung của tab "Tài liệu" công việc (web `document-panel.tsx` + `document-preview.tsx`).
class LinkedDocsUtils {
  LinkedDocsUtils._();

  /// Web `PREVIEWABLE_DOCUMENT_CONTENT_TYPES`.
  static const previewableTypes = <String>{
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Web `ALLOWED_DOCUMENT_CONTENT_TYPES`, theo đuôi tệp.
  static const contentTypeByExt = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'csv': 'text/csv',
    'txt': 'text/plain',
  };

  /// Web `DOCUMENT_MAX_BYTES` (50 MB) và `UPLOAD_BATCH_MAX`.
  static const maxBytes = 50 * 1024 * 1024;
  static const batchMax = 10;

  static bool isPreviewable(String? contentType) =>
      contentType != null && previewableTypes.contains(contentType);

  static String extOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  }

  /// Web `kindOf`: nhóm loại tệp cho bộ lọc.
  static String kindOf(LinkedDoc doc) {
    final type = doc.currentVersion?.contentType ?? '';
    final name = doc.currentVersion?.fileName ?? '';
    if (type.contains('pdf') || name.endsWith('.pdf')) return 'pdf';
    if (type.startsWith('image/')) return 'image';
    if (RegExp('word|excel|powerpoint|officedocument|opendocument|msword').hasMatch(type)) return 'office';
    if (RegExp(r'zip|compressed|csv|json|xml|text/plain').hasMatch(type)) return 'archive';
    return 'other';
  }

  /// Web `KIND_CHIPS` (bỏ "Tất cả").
  static List<(String, String)> kindOptions() => [
        ('pdf', 'PDF'),
        ('office', 'Office'),
        ('image', 'workspace.linked_docs.kind_image'.tr()),
        ('archive', 'workspace.linked_docs.kind_archive'.tr()),
        ('other', 'workspace.linked_docs.kind_other'.tr()),
      ];

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String date(DateTime? d) => d == null ? '' : DateFormat('dd/MM').format(d);
  static String dateTime(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  /// Web `download`: lấy URL ký trước rồi tải về máy.
  static Future<void> download(
    BuildContext context,
    WorkspaceDocumentsApi api, {
    required String documentId,
    required String name,
    required String fileName,
    String? versionId,
  }) async {
    String? error;
    await FileDownloadHelper.downloadDocument(
      context: context,
      docName: name,
      fileName: fileName,
      dioClient: api.dio,
      fetchDownloadUrl: () async {
        final res = await api.downloadUrl(documentId, versionId: versionId);
        if (res.ok && (res.data ?? '').isNotEmpty) return res.data;
        error = res.error;
        return null;
      },
    );
    if (error != null && context.mounted) AppToast.show(context, error!, isError: true);
  }

  /// Web `DocumentPreview`: URL chế độ `preview`, mở trong trình xem của hệ thống.
  static Future<void> preview(BuildContext context, WorkspaceDocumentsApi api,
      {required String documentId, String? versionId}) async {
    final res = await api.downloadUrl(documentId, versionId: versionId, preview: true);
    if (!context.mounted) return;
    final uri = res.ok ? Uri.tryParse(res.data ?? '') : null;
    if (uri == null || !uri.hasScheme) {
      AppToast.show(context, res.error ?? 'workspace.linked_docs.preview_failed'.tr(), isError: true);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened && context.mounted) {
      AppToast.show(context, 'workspace.linked_docs.preview_failed'.tr(), isError: true);
    }
  }
}

/// Ô vuông ghi đuôi tệp (web `FileTile`), màu theo loại.
class LinkedDocFileTile extends StatelessWidget {
  final String fileName;
  final bool large;
  const LinkedDocFileTile({super.key, required this.fileName, this.large = false});

  static const _tone = <String, Color>{
    'xls': Color(0xFF16A34A), 'xlsx': Color(0xFF16A34A), 'csv': Color(0xFF16A34A), 'ods': Color(0xFF16A34A),
    'doc': Color(0xFF2563EB), 'docx': Color(0xFF2563EB), 'odt': Color(0xFF2563EB), 'txt': Color(0xFF2563EB),
    'pdf': Color(0xFFDC2626),
    'ppt': Color(0xFFEA580C), 'pptx': Color(0xFFEA580C), 'odp': Color(0xFFEA580C),
    'dwg': Color(0xFF7C3AED), 'dxf': Color(0xFF7C3AED),
    'png': Color(0xFFDB2777), 'jpg': Color(0xFFDB2777), 'jpeg': Color(0xFFDB2777),
    'gif': Color(0xFFDB2777), 'webp': Color(0xFFDB2777), 'svg': Color(0xFFDB2777),
  };

  @override
  Widget build(BuildContext context) {
    final ext = LinkedDocsUtils.extOf(fileName);
    final color = _tone[ext] ?? const Color(0xFF64748B);
    final label = (ext.isEmpty ? 'workspace.linked_docs.file'.tr() : ext);
    final size = large ? 44.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.substring(0, label.length > 4 ? 4 : label.length).toUpperCase(),
        style: TextStyle(fontSize: large ? 11 : 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// Nhãn nhỏ (Chưa tải lên xong / Khách hàng / khoá).
class LinkedDocBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const LinkedDocBadge({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

/// Hộp xác nhận kiểu web `Confirm` (nút nguy hiểm).
Future<bool> confirmLinkedDocAction(
  BuildContext context, {
  required String title,
  required String description,
  required String okText,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(description, style: const TextStyle(fontSize: 13.5)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return ok ?? false;
}
