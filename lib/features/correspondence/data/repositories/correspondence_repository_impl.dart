import 'package:dio/dio.dart';
import '../../domain/errors/correspondence_exception.dart';
import '../../domain/models/correspondence_models.dart';
import '../../domain/repositories/i_correspondence_repository.dart';
import '../datasources/correspondence_error_mapper.dart';
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
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
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
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
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
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> createLetter(CreateLetterRequest request) async {
    try {
      final data = await _remoteDataSource.createLetterRaw(request.toJson());
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<void> uploadLetterAttachment(
    String letterId,
    dynamic file,
    String kind, {
    String? assignmentId,
  }) async {
    // Không nuốt lỗi: nơi gọi cần biết để báo người dùng tải lên thất bại.
    try {
      await _remoteDataSource.uploadAttachmentRaw(
        letterId,
        file,
        kind,
        assignmentId: assignmentId,
      );
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<CatalogItem> quickAddCatalogItem(String kind, String name) async {
    try {
      final data = await _remoteDataSource.quickAddCatalogItemRaw(kind, name);
      if (data is Map<String, dynamic>) {
        return CatalogItem.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> getLetter(String id) async {
    try {
      final data = await _remoteDataSource.getLetterRaw(id);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> dispatchLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.dispatchLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> approveLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.approveLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> returnLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.returnLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> sendToClerk(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.sendToClerkRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> submitLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.submitLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> publishLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.publishLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> completeLetter(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.completeLetterRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> assignAssignmentHandler(String letterId, String assignmentId, String handlerUserId) async {
    try {
      final data = await _remoteDataSource.assignAssignmentHandlerRaw(letterId, assignmentId, handlerUserId);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> respondAssignment(String letterId, String assignmentId, String note) async {
    try {
      final data = await _remoteDataSource.respondAssignmentRaw(letterId, assignmentId, note);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> updateDelivery(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.updateDeliveryRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> requestRevoke(String id, Map<String, dynamic> body) async {
    try {
      final data = await _remoteDataSource.requestRevokeRaw(id, body);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> decideRevoke(String id, {required bool approve, String? note}) async {
    try {
      final data = await _remoteDataSource.decideRevokeRaw(id, {
        'approve': approve,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> withdrawRevoke(String id) async {
    try {
      final data = await _remoteDataSource.withdrawRevokeRaw(id);
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<void> removeLetter(String id) async {
    try {
      await _remoteDataSource.removeLetterRaw(id);
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<void> cancelLetter(String id, String reason) async {
    try {
      await _remoteDataSource.cancelLetterRaw(id, reason);
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
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
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<LetterDetail> remindLetter(String id, String reason, String note) async {
    try {
      final data = await _remoteDataSource.remindLetterRaw(id, {'reason': reason, 'note': note});
      if (data is Map<String, dynamic>) {
        return LetterDetail.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<ArchiveTree> getArchiveTree() async {
    try {
      final data = await _remoteDataSource.getArchiveTreeRaw();
      if (data is Map<String, dynamic>) {
        return ArchiveTree.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<AttachmentTicket> getAttachmentTicket(String letterId, String attachmentId, {String mode = 'download'}) async {
    try {
      final data = await _remoteDataSource.getAttachmentTicketRaw(letterId, attachmentId, mode: mode);
      if (data is Map<String, dynamic>) {
        return AttachmentTicket.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }

  @override
  Future<CorrespondenceReport> getReport(int year) async {
    try {
      final data = await _remoteDataSource.getReportRaw(year);
      if (data is Map<String, dynamic>) {
        return CorrespondenceReport.fromJson(data);
      }
      throw const CorrespondenceException();
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
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
    } on DioException catch (e) {
      throw mapCorrespondenceDioError(e);
    }
  }
}
