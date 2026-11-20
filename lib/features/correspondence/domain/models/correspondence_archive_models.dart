/// Model cho một tệp trong cây lưu trữ (nằm ở kho tài liệu của Hệ dùng chung)
class ArchiveFile {
  final String id;
  final String fileName;
  final String kind;
  final String contentType;
  final int sizeBytes;
  final int versionNo;
  final String createdAt;
  final String? unitName;

  const ArchiveFile({
    required this.id,
    required this.fileName,
    required this.kind,
    required this.contentType,
    this.sizeBytes = 0,
    this.versionNo = 1,
    required this.createdAt,
    this.unitName,
  });

  factory ArchiveFile.fromJson(Map<String, dynamic> json) {
    return ArchiveFile(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'other',
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt']?.toString() ?? '',
      unitName: json['unitName']?.toString(),
    );
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get kindLabel {
    switch (kind) {
      case 'incoming':
        return 'Bản quét công văn đến';
      case 'outgoing':
        return 'Văn bản đã ban hành';
      case 'draft':
        return 'Bản dự thảo';
      case 'result':
        return 'Tệp kết quả xử lý';
      case 'reference':
        return 'Tài liệu kèm theo';
      default:
        return 'Tệp đính kèm';
    }
  }
}

/// Thư mục hồ sơ của một công văn, cùng tên với thư mục bên Hệ dùng chung
class ArchiveDossier {
  final String letterId;
  final String direction; // 'incoming' | 'outgoing'
  final String folderName;
  final String displayNo;
  final String subject;
  final String stage;
  final String stageLabel;
  final String? partner;
  final String? archiveCode;
  final String? archivedOn;
  final String receivedOn;
  final List<ArchiveFile> files;

  const ArchiveDossier({
    required this.letterId,
    required this.direction,
    required this.folderName,
    required this.displayNo,
    required this.subject,
    required this.stage,
    required this.stageLabel,
    this.partner,
    this.archiveCode,
    this.archivedOn,
    required this.receivedOn,
    this.files = const [],
  });

  factory ArchiveDossier.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List? ?? [];
    return ArchiveDossier(
      letterId: json['letterId']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'incoming',
      folderName: json['folderName']?.toString() ?? '',
      displayNo: json['displayNo']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      stageLabel: json['stageLabel']?.toString() ?? '',
      partner: json['partner']?.toString(),
      archiveCode: json['archiveCode']?.toString(),
      archivedOn: json['archivedOn']?.toString(),
      receivedOn: json['receivedOn']?.toString() ?? '',
      files: rawFiles
          .whereType<Map<String, dynamic>>()
          .map((f) => ArchiveFile.fromJson(f))
          .toList(),
    );
  }
}

/// Nhóm công văn đến / đi theo năm
class ArchiveDirectionGroup {
  final String direction; // 'incoming' | 'outgoing'
  final String label; // 'Công văn đến' | 'Công văn đi'
  final List<ArchiveDossier> dossiers;

  const ArchiveDirectionGroup({
    required this.direction,
    required this.label,
    this.dossiers = const [],
  });

  factory ArchiveDirectionGroup.fromJson(Map<String, dynamic> json) {
    final rawDossiers = json['dossiers'] as List? ?? [];
    return ArchiveDirectionGroup(
      direction: json['direction']?.toString() ?? 'incoming',
      label: json['label']?.toString() ?? '',
      dossiers: rawDossiers
          .whereType<Map<String, dynamic>>()
          .map((d) => ArchiveDossier.fromJson(d))
          .toList(),
    );
  }
}

/// Nhóm hồ sơ lưu trữ theo từng năm
class ArchiveYearGroup {
  final int year;
  final List<ArchiveDirectionGroup> groups;

  const ArchiveYearGroup({
    required this.year,
    this.groups = const [],
  });

  factory ArchiveYearGroup.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'] as List? ?? [];
    return ArchiveYearGroup(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      groups: rawGroups
          .whereType<Map<String, dynamic>>()
          .map((g) => ArchiveDirectionGroup.fromJson(g))
          .toList(),
    );
  }
}

/// Cây lưu trữ Văn thư: năm › công văn đến / đi › hồ sơ › tệp
class ArchiveTree {
  final String rootName;
  final List<ArchiveYearGroup> years;

  const ArchiveTree({
    this.rootName = 'Văn thư',
    this.years = const [],
  });

  factory ArchiveTree.fromJson(Map<String, dynamic> json) {
    final rawYears = json['years'] as List? ?? [];
    return ArchiveTree(
      rootName: json['rootName']?.toString() ?? 'Văn thư',
      years: rawYears
          .whereType<Map<String, dynamic>>()
          .map((y) => ArchiveYearGroup.fromJson(y))
          .toList(),
    );
  }

  int get totalDossiers {
    int count = 0;
    for (final year in years) {
      for (final group in year.groups) {
        count += group.dossiers.length;
      }
    }
    return count;
  }
}

/// Ticket tải về hoặc xem trước tệp đính kèm
class AttachmentTicket {
  final String downloadUrl;
  final String fileName;

  const AttachmentTicket({
    required this.downloadUrl,
    required this.fileName,
  });

  factory AttachmentTicket.fromJson(Map<String, dynamic> json) {
    return AttachmentTicket(
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
    );
  }
}
