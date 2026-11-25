import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../../utils/finance_external_links.dart';
import '../common/finance_ui.dart';
import '../voucher_form/voucher_form_data.dart';
import 'voucher_detail_parts.dart';
import 'voucher_note_view.dart';

const _k = 'finance.voucher_detail';
const _body = TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4);
const _muted = TextStyle(fontSize: 12, color: FinanceColors.muted);

/// Khối "Đính kèm": bấm tên tệp để mở link tải tạm thời.
class VoucherAttachmentsCard extends StatelessWidget {
  final List<FinanceVoucherAttachment> attachments;
  final String? openingId;
  final ValueChanged<FinanceVoucherAttachment> onOpen;

  const VoucherAttachmentsCard({super.key, required this.attachments, required this.onOpen, this.openingId});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: '$_k.attachments'.tr(),
      child: Column(
        children: [
          for (var i = 0; i < attachments.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _row(attachments[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(FinanceVoucherAttachment file) {
    final busy = openingId == file.id;
    return InkWell(
      onTap: openingId == null ? () => onOpen(file) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 18, color: FinanceColors.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: FinanceColors.primary)),
                  Text(
                    [formatVoucherBytes(file.sizeBytes), if (file.uploadedByName != null) file.uploadedByName!].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: FinanceColors.primary))
                : const Icon(Icons.download_rounded, size: 20, color: FinanceColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Khối "Liên quan" (web `RelatedPanel`): dự án hạch toán, hồ sơ quy trình, công việc Workspace.
/// Trả về khung rỗng khi không có gì.
class VoucherRelatedCard extends StatelessWidget {
  final FinanceVoucher voucher;
  const VoucherRelatedCard({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final src = v.source;
    final proc = v.procedure;
    ({String id, String code, String? title, String? detail})? dossier;
    if (src?.instanceId != null) {
      dossier = (id: src!.instanceId!, code: src.instanceCode, title: src.instanceTitle, detail: src.definitionName);
    } else if (proc?.instanceId != null) {
      dossier = (
        id: proc!.instanceId!,
        code: proc.instanceCode ?? proc.instanceId!,
        title: null,
        detail: proc.currentStepName,
      );
    }
    final item = v.linkedWorkItem;
    if (v.allocation == null && dossier == null && item == null) return const SizedBox.shrink();
    final statusKey = '$_k.related.work_${item?.status.toLowerCase()}';
    final statusText = item == null ? '' : (statusKey.tr() == statusKey ? item.status : statusKey.tr());
    return FinanceCard(
      title: '$_k.related.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web: dự án và công việc mở trang dự án Workspace; hồ sơ mở hồ sơ quy trình.
          if (v.allocation != null)
            _row('$_k.related.project'.tr(), v.allocation!.label, null, '$_k.related.allocation_hint'.tr(),
                () => FinanceExternalLinks.openWorkspaceProject(context, v.allocation!.projectId)),
          if (dossier != null)
            _row('$_k.related.dossier'.tr(), dossier.code, dossier.title,
                dossier.detail != null && dossier.detail!.isNotEmpty ? '(${dossier.detail})' : null,
                () => FinanceExternalLinks.openProcedureInstance(context, dossier!.id)),
          if (item != null)
            _row('$_k.related.work_item'.tr(), '${item.code} - ${item.title}', null, statusText,
                () => FinanceExternalLinks.openWorkspaceProject(context, item.projectId)),
        ],
      ),
    );
  }

  Widget _row(String tag, String main, String? extra, String? hint, VoidCallback onOpen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoucherDetailTag(tag),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: main,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF1D4ED8),
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onOpen,
                ),
                if (extra != null && extra.isNotEmpty) TextSpan(text: ' $extra'),
                if (hint != null && hint.isNotEmpty) TextSpan(text: ' $hint', style: _muted),
              ]),
              style: _body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khối "Ghi chú" và "Đối tượng liên quan" (dự án chỉ để tham chiếu).
class VoucherNoteCard extends StatelessWidget {
  final FinanceVoucher voucher;
  const VoucherNoteCard({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    // Web: hiện khi có ghi chú (kể cả chỉ có ảnh) hoặc có dự án liên quan.
    final note = voucher.note ?? '';
    final projects = voucher.relatedProjects;
    if (note.isEmpty && projects.isEmpty) return const SizedBox.shrink();
    const heading = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: FinanceColors.text);
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note.isNotEmpty) ...[
            Text('common.note'.tr(), style: heading),
            const SizedBox(height: 6),
            VoucherNoteView(voucherId: voucher.id, html: note),
          ],
          if (projects.isNotEmpty) ...[
            if (note.isNotEmpty) const SizedBox(height: 12),
            Text('$_k.related_projects'.tr(), style: heading),
            const SizedBox(height: 6),
            for (final p in projects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${p.label}', style: _body),
              ),
          ],
        ],
      ),
    );
  }
}

/// Khối "Lịch sử xử lý": dòng thời gian sự kiện.
class VoucherHistoryCard extends StatelessWidget {
  final List<FinanceVoucherEvent> events;
  const VoucherHistoryCard({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: '$_k.history'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in events)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFA7F3D0), width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(financeEventLabel(e.action),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: FinanceColors.text)),
                  const SizedBox(height: 2),
                  Text('${e.actorName ?? '$_k.system'.tr()} · ${formatFinanceDateTime(e.createdAt)}', style: _muted),
                  if (e.note != null && e.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(e.note!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
