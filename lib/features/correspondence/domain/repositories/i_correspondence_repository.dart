import '../models/correspondence_models.dart';

abstract class ICorrespondenceRepository {
  Future<CorrespondenceOverview> getOverview();
  Future<CorrespondenceStatus> getStatus();
  Future<List<LetterSummary>> getLetters({
    String? box,
    String? search,
    String? stage,
    String? kind,
    String? month,
    String? bookId,
  });
  Future<CorrespondenceConfig> getConfig();
  Future<CorrespondenceDirectory> getDirectory();
  Future<LetterSummary> createOutgoing(CreateOutgoingRequest request);
  Future<LetterDetail> createLetter(CreateLetterRequest request);
  Future<void> uploadLetterAttachment(String letterId, dynamic file, String kind);
  Future<CatalogItem> quickAddCatalogItem(String kind, String name);
  Future<LetterDetail> getLetter(String id);
  Future<LetterDetail> dispatchLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> approveLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> returnLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> commentLetter(String id, String body, {List<String> mentionedUserIds = const []});
  Future<LetterDetail> remindLetter(String id, String reason, String note);
  Future<ArchiveTree> getArchiveTree();
  Future<AttachmentTicket> getAttachmentTicket(String letterId, String attachmentId, {String mode = 'download'});
  Future<CorrespondenceReport> getReport(int year);
  Future<List<LetterSummary>> getLedger(String direction, int year);
}
