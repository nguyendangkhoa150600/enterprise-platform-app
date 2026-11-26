import 'package:dio/dio.dart';
import 'workspace_api_base.dart';

/// Phiên bản tài liệu (web `DocumentVersion`). `sizeBytes == null` = "Chưa tải lên xong".
class LinkedDocVersion {
  final String id;
  final int versionNo;
  final String fileName;
  final String contentType;
  final int? sizeBytes;
  final String? changeNote;
  final String? uploadedBy;
  final DateTime? createdAt;

  const LinkedDocVersion({
    required this.id,
    required this.versionNo,
    required this.fileName,
    required this.contentType,
    this.sizeBytes,
    this.changeNote,
    this.uploadedBy,
    this.createdAt,
  });

  bool get pending => sizeBytes == null;

  factory LinkedDocVersion.fromJson(Map<String, dynamic> json) => LinkedDocVersion(
        id: json['id']?.toString() ?? '',
        versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
        fileName: json['fileName']?.toString() ?? '',
        contentType: json['contentType']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
        changeNote: json['changeNote']?.toString(),
        uploadedBy: json['uploadedBy']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

/// Công việc tài liệu đang gắn (web `DocumentLinkedWorkItem`).
class LinkedDocWorkItem {
  final String id;
  final String code;
  final String title;
  const LinkedDocWorkItem({required this.id, required this.code, required this.title});
}

/// Một liên kết của tài liệu (web `DocumentLink`).
class LinkedDocLink {
  final String id;
  final String entityType;
  final String entityId;
  final DateTime? createdAt;
  const LinkedDocLink({required this.id, required this.entityType, required this.entityId, this.createdAt});
}

/// Tài liệu trong danh sách / chi tiết (web `DocumentSummary` + `DocumentDetail`).
class LinkedDoc {
  final String id;
  final String name;
  final String? description;
  final String folderId;
  final String status;
  final String audience;
  final String? createdBy;
  final String? lockedByUserId;
  final DateTime? lockedAt;
  final DateTime? updatedAt;
  final int versionCount;
  final LinkedDocVersion? currentVersion;
  final List<LinkedDocWorkItem> linkedWorkItems;
  final List<LinkedDocVersion> versions;
  final List<LinkedDocLink> links;

  const LinkedDoc({
    required this.id,
    required this.name,
    this.description,
    this.folderId = '',
    this.status = 'active',
    this.audience = 'internal',
    this.createdBy,
    this.lockedByUserId,
    this.lockedAt,
    this.updatedAt,
    this.versionCount = 1,
    this.currentVersion,
    this.linkedWorkItems = const [],
    this.versions = const [],
    this.links = const [],
  });

  factory LinkedDoc.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic raw) =>
        raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    final versions = maps(json['versions']).map(LinkedDocVersion.fromJson).toList();
    final currentId = json['currentVersionId']?.toString();
    LinkedDocVersion? current = json['currentVersion'] is Map
        ? LinkedDocVersion.fromJson(Map<String, dynamic>.from(json['currentVersion'] as Map))
        : null;
    if (current == null && versions.isNotEmpty) {
      // Như web: phiên bản hiện hành, vắng thì lấy bản số lớn nhất.
      current = versions.where((v) => v.id == currentId).firstOrNull ??
          versions.reduce((a, b) => b.versionNo > a.versionNo ? b : a);
    }
    return LinkedDoc(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      folderId: json['folderId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      audience: json['audience']?.toString() ?? 'internal',
      createdBy: json['createdBy']?.toString(),
      lockedByUserId: json['lockedByUserId']?.toString(),
      lockedAt: DateTime.tryParse(json['lockedAt']?.toString() ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
      versionCount: (json['versionCount'] as num?)?.toInt() ?? (versions.isEmpty ? 1 : versions.length),
      currentVersion: current,
      linkedWorkItems: maps(json['linkedWorkItems'])
          .map((e) => LinkedDocWorkItem(
                id: e['id']?.toString() ?? '',
                code: e['code']?.toString() ?? '',
                title: e['title']?.toString() ?? '',
              ))
          .toList(),
      versions: versions,
      links: maps(json['links'])
          .map((e) => LinkedDocLink(
                id: e['id']?.toString() ?? '',
                entityType: e['entityType']?.toString() ?? '',
                entityId: e['entityId']?.toString() ?? '',
                createdAt: DateTime.tryParse(e['createdAt']?.toString() ?? '')?.toLocal(),
              ))
          .toList(),
    );
  }

  String get fileName => currentVersion?.fileName ?? name;
  bool get pending => currentVersion?.sizeBytes == null;
}

/// Thư mục tài liệu (web `DocumentFolder`).
class LinkedDocFolder {
  final String id;
  final String name;
  final String? parentId;
  final String? projectId;
  final bool isActive;
  const LinkedDocFolder({required this.id, required this.name, this.parentId, this.projectId, this.isActive = true});

  factory LinkedDocFolder.fromJson(Map<String, dynamic> json) => LinkedDocFolder(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        parentId: json['parentId']?.toString(),
        projectId: json['projectId']?.toString(),
        isActive: json['isActive'] != false,
      );
}

/// Phiếu tải lên (web `CreateDocumentResponse`).
class LinkedDocUploadTicket {
  final String documentId;
  final String versionId;
  final String uploadUrl;
  const LinkedDocUploadTicket({required this.documentId, required this.versionId, required this.uploadUrl});
}

/// API Tài liệu của Workspace cho tab "Tài liệu" của công việc (web `workspace-api.ts` phần documents).
class WorkspaceDocumentsApi extends WorkspaceApiBase {
  static const String _r = WorkspaceApiBase.root;

  static Map<String, dynamic> _obj(dynamic data) {
    final inner = data is Map && data['data'] is Map ? data['data'] : data;
    return inner is Map ? Map<String, dynamic>.from(inner) : const {};
  }

  /// GET /documents — web `listDocuments`.
  Future<WorkspaceApiResult<List<LinkedDoc>>> listDocuments({
    String? projectId,
    String? folderId,
    String? search,
    String? linkedType,
    String? linkedId,
  }) {
    final query = <String, dynamic>{
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (folderId != null && folderId.isNotEmpty) 'folderId': folderId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (linkedType != null && linkedType.isNotEmpty) 'linkedType': linkedType,
      if (linkedId != null && linkedId.isNotEmpty) 'linkedId': linkedId,
    };
    return send('GET', '$_r/documents',
        query: query, parse: (d) => WorkspaceApiBase.itemsOf(d).map(LinkedDoc.fromJson).toList());
  }

  /// GET /folders?projectId — web `listFolders`.
  Future<WorkspaceApiResult<List<LinkedDocFolder>>> listFolders(String? projectId) => send('GET', '$_r/folders',
      query: {if (projectId != null && projectId.isNotEmpty) 'projectId': projectId},
      parse: (d) => WorkspaceApiBase.itemsOf(d).map(LinkedDocFolder.fromJson).toList());

  /// GET /documents/:id — web `getDocument`.
  Future<WorkspaceApiResult<LinkedDoc>> getDocument(String id) =>
      send('GET', '$_r/documents/$id', parse: (d) => LinkedDoc.fromJson(_obj(d)));

  /// POST /folders/ensure-path — web `ensureFolderPath`, trả về id thư mục lá.
  Future<WorkspaceApiResult<String>> ensureFolderPath({
    String? rootFolderId,
    required String projectId,
    String? workItemId,
  }) =>
      send('POST', '$_r/folders/ensure-path',
          body: {
            if (rootFolderId != null && rootFolderId.isNotEmpty) 'rootFolderId': rootFolderId,
            'projectId': projectId,
            if (workItemId != null && workItemId.isNotEmpty) 'workItemId': workItemId,
          },
          parse: (d) => _obj(d)['id']?.toString() ?? '');

  /// POST /documents — chặng 1: ghi siêu dữ liệu (kèm `linkTo`), nhận URL ký trước.
  Future<WorkspaceApiResult<LinkedDocUploadTicket>> createDocument({
    required String folderId,
    required String name,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    String? description,
    Map<String, String>? linkTo,
  }) =>
      send('POST', '$_r/documents',
          body: {
            'folderId': folderId,
            'name': name,
            'fileName': fileName,
            'contentType': contentType,
            'sizeBytes': sizeBytes,
            if (description != null && description.isNotEmpty) 'description': description,
            'linkTo': ?linkTo,
          },
          parse: (d) {
            final m = _obj(d);
            final doc = m['document'] is Map ? m['document'] as Map : const {};
            final ver = m['version'] is Map ? m['version'] as Map : const {};
            return LinkedDocUploadTicket(
              documentId: doc['id']?.toString() ?? '',
              versionId: ver['id']?.toString() ?? '',
              uploadUrl: m['uploadUrl']?.toString() ?? '',
            );
          });

  /// Chặng 2: PUT thẳng lên kho lưu trữ (URL đã ký, không kèm Authorization).
  /// Trả về mã HTTP khi thất bại, null khi thành công.
  Future<int?> uploadToStorage(String uploadUrl, List<int> bytes, String contentType) async {
    try {
      final res = await Dio().put<dynamic>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
          validateStatus: (_) => true,
        ),
      );
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300 ? null : code;
    } catch (_) {
      return 0;
    }
  }

  /// Chặng 3: POST /documents/:id/versions/:versionId/complete.
  Future<WorkspaceApiResult<bool>> completeUpload(String id, String versionId, int sizeBytes) =>
      send('POST', '$_r/documents/$id/versions/$versionId/complete',
          body: {'sizeBytes': sizeBytes}, parse: (_) => true);

  /// GET /documents/:id/download — web `getDownloadTicket` (mode `preview` để xem trước).
  Future<WorkspaceApiResult<String>> downloadUrl(String id, {String? versionId, bool preview = false}) =>
      send('GET', '$_r/documents/$id/download',
          query: {
            if (versionId != null && versionId.isNotEmpty) 'versionId': versionId,
            if (preview) 'mode': 'preview',
          },
          parse: (d) => _obj(d)['downloadUrl']?.toString() ?? '');

  /// POST /documents/:id/links — web `linkDocument`.
  Future<WorkspaceApiResult<bool>> linkDocument(String id, {required String entityType, required String entityId}) =>
      send('POST', '$_r/documents/$id/links',
          body: {'entityType': entityType, 'entityId': entityId}, parse: (_) => true);

  /// DELETE /documents/:id/links/:linkId — web `unlinkDocument`.
  Future<WorkspaceApiResult<bool>> unlinkDocument(String id, String linkId) =>
      send('DELETE', '$_r/documents/$id/links/$linkId', parse: (_) => true);

  /// POST /documents/:id/lock | /unlock — web `lockDocument` / `unlockDocument`.
  Future<WorkspaceApiResult<bool>> setLocked(String id, bool locked) =>
      send('POST', '$_r/documents/$id/${locked ? 'lock' : 'unlock'}', parse: (_) => true);

  /// DELETE /documents/:id — web `archiveDocument` (lưu trữ).
  Future<WorkspaceApiResult<bool>> archiveDocument(String id) =>
      send('DELETE', '$_r/documents/$id', parse: (_) => true);
}
