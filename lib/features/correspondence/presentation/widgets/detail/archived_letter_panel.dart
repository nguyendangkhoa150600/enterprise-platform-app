import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/correspondence_models.dart';
import 'revoke_request_dialog.dart';

/// Panel "Hồ sơ đã lưu trữ" đồng bộ 1:1 với Savina Web ArchivedPanel
class ArchivedLetterPanel extends StatefulWidget {
  final LetterDetail letter;
  final Future<void> Function(Map<String, dynamic> body) onUpdateDelivery;
  final Future<void> Function(Map<String, dynamic> body) onRequestRevoke;

  const ArchivedLetterPanel({
    super.key,
    required this.letter,
    required this.onUpdateDelivery,
    required this.onRequestRevoke,
  });

  @override
  State<ArchivedLetterPanel> createState() => _ArchivedLetterPanelState();
}

class _ArchivedLetterPanelState extends State<ArchivedLetterPanel> {
  static Map<String, String> get _deliveryStatusLabels => {
    'sent': 'correspondence.panel.archived.status_sent'.tr(),
    'pending': 'correspondence.panel.archived.status_pending'.tr(),
    'received': 'correspondence.panel.archived.status_received'.tr(),
    'returned': 'correspondence.panel.archived.status_returned'.tr(),
  };

  late String _status;
  late String _deliveredOn;
  final TextEditingController _noteController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _status = widget.letter.deliveryStatus ?? 'sent';
    _deliveredOn = widget.letter.deliveredOn ?? CorrespondenceDateUtils.localToday();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateDelivery() async {
    setState(() => _isUpdating = true);
    try {
      await widget.onUpdateDelivery({
        'status': _status,
        'deliveredOn': _deliveredOn,
        if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
      });
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleRequestRevoke() async {
    final result = await RevokeRequestDialog.show(context, letter: widget.letter);
    if (result != null) {
      setState(() => _isUpdating = true);
      try {
        await widget.onRequestRevoke(result);
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final actions = letter.actions;

    final buffer = StringBuffer();
    if (letter.archiveCode != null && letter.archiveCode!.isNotEmpty) {
      buffer.write('correspondence.panel.archived.summary_code'.tr(args: {'code': letter.archiveCode, 'date': CorrespondenceDateUtils.formatDay(letter.archivedOn)}));
    } else {
      buffer.write('correspondence.panel.archived.summary_done'.tr());
    }
    if (letter.outgoingNo != null && letter.outgoingNo!.isNotEmpty) {
      buffer.write(' ${'correspondence.panel.archived.summary_issued'.tr(args: {'no': letter.outgoingNo, 'date': CorrespondenceDateUtils.formatDay(letter.publishedOn), 'recipient': letter.recipient ?? ''})}');
    }
    if (letter.completionNote != null && letter.completionNote!.isNotEmpty) {
      buffer.write(' ${letter.completionNote}.');
    }
    buffer.write(' ${'correspondence.panel.archived.summary_files'.tr()}');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
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
          // Tiêu đề card màu xanh lá
          Text(
            'correspondence.panel.archived.title'.tr(),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 8),

          // Đoạn text thông tin lưu trữ khớp 1:1 Web
          Text(
            buffer.toString(),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
          ),

          // Form cập nhật tình trạng gửi nếu có quyền updateDelivery
          if (actions.updateDelivery) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tình trạng gửi
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'correspondence.panel.archived.delivery_status'.tr(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _status,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                            items: _deliveryStatusLabels.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Ngày gửi
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'correspondence.panel.archived.date'.tr(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _deliveredOn = CorrespondenceDateUtils.localToday(picked));
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                CorrespondenceDateUtils.formatDay(_deliveredOn),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                              ),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Ghi chú gửi
            Text(
              'common.note'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'correspondence.panel.note_hint'.tr(),
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),

            // Nút Cập nhật tình trạng gửi
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _isUpdating ? null : _handleUpdateDelivery,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isUpdating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('correspondence.panel.archived.update_delivery'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else if (letter.deliveryStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              'correspondence.panel.archived.delivery_status_inline'.tr(args: {
                'status': _deliveryStatusLabels[letter.deliveryStatus] ?? letter.deliveryStatus!,
                'date': letter.deliveredOn != null ? ' · ${CorrespondenceDateUtils.formatDay(letter.deliveredOn)}' : '',
              }),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],

          // Nút Đề nghị huỷ công văn
          if (actions.requestRevoke) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _handleRequestRevoke,
                icon: const Icon(Icons.shield_outlined, size: 15, color: Color(0xFFDC2626)),
                label: Text(
                  'correspondence.revoke.title'.tr(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
