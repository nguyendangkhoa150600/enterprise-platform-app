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
  Future<void> uploadLetterAttachment(
    String letterId,
    dynamic file,
    String kind, {
    String? assignmentId,
  });
  Future<CatalogItem> quickAddCatalogItem(String kind, String name);
  Future<LetterDetail> getLetter(String id);
  Future<LetterDetail> dispatchLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> approveLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> returnLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> sendToClerk(String id, Map<String, dynamic> body);
  Future<LetterDetail> submitLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> publishLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> completeLetter(String id, Map<String, dynamic> body);
  Future<LetterDetail> assignAssignmentHandler(String letterId, String assignmentId, String handlerUserId);
  Future<LetterDetail> respondAssignment(String letterId, String assignmentId, String note);
  Future<LetterDetail> updateDelivery(String id, Map<String, dynamic> body);
  Future<LetterDetail> requestRevoke(String id, Map<String, dynamic> body);
  Future<LetterDetail> decideRevoke(String id, {required bool approve, String? note});
  Future<LetterDetail> withdrawRevoke(String id);
  Future<void> removeLetter(String id);
  Future<void> cancelLetter(String id, String reason);
  Future<LetterDetail> commentLetter(String id, String body, {List<String> mentionedUserIds = const []});
  Future<LetterDetail> remindLetter(String id, String reason, String note);
  Future<ArchiveTree> getArchiveTree();
  Future<AttachmentTicket> getAttachmentTicket(String letterId, String attachmentId, {String mode = 'download'});
  Future<CorrespondenceReport> getReport(int year);
  Future<List<LetterSummary>> getLedger(String direction, int year);
}
