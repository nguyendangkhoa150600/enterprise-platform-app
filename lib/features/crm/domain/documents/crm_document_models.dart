import '../common/crm_json.dart';
import '../crm_capabilities.dart';

/// Kho tài liệu CRM (contracts `documents.ts`, web `documents/documents.model.ts`).
class CrmDocumentRules {
  CrmDocumentRules._();

  /// Trần dung lượng một file (contracts `CRM_DOCUMENT_MAX_BYTES`, 50 MB).
  static const int maxBytes = 50 * 1024 * 1024;

  /// Danh sách trắng loại nội dung (contracts `CRM_ALLOWED_DOCUMENT_CONTENT_TYPES`).
  static const List<String> allowedContentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/csv',
    'text/plain',
  ];

  /// Đuôi file → loại nội dung (web `CONTENT_TYPE_BY_EXTENSION`; trên máy không có `file.type` nên luôn suy từ đuôi).
  static const Map<String, String> contentTypeByExtension = {
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

  /// Đối tượng xem (contracts `CRM_DOCUMENT_AUDIENCES`).
  static const List<String> audiences = ['internal', 'customer'];

  /// Giá trị lọc thư mục "chỉ thư mục gốc" (web `FOLDER_ROOT`).
  static const String folderRoot = 'root';

  /// Web `resolveContentType`: ưu tiên [declared], thiếu thì suy từ đuôi file; không rõ → ''.
  static String resolveContentType(String fileName, [String? declared]) {
    if (declared != null && declared.isNotEmpty) return declared.toLowerCase();
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
    return contentTypeByExtension[ext] ?? '';
  }
}

/// Lỗi kiểm file trước khi xin URL ký (web `validateUploadFile`).
enum CrmUploadFileProblem { noName, empty, tooLarge, unsupported }

CrmUploadFileProblem? validateCrmUploadFile(String name, int size, [String? declaredType]) {
  if (name.trim().isEmpty) return CrmUploadFileProblem.noName;
  if (size <= 0) return CrmUploadFileProblem.empty;
  if (size > CrmDocumentRules.maxBytes) return CrmUploadFileProblem.tooLarge;
  final type = CrmDocumentRules.resolveContentType(name, declaredType);
  if (!CrmDocumentRules.allowedContentTypes.contains(type)) return CrmUploadFileProblem.unsupported;
  return null;
}

/// Loại tài liệu cấu hình theo tenant (`GET /document-types`).
class CrmDocumentType {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool active;
  final int sortOrder;

  const CrmDocumentType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.active = true,
    this.sortOrder = 0,
  });

  factory CrmDocumentType.fromJson(Map<String, dynamic> json) => CrmDocumentType(
        id: CrmJson.str(json['id']),
        code: CrmJson.str(json['code']),
        name: CrmJson.str(json['name']),
        description: CrmJson.strOrNull(json['description']),
        active: CrmJson.boolean(json['active'], true),
        sortOrder: CrmJson.integer(json['sortOrder']),
      );
}

/// Thư mục tài liệu của một đối tượng (`GET /document-folders`).
class CrmDocumentFolder {
  final String id;
  final String entityType;
  final String entityId;
  final String? parentId;
  final String name;
  final int depth;
  final String createdBy;
  final String createdAt;

  const CrmDocumentFolder({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.parentId,
    required this.name,
    this.depth = 1,
    this.createdBy = '',
    this.createdAt = '',
  });

  factory CrmDocumentFolder.fromJson(Map<String, dynamic> json) => CrmDocumentFolder(
        id: CrmJson.str(json['id']),
        entityType: CrmJson.str(json['entityType']),
        entityId: CrmJson.str(json['entityId']),
        parentId: CrmJson.strOrNull(json['parentId']),
        name: CrmJson.str(json['name']),
        depth: CrmJson.integer(json['depth'], 1),
        createdBy: CrmJson.str(json['createdBy']),
        createdAt: CrmJson.str(json['createdAt']),
      );
}

/// Lựa chọn thư mục phẳng với nhãn đường dẫn đầy đủ ("Hợp đồng / Phụ lục").
class CrmFolderOption {
  final String value;
  final String label;
  const CrmFolderOption(this.value, this.label);
}

/// Web `folderOptions`: cha trước con, anh em sắp theo tên.
List<CrmFolderOption> crmFolderOptions(List<CrmDocumentFolder> folders) {
  final ids = folders.map((f) => f.id).toSet();
  final byParent = <String?, List<CrmDocumentFolder>>{};
  for (final folder in folders) {
    final key = folder.parentId != null && ids.contains(folder.parentId) ? folder.parentId : null;
    byParent.putIfAbsent(key, () => []).add(folder);
  }
  final result = <CrmFolderOption>[];
  void walk(String? parent, String prefix) {
    final children = [...(byParent[parent] ?? const <CrmDocumentFolder>[])]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final child in children) {
      final label = prefix.isEmpty ? child.name : '$prefix / ${child.name}';
      result.add(CrmFolderOption(child.id, label));
      walk(child.id, label);
    }
  }

  walk(null, '');
  return result;
}

/// Một phiên bản file của tài liệu.
class CrmDocumentVersion {
  final String id;
  final String documentId;
  final int versionNo;
  final String fileName;
  final String contentType;
  final int? sizeBytes;
  final String? changeNote;

  /// Rỗng cho tới khi xác nhận tải lên xong.
  final String? uploadedAt;
  final String createdBy;
  final String createdAt;

  const CrmDocumentVersion({
    required this.id,
    required this.documentId,
    required this.versionNo,
    required this.fileName,
    this.contentType = '',
    this.sizeBytes,
    this.changeNote,
    this.uploadedAt,
    this.createdBy = '',
    this.createdAt = '',
  });

  factory CrmDocumentVersion.fromJson(Map<String, dynamic> json) => CrmDocumentVersion(
        id: CrmJson.str(json['id']),
        documentId: CrmJson.str(json['documentId']),
        versionNo: CrmJson.integer(json['versionNo']),
        fileName: CrmJson.str(json['fileName']),
        contentType: CrmJson.str(json['contentType']),
        sizeBytes: CrmJson.intOrNull(json['sizeBytes']),
        changeNote: CrmJson.strOrNull(json['changeNote']),
        uploadedAt: CrmJson.strOrNull(json['uploadedAt']),
        createdBy: CrmJson.str(json['createdBy']),
        createdAt: CrmJson.str(json['createdAt']),
      );
}

/// Tham chiếu loại tài liệu gắn trên tài liệu.
class CrmDocumentTypeRef {
  final String id;
  final String code;
  final String name;
  const CrmDocumentTypeRef({required this.id, required this.code, required this.name});
}

/// Tài liệu (`GET /documents`); [versions] chỉ có ở chi tiết (`GET /documents/:id`), mới nhất trước.
class CrmDocument {
  final String id;
  final String entityType;
  final String entityId;
  final String? folderId;
  final CrmDocumentTypeRef? documentType;
  final String name;
  final String? description;
  final String audience;
  final int? currentVersionNo;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final String? lockedByUserId;
  final String? lockedAt;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<CrmDocumentVersion> versions;

  const CrmDocument({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.folderId,
    this.documentType,
    required this.name,
    this.description,
    this.audience = 'internal',
    this.currentVersionNo,
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.lockedByUserId,
    this.lockedAt,
    this.createdBy = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.versions = const [],
  });

  factory CrmDocument.fromJson(Map<String, dynamic> json) {
    final type = json['documentType'];
    return CrmDocument(
      id: CrmJson.str(json['id']),
      entityType: CrmJson.str(json['entityType']),
      entityId: CrmJson.str(json['entityId']),
      folderId: CrmJson.strOrNull(json['folderId']),
      documentType: type is Map
          ? CrmDocumentTypeRef(
              id: CrmJson.str(type['id']), code: CrmJson.str(type['code']), name: CrmJson.str(type['name']))
          : null,
      name: CrmJson.str(json['name']),
      description: CrmJson.strOrNull(json['description']),
      audience: CrmJson.str(json['audience'], 'internal'),
      currentVersionNo: CrmJson.intOrNull(json['currentVersionNo']),
      fileName: CrmJson.strOrNull(json['fileName']),
      contentType: CrmJson.strOrNull(json['contentType']),
      sizeBytes: CrmJson.intOrNull(json['sizeBytes']),
      lockedByUserId: CrmJson.strOrNull(json['lockedByUserId']),
      lockedAt: CrmJson.strOrNull(json['lockedAt']),
      createdBy: CrmJson.str(json['createdBy']),
      createdAt: CrmJson.str(json['createdAt']),
      updatedAt: CrmJson.str(json['updatedAt']),
      versions: CrmJson.list(json['versions'], CrmDocumentVersion.fromJson),
    );
  }

  bool get isLocked => lockedByUserId != null;

  bool isLockedByOther(String? currentUserId) => lockedByUserId != null && lockedByUserId != currentUserId;
}

/// Nút hiện cho một tài liệu (web `documentActions`). Ẩn nút chỉ là gợi ý, máy chủ mới kiểm quyền.
/// [canWrite] = false (màn cha chỉ đọc) tắt mọi thao tác ghi/xoá.
class CrmDocumentActions {
  final bool newVersion;
  final bool edit;
  final bool lock;
  final bool unlock;
  final bool audience;
  final bool remove;

  const CrmDocumentActions._(this.newVersion, this.edit, this.lock, this.unlock, this.audience, this.remove);

  factory CrmDocumentActions.of(CrmDocument doc, CrmCapabilities caps, String? currentUserId, {bool canWrite = true}) {
    final write = caps.canWriteDocument && canWrite;
    final lockedByOther = doc.isLockedByOther(currentUserId);
    return CrmDocumentActions._(
      write && !lockedByOther,
      write && !lockedByOther,
      write && !doc.isLocked,
      write && doc.isLocked,
      write && !lockedByOther,
      caps.canDeleteDocument && canWrite && !lockedByOther,
    );
  }
}

/// Phiếu tải lên: URL ký để PUT file + id tài liệu/phiên bản cần xác nhận.
class CrmDocumentUploadTicket {
  final String documentId;
  final String versionId;
  final String uploadUrl;
  const CrmDocumentUploadTicket({required this.documentId, required this.versionId, required this.uploadUrl});
}

/// Phiếu tải xuống (`GET /documents/:id/download`).
class CrmDocumentDownloadTicket {
  final String downloadUrl;
  final String fileName;
  final String contentType;
  final int versionNo;

  const CrmDocumentDownloadTicket({
    required this.downloadUrl,
    this.fileName = '',
    this.contentType = '',
    this.versionNo = 0,
  });

  factory CrmDocumentDownloadTicket.fromJson(Map<String, dynamic> json) => CrmDocumentDownloadTicket(
        downloadUrl: CrmJson.str(json['downloadUrl']),
        fileName: CrmJson.str(json['fileName']),
        contentType: CrmJson.str(json['contentType']),
        versionNo: CrmJson.integer(json['versionNo']),
      );
}
