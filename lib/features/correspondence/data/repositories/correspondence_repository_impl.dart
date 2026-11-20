import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../datasources/correspondence_remote_datasource.dart';

class CorrespondenceRepositoryImpl implements ICorrespondenceRepository {
  final CorrespondenceRemoteDataSource _remoteDataSource;

  CorrespondenceRepositoryImpl({CorrespondenceRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CorrespondenceRemoteDataSource();

  @override
  Future<CorrespondenceOverview> getOverview() async {
    try {
      final data = await _remoteDataSource.getOverviewRaw();
      if (data is Map<String, dynamic>) {
        return CorrespondenceOverview.fromJson(data);
      }
      return const CorrespondenceOverview();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CorrespondenceStatus> getStatus() async {
    try {
      final data = await _remoteDataSource.getStatusRaw();
      if (data is Map<String, dynamic>) {
        return CorrespondenceStatus.fromJson(data);
      }
      return const CorrespondenceStatus();
    } catch (_) {
      return const CorrespondenceStatus();
    }
  }

  @override
  Future<List<LetterSummary>> getLetters({
    String? box,
    String? search,
    String? stage,
    String? kind,
    String? month,
    String? bookId,
  }) async {
    try {
      final data = await _remoteDataSource.getLettersRaw(
        box: box,
        search: search,
        stage: stage,
        kind: kind,
        month: month,
        bookId: bookId,
      );
      if (data is Map<String, dynamic> && data['items'] is List) {
        final list = data['items'] as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => LetterSummary.fromJson(e))
            .toList();
      } else if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => LetterSummary.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CorrespondenceConfig> getConfig() async {
    try {
      final data = await _remoteDataSource.getConfigRaw();
      if (data is Map<String, dynamic>) {
        return CorrespondenceConfig.fromJson(data);
      }
      return const CorrespondenceConfig();
    } catch (_) {
      return const CorrespondenceConfig();
    }
  }

  @override
  Future<CorrespondenceDirectory> getDirectory() async {
    try {
      final data = await _remoteDataSource.getDirectoryRaw();
      if (data is Map<String, dynamic>) {
        return CorrespondenceDirectory.fromJson(data);
      }
      return const CorrespondenceDirectory();
    } catch (_) {
      return const CorrespondenceDirectory();
    }
  }

  @override
  Future<LetterSummary> createOutgoing(CreateOutgoingRequest request) async {
    try {
      final data = await _remoteDataSource.createOutgoingRaw(request.toJson());
      if (data is Map<String, dynamic>) {
        return LetterSummary.fromJson(data);
      }
      throw Exception('Phản hồi không hợp lệ từ máy chủ.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> createLetter(CreateLetterRequest request) async {
    try {
      final data = await _remoteDataSource.createLetterRaw(request.toJson());
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Phản hồi không hợp lệ từ máy chủ.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> uploadLetterAttachment(String letterId, dynamic file, String kind) async {
    try {
      await _remoteDataSource.uploadAttachmentRaw(letterId, file, kind);
    } catch (_) {}
  }

  @override
  Future<CatalogItem> quickAddCatalogItem(String kind, String name) async {
    try {
      final data = await _remoteDataSource.quickAddCatalogItemRaw(kind, name);
      if (data is Map<String, dynamic>) {
        return CatalogItem.fromJson(data);
      }
      throw Exception('Không tạo được danh mục.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> getLetter(String id) async {
    try {
      final data = await _remoteDataSource.getLetterRaw(id);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không tìm thấy thông tin công văn.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> dispatchLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.dispatchLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không phân loại được công văn.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> approveLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.approveLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không duyệt được công văn.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> returnLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.returnLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không trả lại được công văn.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> commentLetter(String id, String body, {List<String> mentionedUserIds = const []}) async {
    try {
      final payload = <String, dynamic>{
        'body': body,
        if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      };
      final data = await _remoteDataSource.commentLetterRaw(id, payload);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không gửi được ý kiến trao đổi.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<LetterDetail> remindLetter(String id, String reason, String note) async {
    try {
      final data = await _remoteDataSource.remindLetterRaw(id, {'reason': reason, 'note': note});
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw Exception('Không gửi được nhắc nhở đôn đốc.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ArchiveTree> getArchiveTree() async {
    try {
      final data = await _remoteDataSource.getArchiveTreeRaw();
      if (data is Map<String, dynamic>) {
        return ArchiveTree.fromJson(data);
      }
      throw Exception('Không tải được cây lưu trữ.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AttachmentTicket> getAttachmentTicket(String letterId, String attachmentId, {String mode = 'download'}) async {
    try {
      final data = await _remoteDataSource.getAttachmentTicketRaw(letterId, attachmentId, mode: mode);
      if (data is Map<String, dynamic>) {
        return AttachmentTicket.fromJson(data);
      }
      throw Exception('Không lấy được liên kết tải tệp.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CorrespondenceReport> getReport(int year) async {
    try {
      final data = await _remoteDataSource.getReportRaw(year);
      if (data is Map<String, dynamic>) {
        return CorrespondenceReport.fromJson(data);
      }
      throw Exception('Không tải được số liệu báo cáo.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<LetterSummary>> getLedger(String direction, int year) async {
    try {
      final data = await _remoteDataSource.getLedgerRaw(direction, year);
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List? ?? [];
        return items
            .whereType<Map<String, dynamic>>()
            .map((item) => LetterSummary.fromJson(item))
            .toList();
      }
      return const [];
    } catch (e) {
      rethrow;
    }
  }
}
