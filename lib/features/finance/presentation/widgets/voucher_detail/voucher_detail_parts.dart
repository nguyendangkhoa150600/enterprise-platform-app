import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../common/finance_ui.dart';

/// Trường lấy từ hồ sơ nguồn bị khoá (web `lockedLabel`): nội dung và số tiền luôn khoá khi có nguồn.
bool voucherFieldLocked(FinanceVoucherSource? source, String field) =>
    source != null && (field == 'content' || field == 'amount' || source.isLocked(field));

/// Một ô "nhãn trên, giá trị dưới" (web `Info`); rỗng thì hiện '-'.
class VoucherDetailField extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final bool locked;

  const VoucherDetailField({super.key, required this.label, this.value, this.child, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final empty = child == null && (value == null || value!.trim().isEmpty);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: FinanceColors.muted))),
              if (locked) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'finance.voucher_detail.locked_hint'.tr(),
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.lock_outline_rounded, size: 12, color: FinanceColors.faint),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          if (empty)
            const Text('-', style: TextStyle(fontSize: 13.5, color: FinanceColors.faint))
          else
            child ?? Text(value!, style: const TextStyle(fontSize: 13.5, color: FinanceColors.text)),
        ],
      ),
    );
  }
}

/// Hai ô cạnh nhau (thu gọn bố cục 3 cột của web cho màn hẹp).
class VoucherDetailFieldPair extends StatelessWidget {
  final Widget left;
  final Widget? right;
  const VoucherDetailFieldPair({super.key, required this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    );
  }
}

enum VoucherNoticeTone { warning, danger, neutral }

/// Hộp thông báo màu (amber/red/slate như web).
class VoucherDetailNotice extends StatelessWidget {
  final String text;
  final VoucherNoticeTone tone;
  const VoucherDetailNotice({super.key, required this.text, this.tone = VoucherNoticeTone.warning});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      VoucherNoticeTone.warning => (const Color(0xFFFFFBEB), const Color(0xFF92400E)),
      VoucherNoticeTone.danger => (const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
      VoucherNoticeTone.neutral => (const Color(0xFFF8FAFC), const Color(0xFF475569)),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
    );
  }
}

/// Nhãn nhỏ nền xám (Dự án / Hồ sơ / Công việc).
class VoucherDetailTag extends StatelessWidget {
  final String text;
  const VoucherDetailTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
    );
  }
}
