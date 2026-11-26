import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/models/correspondence_models.dart';
import 'unit_member_picker_sheet.dart';
import '../../../../../core/i18n/app_i18n.dart';

/// Card danh sách "Phòng ban xử lý" đồng bộ 1:1 với Savina Web AssignmentsSection
class LetterAssignmentsSectionView extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceDirectory directory;
  final Future<void> Function(String assignmentId, String handlerUserId)? onAssignHandler;
  final Future<void> Function(String assignmentId, String note)? onRespond;
  final Future<void> Function(String assignmentId, dynamic file)? onUploadResultFile;
  final VoidCallback? onFilesChanged;

  const LetterAssignmentsSectionView({
    super.key,
    required this.letter,
    required this.directory,
    this.onAssignHandler,
    this.onRespond,
    this.onUploadResultFile,
    this.onFilesChanged,
  });

  @override
  State<LetterAssignmentsSectionView> createState() => _LetterAssignmentsSectionViewState();
}

class _LetterAssignmentsSectionViewState extends State<LetterAssignmentsSectionView> {
  final Map<String, TextEditingController> _responseControllers = {};
  final Map<String, String> _errors = {};
  String? _busyAssignmentId;
  String? _uploadingAssignmentId;

  static Map<String, String> get _roleLabels => {
    'lead': 'correspondence.assignment.role_lead'.tr(),
    'support': 'correspondence.assignment.role_support'.tr(),
    'info': 'correspondence.assignment.role_info'.tr(),
  };

  @override
  void dispose() {
    for (final c in _responseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String id) {
    return _responseControllers.putIfAbsent(id, () => TextEditingController());
  }

  Future<void> _handlePickHandler(LetterAssignment assignment) async {
    final unit = widget.directory.units.firstWhere(
      (u) => u.id == assignment.unitId,
      orElse: () => OrgUnitModel(id: assignment.unitId, name: assignment.unitName),
    );

    final selectedUserId = await UnitMemberPickerSheet.show(
      context,
      unit: unit,
      currentHandlerUserId: assignment.handlerUserId ?? '',
    );

    if (selectedUserId != null && selectedUserId != assignment.handlerUserId && widget.onAssignHandler != null) {
      setState(() => _busyAssignmentId = assignment.id);
      try {
        await widget.onAssignHandler!(assignment.id, selectedUserId);
      } finally {
        if (mounted) setState(() => _busyAssignmentId = null);
      }
    }
  }

  Future<void> _handleSendResponse(LetterAssignment assignment) async {
    if (assignment.waitingFor.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'correspondence.assignment.wait_supporting'.tr(args: {'units': assignment.waitingFor.join(", ")}),
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final note = _getController(assignment.id).text.trim();
    if (note.isEmpty) {
      setState(() {
        _errors[assignment.id] = 'correspondence.assignment.result_required'.tr(args: {'unit': assignment.unitName});
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.assignment.result_required'.tr(args: {'unit': assignment.unitName})),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.onRespond == null) return;

    setState(() {
      _busyAssignmentId = assignment.id;
      _errors.remove(assignment.id);
    });
    try {
      await widget.onRespond!(assignment.id, note);
      _getController(assignment.id).clear();
    } catch (_) {
      // Màn cha đã báo lỗi; giữ nguyên nội dung để người dùng gửi lại.
    } finally {
      if (mounted) setState(() => _busyAssignmentId = null);
    }
  }

  Future<void> _handlePickAndUploadResult(LetterAssignment assignment) async {
    int count = 0;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'xlsx', 'xls'],
      );
      if (files.isEmpty) return;

      setState(() => _uploadingAssignmentId = assignment.id);
      for (final f in files) {
        if (widget.onUploadResultFile != null) {
          await widget.onUploadResultFile!(assignment.id, f);
          count++;
        }
      }
      if (count > 0 && mounted) {
        widget.onFilesChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('correspondence.assignment.uploaded'.tr(args: {'count': count})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        // Một số tệp có thể đã lên trước khi lỗi: vẫn làm mới để hiển thị.
        if (count > 0) widget.onFilesChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'correspondence.assignments.upload_partial'.tr(args: {'count': count})
                : 'correspondence.assignments.upload_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAssignmentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final assignments = letter.assignments;
    if (assignments.isEmpty) return const SizedBox.shrink();

    final handling = assignments.where((item) => item.role != 'info').toList();
    final done = handling.where((item) => item.status == 'submitted').length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Bộ đếm
          Row(
            children: [
              Text(
                'correspondence.assignment.section_title'.tr(),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                'correspondence.assignment.submitted_progress'.tr(args: {'done': done, 'total': handling.length}),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Chỉ đạo / Bút phê / Ghi chú khi giao (nếu có)
          if (letter.instruction != null && letter.instruction!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                letter.directive?.note == letter.instruction
                    ? 'correspondence.assignment.instruction_directive'.tr(args: {'text': letter.instruction})
                    : 'correspondence.assignment.instruction_note'.tr(args: {'text': letter.instruction}),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Danh sách từng đơn vị được giao
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assignments.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFF1F5F9),
              thickness: 1,
              height: 24,
            ),
            itemBuilder: (ctx, index) {
              final assignment = assignments[index];
              return _buildAssignmentItem(assignment);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(LetterAssignment assignment) {
    final roleLabel = _roleLabels[assignment.role] ?? assignment.role;
    final isBusy = _busyAssignmentId == assignment.id;
    final isUploading = _uploadingAssignmentId == assignment.id;
    final results = widget.letter.attachments.where((item) => item.assignmentId == assignment.id).toList();

    // Subtitle logic
    final heads = assignment.headNames.isNotEmpty
        ? assignment.headNames
        : (widget.directory.units
                .firstWhere(
                  (u) => u.id == assignment.unitId,
                  orElse: () => const OrgUnitModel(id: '', name: ''),
                )
                .members
                .where((m) => m.isHead)
                .map((m) => m.name)
                .toList());

    final hintParts = <String>[];
    if (assignment.handlerName != null && assignment.handlerName!.isNotEmpty) {
      hintParts.add('correspondence.assignment.handler'.tr(args: {'name': assignment.handlerName}));
    } else {
      hintParts.add('correspondence.assignment.whole_unit_unassigned'.tr());
    }
    if (heads.isNotEmpty) {
      hintParts.add('correspondence.assignment.heads'.tr(args: {'names': heads.join(", ")}));
    }
    if (assignment.round > 1) {
      hintParts.add('correspondence.assignment.round'.tr(args: {'round': assignment.round}));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dòng 1: Tên phòng ban + Vai trò + Tag trạng thái
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    assignment.unitName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: assignment.role == 'lead'
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: assignment.role == 'lead'
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      '• $roleLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: assignment.role == 'lead'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(assignment),
          ],
        ),

        const SizedBox(height: 5),

        // Dòng 2: Chi tiết người xử lý & Trưởng phòng
        Text(
          hintParts.join(' · '),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),

        // Dòng 3: Cảnh báo trả lại nếu có
        if (assignment.revisionReason != null &&
            assignment.revisionReason!.isNotEmpty &&
            assignment.status == 'pending') ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              'correspondence.assignment.revision'.tr(args: {'reason': assignment.revisionReason}),
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ],

        // Dòng 4: Nội dung phản hồi kết quả đã gửi
        if (assignment.responseNote != null && assignment.responseNote!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.responseNote!,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                ),
                if (assignment.submittedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'correspondence.assignment.submitted_by'.tr(args: {'name': assignment.submittedByName ?? 'correspondence.assignment.user_fallback'.tr(), 'time': CorrespondenceDateUtils.formatDateTime(assignment.submittedAt)}),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Dòng 4.5: Danh sách tệp đính kèm kết quả của phòng ban này (nếu có)
        if (results.isNotEmpty) ...[
          _buildResultAttachments(results),
        ],

        // Nút phân công người xử lý (nếu có quyền)
        if (assignment.canAssignHandler) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : () => _handlePickHandler(assignment),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
            label: Text(
              assignment.handlerName != null ? 'correspondence.assignment.change_handler'.tr() : 'correspondence.assignment.assign_handler'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],

        // Form gửi kết quả (nếu có quyền)
        if (assignment.canRespond) ...[
          const SizedBox(height: 10),
          if (assignment.waitingFor.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'correspondence.assignment.lead_wait_note'.tr(args: {'units': assignment.waitingFor.join(", ")}),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
              ),
            ),
          ],
          Text.rich(
            TextSpan(
              text: 'correspondence.assignment.result_label'.tr(args: {'unit': assignment.unitName}),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _getController(assignment.id),
            maxLines: 3,
            style: const TextStyle(fontSize: 12.5),
            onChanged: (val) {
              if (_errors.containsKey(assignment.id) && val.trim().isNotEmpty) {
                setState(() => _errors.remove(assignment.id));
              }
            },
            decoration: InputDecoration(
              hintText: 'correspondence.assignment.result_hint'.tr(),
              errorText: _errors[assignment.id],
              errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _errors.containsKey(assignment.id)
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _errors.containsKey(assignment.id)
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy || isUploading
                    ? null
                    : () => _handlePickAndUploadResult(assignment),
                icon: isUploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 15, color: Color(0xFF475569)),
                label: Text(
                  isUploading ? 'correspondence.assignment.uploading'.tr() : 'correspondence.assignment.upload_result'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isBusy || isUploading
                    ? null
                    : () => _handleSendResponse(assignment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('correspondence.assignment.submit_result'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildResultAttachments(List<LetterAttachment> files) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'correspondence.assignment.result_files'.tr(args: {'count': files.length}),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...files.map((file) {
            final isPdf = file.fileName.toLowerCase().endsWith('.pdf');
            final isWord = file.fileName.toLowerCase().endsWith('.doc') || file.fileName.toLowerCase().endsWith('.docx');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf_outlined : (isWord ? Icons.description_outlined : Icons.insert_drive_file_outlined),
                    size: 16,
                    color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (file.formattedSize.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      file.formattedSize,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LetterAssignment assignment) {
    if (assignment.role == 'info') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'correspondence.assignment.status_info'.tr(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    if (assignment.status == 'submitted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Text(
          'correspondence.assignment.status_submitted'.tr(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF15803D),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        'correspondence.assignment.status_processing'.tr(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }
}
