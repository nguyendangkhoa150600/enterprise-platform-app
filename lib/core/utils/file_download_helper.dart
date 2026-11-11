import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper tiện ích tải tệp tin và lưu trữ trực tiếp vào bộ nhớ máy (Download directory)
/// Giải quyết triệt để vấn đề: bấm tải chỉ mở trình duyệt web xem trước chứ không lưu vào máy.
class FileDownloadHelper {
  /// Thực hiện toàn bộ quy trình: Lấy URL -> Tải bytes -> Lưu file vào Download -> Thông báo cho người dùng
  static Future<bool> downloadDocument({
    required BuildContext context,
    required String docName,
    required String fileName,
    required Future<String?> Function() fetchDownloadUrl,
    Dio? dioClient,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    // 1. Thông báo đang chuẩn bị tải
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đang tải tệp: $fileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      // 2. Lấy link tải
      final downloadUrl = await fetchDownloadUrl();
      if (downloadUrl == null || downloadUrl.trim().isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Không thể lấy liên kết tải của tài liệu này!'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return false;
      }

      // 3. Xác định thư mục lưu trữ trên thiết bị
      final saveDirectory = await _resolveSaveDirectory();
      var safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (safeName.isEmpty) safeName = 'document_${DateTime.now().millisecondsSinceEpoch}';

      // Xử lý trùng tên: tự động thêm (1), (2)...
      var savePath = '${saveDirectory.path}/$safeName';
      var file = File(savePath);
      int counter = 1;
      final dotIndex = safeName.lastIndexOf('.');
      final baseName = dotIndex != -1 ? safeName.substring(0, dotIndex) : safeName;
      final ext = dotIndex != -1 ? safeName.substring(dotIndex) : '';

      while (await file.exists()) {
        savePath = '${saveDirectory.path}/$baseName ($counter)$ext';
        file = File(savePath);
        counter++;
      }

      // 4. Tiến hành tải xuống bằng Dio
      final dio = dioClient ?? Dio();
      final isAbsoluteUrl = downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://');
      final finalUrl = isAbsoluteUrl
          ? downloadUrl
          : (dio.options.baseUrl.isNotEmpty ? '${dio.options.baseUrl}$downloadUrl' : downloadUrl);

      await dio.download(finalUrl, savePath);

      // 5. Thông báo tải thành công kèm tuỳ chọn mở/chia sẻ
      messenger.hideCurrentSnackBar();
      final isPdf = safeName.toLowerCase().endsWith('.pdf');

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã tải về máy: $safeName\nThư mục: ${saveDirectory.path}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 7),
          action: SnackBarAction(
            label: isPdf ? 'Mở PDF' : 'Xem web',
            textColor: Colors.white,
            onPressed: () async {
              if (isPdf) {
                try {
                  final bytes = await File(savePath).readAsBytes();
                  await Printing.sharePdf(bytes: bytes, filename: safeName);
                  return;
                } catch (_) {}
              }
              final uri = Uri.tryParse(finalUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );

      return true;
    } catch (e) {
      messenger.hideCurrentSnackBar();
      // Fallback: Nếu không tải được vào filesystem, thử mở bằng trình duyệt ngoài
      try {
        final fallbackUrl = await fetchDownloadUrl();
        final uri = fallbackUrl == null ? null : Uri.tryParse(fallbackUrl);
        if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Đang mở tải qua trình duyệt: $fileName'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          return true;
        }
      } catch (_) {}

      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải xuống: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return false;
    }
  }

  /// Tìm thư mục lưu trữ phù hợp nhất trên từng nền tảng
  static Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isAndroid) {
      // Ưu tiên thư mục Download công khai của Android (mọi File Manager đều thấy ngay)
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      } catch (_) {}
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      try {
        final dlDir = await getDownloadsDirectory();
        if (dlDir != null) return dlDir;
      } catch (_) {}
    }

    return await getApplicationDocumentsDirectory();
  }
}
