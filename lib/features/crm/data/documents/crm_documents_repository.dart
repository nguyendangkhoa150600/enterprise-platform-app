import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../domain/common/crm_json.dart';
import '../../domain/documents/crm_document_models.dart';
import '../crm_api_client.dart';

/// Endpoint kho tài liệu CRM (web `crm-api.ts`: documents, document-folders, document-types).
class CrmDocumentsRepository {
  CrmDocumentsRepository._();
  static final CrmDocumentsRepository instance = CrmDocumentsRepository._();

  final CrmApiClient _api = CrmApiClient.instance;
  static String _seg(String v) => CrmApiClient.seg(v);

  /// `GET /documents`: [folderId] rỗng = mọi thư mục, `root` = chỉ thư mục gốc.
  Future<List<CrmDocument>> listDocuments({
    required String entityType,
    required String entityId,
    String? folderId,
    String? documentTypeId,
    String? audience,
  }) async =>
      CrmJson.list(
        await _api.get('/documents', query: {
          'entityType': entityType,
          'entityId': entityId,
          'folderId': folderId,
          'documentTypeId': documentTypeId,
          'audience': audience,
        }),
        CrmDocument.fromJson,
      );

  Future<CrmDocument> getDocument(String id) async =>
      CrmDocument.fromJson(CrmJson.map(await _api.get('/documents/${_seg(id)}')));

  /// `POST /documents`: tạo tài liệu + xin URL ký cho phiên bản đầu.
  Future<CrmDocumentUploadTicket> createDocument({
    required String entityType,
    required String entityId,
    String? folderId,
    String? documentTypeId,
    String? name,
    String? description,
    required String audience,
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) async {
    final body = <String, dynamic>{
      'entityType': entityType,
      'entityId': entityId,
      'folderId': folderId,
      'documentTypeId': documentTypeId,
      'name': ?name,
      'description': description,
      'audience': audience,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    };
    final json = CrmJson.map(await _api.post('/documents', body));
    return CrmDocumentUploadTicket(
      documentId: CrmJson.str(CrmJson.map(json['document'])['id']),
      versionId: CrmJson.str(CrmJson.map(json['version'])['id']),
      uploadUrl: CrmJson.str(json['uploadUrl']),
    );
  }

  /// `PATCH /documents/:id`.
  Future<void> updateDocument(String id, {required String name, String? description, String? documentTypeId}) =>
      _api.patch('/documents/${_seg(id)}', {
        'name': name,
        'description': description,
        'documentTypeId': documentTypeId,
      });

  Future<void> deleteDocument(String id) => _api.delete('/documents/${_seg(id)}');

  /// `POST /documents/:id/versions`: xin URL ký cho phiên bản mới ([changeNote] bắt buộc).
  Future<CrmDocumentUploadTicket> createVersion(
    String id, {
    required String fileName,
    required String contentType,
    required int sizeBytes,
    required String changeNote,
  }) async {
    final json = CrmJson.map(await _api.post('/documents/${_seg(id)}/versions', {
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'changeNote': changeNote,
    }));
    return CrmDocumentUploadTicket(
      documentId: id,
      versionId: CrmJson.str(CrmJson.map(json['version'])['id']),
      uploadUrl: CrmJson.str(json['uploadUrl']),
    );
  }

  /// `POST /documents/:id/versions/:versionId/complete`.
  Future<void> completeUpload(String id, String versionId, int sizeBytes) =>
      _api.post('/documents/${_seg(id)}/versions/${_seg(versionId)}/complete', {'sizeBytes': sizeBytes});

  /// PUT file lên URL ký (không qua máy chủ CRM).
  Future<void> putFile(String uploadUrl, Uint8List bytes, String contentType,
          {void Function(int sent, int total)? onProgress, CancelToken? cancelToken}) =>
      _api.putSignedUrl(uploadUrl, bytes, contentType, onProgress: onProgress, cancelToken: cancelToken);

  /// `GET /documents/:id/download?version=`: URL ký ngắn hạn.
  Future<CrmDocumentDownloadTicket> download(String id, {int? version}) async =>
      CrmDocumentDownloadTicket.fromJson(
          CrmJson.map(await _api.get('/documents/${_seg(id)}/download', query: {'version': version})));

  Future<void> lock(String id) => _api.post('/documents/${_seg(id)}/lock');

  Future<void> unlock(String id) => _api.post('/documents/${_seg(id)}/unlock');

  Future<void> setAudience(String id, String audience) =>
      _api.patch('/documents/${_seg(id)}/audience', {'audience': audience});

  Future<List<CrmDocumentFolder>> listFolders(String entityType, String entityId) async => CrmJson.list(
      await _api.get('/document-folders', query: {'entityType': entityType, 'entityId': entityId}),
      CrmDocumentFolder.fromJson);

  Future<CrmDocumentFolder> createFolder({
    required String entityType,
    required String entityId,
    String? parentId,
    required String name,
  }) async =>
      CrmDocumentFolder.fromJson(CrmJson.map(await _api.post('/document-folders', {
        'entityType': entityType,
        'entityId': entityId,
        'parentId': parentId,
        'name': name,
      })));

  /// `GET /document-types` (chỉ loại đang dùng, như panel web).
  Future<List<CrmDocumentType>> listTypes() async =>
      CrmJson.list(await _api.get('/document-types'), CrmDocumentType.fromJson);
}
