import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/api_client_helper.dart';

/// Remote DataSource giao tiếp trực tiếp với Correspondence API: /api/correspondence/v1
class CorrespondenceRemoteDataSource {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthProvider.authBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 25),
  ));

  CorrespondenceRemoteDataSource() {
    ApiClientHelper.configureDio(_dio);
  }

  /// GET /api/correspondence/v1/overview
  Future<dynamic> getOverviewRaw() async {
    final res = await _dio.get(
      '/api/correspondence/v1/overview',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/status
  Future<dynamic> getStatusRaw() async {
    final res = await _dio.get(
      '/api/correspondence/v1/status',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/letters?box=mine|incoming|outgoing
  Future<dynamic> getLettersRaw({
    String? box,
    String? search,
    String? stage,
    String? kind,
    String? month,
    String? bookId,
  }) async {
    final q = <String, dynamic>{};
    if (box != null && box.isNotEmpty) q['box'] = box;
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
    if (stage != null && stage.isNotEmpty) q['stage'] = stage;
    if (kind != null && kind.isNotEmpty) q['kind'] = kind;
    if (month != null && month.isNotEmpty) q['month'] = month;
    if (bookId != null && bookId.isNotEmpty) q['bookId'] = bookId;

    final res = await _dio.get(
      '/api/correspondence/v1/letters',
      queryParameters: q.isNotEmpty ? q : null,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/config
  Future<dynamic> getConfigRaw() async {
    final res = await _dio.get(
      '/api/correspondence/v1/config',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/directory
  Future<dynamic> getDirectoryRaw() async {
    final res = await _dio.get(
      '/api/correspondence/v1/directory',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/outgoing
  Future<dynamic> createOutgoingRaw(Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/api/correspondence/v1/outgoing',
      data: data,
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters
  Future<dynamic> createLetterRaw(Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters',
      data: data,
    );
    return res.data;
  }

  /// Tải tệp đính kèm theo luồng ký trước (Signed upload ticket)
  Future<void> uploadAttachmentRaw(String letterId, dynamic file, String kind) async {
    if (file == null) return;
    String fileName = '';
    int sizeBytes = 0;
    List<int>? bytes;

    if (file is PlatformFile) {
      fileName = file.name;
      sizeBytes = await file.length() ?? 0;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {}
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
          if (sizeBytes == 0) sizeBytes = bytes.length;
        }
      }
    }

    if (fileName.isEmpty || bytes == null || bytes.isEmpty) return;

    // 1. Lấy vé tải lên (ticket)
    String contentType = 'application/octet-stream';
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      contentType = 'application/pdf';
    } else if (lower.endsWith('.doc')) {
      contentType = 'application/msword';
    } else if (lower.endsWith('.docx')) {
      contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    } else if (lower.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    }

    final ticketRes = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(letterId)}/attachments',
      data: {
        'kind': kind,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );

    final ticketData = ticketRes.data;
    if (ticketData == null) return;
    final uploadUrl = ticketData['uploadUrl']?.toString();
    final attId = (ticketData['attachment'] is Map ? ticketData['attachment']['id'] : null)?.toString();

    if (uploadUrl != null && uploadUrl.isNotEmpty && attId != null && attId.isNotEmpty) {
      // 2. Gửi tệp lên uploadUrl
      await Dio().put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
        ),
      );

      // 3. Hoàn tất tệp đính kèm
      await _dio.post(
        '/api/correspondence/v1/letters/${Uri.encodeComponent(letterId)}/attachments/${Uri.encodeComponent(attId)}/complete',
        data: {'sizeBytes': sizeBytes},
      );
    }
  }

  /// POST /api/correspondence/v1/catalog/quick
  Future<dynamic> quickAddCatalogItemRaw(String kind, String name) async {
    final res = await _dio.post(
      '/api/correspondence/v1/catalog/quick',
      data: {'kind': kind, 'name': name},
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/letters/:id
  Future<dynamic> getLetterRaw(String id) async {
    final res = await _dio.get(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters/:id/dispatch
  Future<dynamic> dispatchLetterRaw(String id, Map<String, dynamic> body) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}/dispatch',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters/:id/approve
  Future<dynamic> approveLetterRaw(String id, Map<String, dynamic> body) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}/approve',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters/:id/return
  Future<dynamic> returnLetterRaw(String id, Map<String, dynamic> body) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}/return',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters/:id/comments
  Future<dynamic> commentLetterRaw(String id, Map<String, dynamic> body) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}/comments',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// POST /api/correspondence/v1/letters/:id/remind
  Future<dynamic> remindLetterRaw(String id, Map<String, dynamic> body) async {
    final res = await _dio.post(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(id)}/remind',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/archive-tree
  Future<dynamic> getArchiveTreeRaw() async {
    final res = await _dio.get('/api/correspondence/v1/archive-tree');
    return res.data;
  }

  /// GET /api/correspondence/v1/letters/:letterId/attachments/:attId/download
  Future<dynamic> getAttachmentTicketRaw(String letterId, String attachmentId, {String mode = 'download'}) async {
    final res = await _dio.get(
      '/api/correspondence/v1/letters/${Uri.encodeComponent(letterId)}/attachments/${Uri.encodeComponent(attachmentId)}/download',
      queryParameters: {'mode': mode},
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/reports?year=:year
  Future<dynamic> getReportRaw(int year) async {
    final res = await _dio.get(
      '/api/correspondence/v1/reports',
      queryParameters: {'year': year},
    );
    return res.data;
  }

  /// GET /api/correspondence/v1/ledger?direction=:direction&year=:year
  Future<dynamic> getLedgerRaw(String direction, int year) async {
    final res = await _dio.get(
      '/api/correspondence/v1/ledger',
      queryParameters: {'direction': direction, 'year': year},
    );
    return res.data;
  }
}
