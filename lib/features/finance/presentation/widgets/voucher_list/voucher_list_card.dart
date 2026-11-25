import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Một dòng phiếu ở danh sách (web: các cột mặc định của bảng phiếu, dựng thành thẻ).
/// Dòng 1: mã + số tiền; dòng 2: nội dung; dòng 3: tài khoản/lý do/đối tượng/hạch toán; dòng 4: ngày · người tạo · trạng thái.
class VoucherListCard extends StatelessWidget {
  final FinanceVoucherSummary voucher;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  /// Đang ở chế độ chọn để duyệt hàng loạt.
  final bool selectionMode;
  final bool selected;
  final bool selectable;

  const VoucherListCard({
    super.key,
    required this.voucher,
    required this.onTap,
    this.onLongPress,
    this.onMore,
    this.selectionMode = false,
    this.selected = false,
    this.selectable = false,
  });

  static const _meta = TextStyle(fontSize: 12, color: FinanceColors.muted);

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final transfer = v.kind == FinanceVoucherKind.transfer;
    final details = <String>[
      if (transfer) '${v.accountName ?? ''} → ${v.destAccountName ?? ''}',
      if (!transfer) ...[
        if ((v.reasonName ?? '').isNotEmpty) v.reasonName!,
        if ((v.accountName ?? '').isNotEmpty) v.accountName!,
        if ((v.counterpartyGroupName ?? '').isNotEmpty) v.counterpartyGroupName!,
        if ((v.counterpartyName ?? '').isNotEmpty) v.counterpartyName!,
      ],
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : FinanceColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? const Color(0xFF93C5FD) : FinanceColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: selectable ? (selected ? FinanceColors.primary : FinanceColors.muted) : const Color(0xFFCBD5E1),
                    ),
                  ),
                Expanded(child: _body(details)),
                if (onMore != null && !selectionMode)
                  IconButton(
                    tooltip: 'finance.voucher_list.menu_title'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert_rounded, color: FinanceColors.muted, size: 20),
                    onPressed: onMore,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(List<String> details) {
    final v = voucher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                v.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Phiếu chưa ghi sổ chỉ có mã nháp: hiện nhạt hơn để phân biệt với mã chính thức (như web).
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: (v.officialCode ?? '').isNotEmpty ? FinanceColors.primary : FinanceColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: FinanceAmountText(amount: v.totalAmount, kind: v.kind, fontSize: 15),
              ),
            ),
          ],
        ),
        if ((v.sourceCode ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          _Tag(text: 'finance.voucher_list.from_source'.tr(args: {'code': v.sourceCode!})),
        ],
        if (v.content.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(v.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: FinanceColors.text, height: 1.3)),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: _meta),
        ],
        if (v.allocation != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.folder_outlined, size: 13, color: FinanceColors.faint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(v.allocation!.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _meta),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.event_outlined, size: 13, color: FinanceColors.faint),
            const SizedBox(width: 4),
            Text(formatFinanceDate(v.voucherDate), style: _meta),
            if ((v.createdByName ?? '').isNotEmpty) ...[
              const SizedBox(width: 10),
              const Icon(Icons.person_outline_rounded, size: 13, color: FinanceColors.faint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(v.createdByName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _meta),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 8),
            FinanceStatusBadge(status: v.status, dense: true),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9))),
      );
}
