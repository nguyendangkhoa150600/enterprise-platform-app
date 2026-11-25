import 'package:flutter/material.dart';
import 'voucher_note_editor.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../common/finance_ui.dart';
import 'voucher_form_data.dart';
import 'voucher_form_fields.dart';

/// Khối "Đính kèm" (web `ui/attachments-field.tsx`): tệp đã lưu (mở/gỡ) và tệp vừa chọn chờ tải lên khi lưu.
class VoucherAttachmentsSection extends StatelessWidget {
  final List<FinanceVoucherAttachment> saved;
  final List<VoucherPendingFile> pending;
  final bool disabled;
  final VoidCallback onPick;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<FinanceVoucherAttachment> onRemoveSaved;
  final ValueChanged<FinanceVoucherAttachment> onOpenSaved;

  const VoucherAttachmentsSection({
    super.key,
    required this.saved,
    required this.pending,
    required this.disabled,
    required this.onPick,
    required this.onRemovePending,
    required this.onRemoveSaved,
    required this.onOpenSaved,
  });

  @override
  Widget build(BuildContext context) {
    final room = kVoucherMaxAttachments - saved.length - pending.length;
    return VoucherFormSection(
      title: 'finance.voucher_form.section_attachments'.tr(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: disabled || room <= 0 ? null : onPick,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text('finance.voucher_form.pick_files'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('finance.voucher_form.attach_rules'.tr(),
                style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
            if (saved.isNotEmpty || pending.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final file in saved)
                _FileRow(
                  name: file.fileName,
                  size: file.sizeBytes,
                  isLink: true,
                  disabled: disabled,
                  removeTooltip: 'finance.voucher_form.remove_saved_file'.tr(args: {'name': file.fileName}),
                  onTap: () => onOpenSaved(file),
                  onRemove: () => onRemoveSaved(file),
                ),
              for (var i = 0; i < pending.length; i++)
                _FileRow(
                  name: pending[i].name,
                  size: pending[i].size,
                  pendingNote: 'finance.voucher_form.upload_on_save'.tr(),
                  disabled: disabled,
                  removeTooltip: 'finance.voucher_form.remove_pending_file'.tr(args: {'name': pending[i].name}),
                  onRemove: () => onRemovePending(i),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String name;
  final int size;
  final bool isLink;
  final String? pendingNote;
  final bool disabled;
  final String removeTooltip;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _FileRow({
    required this.name,
    required this.size,
    required this.disabled,
    required this.removeTooltip,
    required this.onRemove,
    this.isLink = false,
    this.pendingNote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 17, color: FinanceColors.faint),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isLink ? FontWeight.w600 : FontWeight.w400,
                      color: isLink ? FinanceColors.primary : FinanceColors.text,
                    ),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      if (pendingNote != null)
                        TextSpan(text: '$pendingNote · ', style: const TextStyle(color: Color(0xFFB45309))),
                      TextSpan(text: formatVoucherBytes(size)),
                    ]),
                    style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: removeTooltip,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: const Color(0xFFDC2626),
            onPressed: disabled ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

/// Khối "Ghi chú": ô soạn thảo có định dạng như web (lưu HTML).
class VoucherNoteSection extends StatelessWidget {
  final VoucherFormData form;
  final bool enabled;

  /// Phiếu chứa ảnh của ghi chú (đang sửa, hoặc phiếu nguồn khi nhân bản).
  final String? imageVoucherId;
  const VoucherNoteSection({super.key, required this.form, required this.enabled, this.imageVoucherId});

  @override
  Widget build(BuildContext context) {
    return VoucherFormSection(
      title: 'finance.voucher_form.section_note'.tr(),
      child: VoucherNoteEditor(
        initialHtml: form.originalNoteHtml ?? '',
        enabled: enabled,
        imageVoucherId: imageVoucherId,
        onChanged: (html) => form.noteHtml = html,
      ),
    );
  }
}
