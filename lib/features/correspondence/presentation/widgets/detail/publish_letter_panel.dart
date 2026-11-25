import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../domain/models/correspondence_models.dart';
import 'internal_units_picker.dart';
import 'letter_action_buttons.dart';
import '../dialogs/return_letter_dialog.dart';

/// Panel "Văn thư ban hành, lưu trữ" công văn đi đồng bộ 1:1 với Savina Web PublishForm
class PublishLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final CorrespondenceConfig config;
  final CorrespondenceDirectory directory;
  final Future<void> Function(Map<String, dynamic> body) onPublish;
  final Future<void> Function(Map<String, dynamic> body) onReturn;

  const PublishLetterPanel({
    super.key,
    required this.letter,
    required this.config,
    required this.directory,
    required this.onPublish,
    required this.onReturn,
  });

  @override
  State<PublishLetterPanel> createState() => _PublishLetterPanelState();
}

class _PublishLetterPanelState extends State<PublishLetterPanel> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _deliveryMethodController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _signerTitleController = TextEditingController();
  final TextEditingController _copyCountController = TextEditingController();

  late String _publishedOn;
  String _signerUserId = '';
  String _registerId = '';
  final List<String> _internalUnitIds = [];
  bool _isSubmitting = false;
  String? _recipientError;

  @override
  void initState() {
    super.initState();
    _recipientController.text = widget.letter.recipient ?? '';
    _publishedOn = widget.letter.publishedOn ?? CorrespondenceDateUtils.localToday();
    _copyCountController.text = widget.letter.copyCount != null ? '${widget.letter.copyCount}' : '';

    // Người ký mặc định là người duyệt bước duyệt cuối; chức vụ theo sơ đồ tổ chức
    _signerUserId = _findLastApprover();
    final defaultTitle = _titleOf(_signerUserId);
    _signerTitleController.text = widget.letter.signerTitle ?? defaultTitle;

    // Sổ đăng ký cấp số đi
    final outgoingRegisters = widget.config.books.where((b) => b.isActive && b.direction == 'outgoing').toList();
    final autoRegister = outgoingRegisters.where((b) => b.confidential == widget.letter.restricted).firstOrNull ?? outgoingRegisters.firstOrNull;
    _registerId = autoRegister?.id ?? '';
  }

  String _findLastApprover() {
    for (final step in widget.letter.steps.reversed) {
      final isApprove = step.type == 'approve' || step.name.toLowerCase().contains('duyệt');
      if (isApprove && step.status == 'done') {
        if (step.actedBy != null && step.actedBy!.isNotEmpty) {
          return step.actedBy!;
        }
        if (step.actedByName != null && step.actedByName!.isNotEmpty) {
          final found = widget.directory.people.where((p) => p.name == step.actedByName).firstOrNull;
          if (found != null) return found.userId;
        }
      }
    }
    return '';
  }

  String _titleOf(String userId) {
    if (userId.isEmpty) return '';
    for (final unit in widget.directory.units) {
      for (final member in unit.members) {
        if (member.userId == userId && member.positionName != null && member.positionName!.isNotEmpty) {
          return member.positionName!;
        }
      }
    }
    return '';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _deliveryMethodController.dispose();
    _noteController.dispose();
    _signerTitleController.dispose();
    _copyCountController.dispose();
    super.dispose();
  }

  Future<void> _handleReturn() async {
    // Nơi trả về, bước, phòng ban làm lại và lý do: chọn trong hộp thoại dùng chung (như web).
    final body = await ReturnLetterDialog.show(context, widget.letter);
    if (body == null || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onReturn(body);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPublish() async {
    if (_recipientController.text.trim().isEmpty) {
      setState(() => _recipientError = 'correspondence.panel.publish.recipient_required'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('correspondence.panel.publish.recipient_required'.tr()),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _recipientError = null;
    });
    try {
      final payload = <String, dynamic>{
        'recipient': _recipientController.text.trim(),
        'publishedOn': _publishedOn,
        if (_deliveryMethodController.text.trim().isNotEmpty)
          'deliveryMethod': _deliveryMethodController.text.trim(),
        if (_noteController.text.trim().isNotEmpty)
          'note': _noteController.text.trim(),
        if (_signerUserId.isNotEmpty) 'signerUserId': _signerUserId,
        if (_signerTitleController.text.trim().isNotEmpty)
          'signerTitle': _signerTitleController.text.trim(),
        if (_copyCountController.text.trim().isNotEmpty)
          'copyCount': int.tryParse(_copyCountController.text.trim()),
        if (_registerId.isNotEmpty) 'registerId': _registerId,
        if (_internalUnitIds.isNotEmpty) 'internalUnitIds': _internalUnitIds,
      };
      await widget.onPublish(payload);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.letter.flow.isNotEmpty ? widget.letter.flow.last.label : 'correspondence.workflow.end_outgoing'.tr();
    final hasSignedAttachment = widget.letter.attachments.any((a) => a.kind == 'outgoing');
    final outgoingRegisters = widget.config.books.where((b) => b.isActive && b.direction == 'outgoing').toList();
    final autoRegister = outgoingRegisters.where((b) => b.confidential == widget.letter.restricted).firstOrNull ?? outgoingRegisters.firstOrNull;

    final selectedSigner = widget.directory.people.where((p) => p.userId == _signerUserId).firstOrNull;
    final selectedRegister = outgoingRegisters.where((b) => b.id == _registerId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
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
          // Tiêu đề bước
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),

          // Cảnh báo nếu chưa có bản ký
          if (!hasSignedAttachment)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'correspondence.panel.publish.no_signed_copy'.tr(),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),

          // 1. Nơi nhận & Ngày ban hành
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'correspondence.panel.publish.recipient_label'.tr(),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        children: const [
                          TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _recipientController,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (val) {
                        if (_recipientError != null && val.trim().isNotEmpty) {
                          setState(() => _recipientError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'correspondence.panel.publish.recipient_hint'.tr(),
                        errorText: _recipientError,
                        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _recipientError != null ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _recipientError != null ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'correspondence.panel.publish.issue_date'.tr(),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _publishedOn = CorrespondenceDateUtils.localToday(picked));
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CorrespondenceDateUtils.formatDay(_publishedOn),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Hình thức gửi & Ghi chú
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('correspondence.panel.publish.delivery_method'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _deliveryMethodController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'correspondence.panel.publish.delivery_method_hint'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('common.note'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'correspondence.panel.note_hint'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Người ký, Chức vụ người ký, Số bản
          Text('correspondence.panel.publish.signer'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          SearchableDropdownField<CorrespondencePerson>(
            value: selectedSigner,
            items: widget.directory.people,
            itemLabel: (p) => p.name,
            hintText: 'correspondence.panel.publish.signer_hint'.tr(),
            icon: Icons.person_outline,
            showClear: true,
            onChanged: (person) {
              setState(() {
                _signerUserId = person.userId;
                final title = _titleOf(person.userId);
                if (title.isNotEmpty) {
                  _signerTitleController.text = title;
                }
              });
            },
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('correspondence.panel.publish.signer_position'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _signerTitleController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'correspondence.panel.publish.signer_position_hint'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('correspondence.panel.publish.copies'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _copyCountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Sổ đăng ký (cấp số đi) nếu có từ 2 sổ trở lên
          if (outgoingRegisters.length > 1) ...[
            Text('correspondence.panel.publish.register'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            SearchableDropdownField<RegisterBookModel>(
              value: selectedRegister,
              items: outgoingRegisters,
              itemLabel: (b) => b.name,
              hintText: autoRegister != null ? 'correspondence.panel.publish.register_auto'.tr(args: {'name': autoRegister.name}) : 'correspondence.panel.publish.register_auto_hint'.tr(),
              icon: Icons.menu_book_outlined,
              showClear: true,
              onChanged: (book) {
                setState(() => _registerId = book.id);
              },
            ),
            const SizedBox(height: 12),
          ],

          // 5. Phòng ban nhận nội bộ
          InternalUnitsPicker(
            directoryUnits: widget.directory.units,
            internalUnitIds: _internalUnitIds,
            onChanged: (updated) => setState(() {
              _internalUnitIds.clear();
              _internalUnitIds.addAll(updated);
            }),
          ),
          const SizedBox(height: 16),

          // 6. Action buttons
          LetterActionButtons(
            returnButton: widget.letter.actions.returnTargets.isNotEmpty
                ? OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleReturn,
                    icon: const Icon(Icons.undo_rounded, size: 15, color: Color(0xFFD97706)),
                    label: Text('correspondence.panel.reject_return'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  )
                : null,
            primaryButton: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('correspondence.panel.publish.submit'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
