import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_finance_api.dart';
import 'finance_format.dart';
import 'finance_summary.dart';

/// Bộ lọc sổ chứng từ (như `ProjectVoucherFilter`); 'all' là không lọc.
class VoucherFilter {
  final String kind;
  final String link;
  final String status;

  const VoucherFilter({this.kind = 'all', this.link = 'all', this.status = 'all'});

  static const none = VoucherFilter();

  int get facets => [kind, link, status].where((v) => v != 'all').length;

  VoucherFilter copyWith({String? kind, String? link, String? status}) =>
      VoucherFilter(kind: kind ?? this.kind, link: link ?? this.link, status: status ?? this.status);

  bool matches(ProjectVoucher v) =>
      (kind == 'all' || v.kind == kind) && (link == 'all' || v.link == link) && (status == 'all' || v.status == status);
}

String voucherKindLabel(String kind) =>
    (kind == 'RECEIPT' ? 'workspace.finance.kind_receipt' : 'workspace.finance.kind_payment').tr();

String voucherStatusLabel(String status) => switch (status) {
      'APPROVED' => 'workspace.finance.status_approved'.tr(),
      'PENDING' => 'workspace.finance.status_pending'.tr(),
      _ => 'workspace.finance.status_draft'.tr(),
    };

/// Màu nhãn trạng thái phiếu (như `PROJECT_VOUCHER_STATUS_TONE`).
(Color, Color) _statusTone(String status) => switch (status) {
      'APPROVED' => (const Color(0x2610B981), const Color(0xFF047857)),
      'PENDING' => (const Color(0x2EF59E0B), const Color(0xFF92400E)),
      _ => (const Color(0x263B82F6), const Color(0xFF1D4ED8)),
    };

/// Thẻ "Sổ chứng từ": dòng tổng, danh sách phiếu (mỗi phiếu một thẻ thay cho một hàng bảng), chú thích chân.
class FinanceLedger extends StatelessWidget {
  final ProjectVoucherList data;
  final VoucherFilter filter;
  final VoidCallback onOpenFilter;

  /// Bấm một phiếu: mở chi tiết phiếu bên Tài chính (web mở `/modules/finance/...`).
  final ValueChanged<ProjectVoucher>? onOpenVoucher;

  const FinanceLedger({
    super.key,
    required this.data,
    required this.filter,
    required this.onOpenFilter,
    this.onOpenVoucher,
  });

  @override
  Widget build(BuildContext context) {
    final visible = data.items.where(filter.matches).toList();
    final muted = Theme.of(context).hintColor;
    final net = data.totals.received - data.totals.paid;
    final facets = filter.facets;

    return Container(
      decoration: financeCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text('workspace.finance.ledger'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 6),
                _Badge('${data.items.length}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onOpenFilter,
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('common.filter'.tr()),
                    if (facets > 0) ...[const SizedBox(width: 4), _Badge('$facets')],
                  ]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (data.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('workspace.finance.total'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  _Amount('workspace.finance.col_receipt'.tr(), formatVnd(data.totals.received), bold: true),
                  _Amount('workspace.finance.col_payment'.tr(), formatVnd(data.totals.paid), bold: true),
                  _Amount('workspace.finance.col_balance'.tr(), formatVnd(net), bold: true, color: net < 0 ? financeNegative : null),
                ],
              ),
            ),
          if (data.items.isNotEmpty) const Divider(height: 1),
          if (data.items.isEmpty)
            _Muted('workspace.finance.empty'.tr())
          else if (visible.isEmpty)
            _Muted('workspace.finance.no_match'.tr())
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _VoucherRow(index: i + 1, voucher: visible[i], onTap: onOpenVoucher),
            ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              (data.truncated ? 'workspace.finance.footer_truncated' : 'workspace.finance.footer_note').tr(),
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  final int index;
  final ProjectVoucher voucher;
  final ValueChanged<ProjectVoucher>? onTap;

  const _VoucherRow({required this.index, required this.voucher, this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final v = voucher;
    // Phiếu chờ/chỉ liên quan chưa phải tiền của dự án: số mờ đi và không có dòng tiền.
    final amountColor = v.settled ? null : muted;
    final sub = [
      if (v.reasonName != null) v.reasonName!,
      if (v.link == 'RELATED') 'workspace.finance.related_only'.tr(),
    ].join(' · ');
    final (bg, fg) = _statusTone(v.status);
    final balance = v.balance;

    final row = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$index. ', style: TextStyle(color: muted, fontSize: 13)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.content, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11, color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Text(voucherStatusLabel(v.status), style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${v.code} · ${voucherKindLabel(v.kind)}', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              _Amount('workspace.finance.col_created_by'.tr(), v.createdByName ?? '—'),
              _Amount('workspace.finance.col_created_at'.tr(), formatDay(v.createdAt)),
              _Amount('workspace.finance.col_posting_date'.tr(), formatDay(v.postingDate)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              _Amount(
                (v.isReceipt ? 'workspace.finance.col_receipt' : 'workspace.finance.col_payment').tr(),
                formatVnd(v.totalAmount),
                color: amountColor,
                bold: v.settled,
              ),
              _Amount(
                'workspace.finance.col_balance'.tr(),
                balance == null ? '--' : formatVnd(balance),
                color: balance != null && balance < 0 ? financeNegative : null,
              ),
            ],
          ),
        ],
      ),
    );
    final open = onTap;
    return open == null ? row : InkWell(onTap: () => open(v), child: row);
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _Amount(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Theme.of(context).hintColor)),
            TextSpan(text: value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null)),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _Muted extends StatelessWidget {
  final String text;
  const _Muted(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
      );
}

/// Bảng lọc phiếu thu chi (bottom sheet thay cho panel thả xuống của web). Đổi là áp dụng ngay như web.
Future<void> showVoucherFilterSheet(
  BuildContext context, {
  required VoucherFilter initial,
  required ValueChanged<VoucherFilter> onChanged,
}) {
  var filter = initial;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheet) {
        void update(VoucherFilter next) {
          setSheet(() => filter = next);
          onChanged(next);
        }

        Widget field(String label, String value, Map<String, String> options, ValueChanged<String> pick) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
                items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => v == null ? null : pick(v),
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('workspace.finance.filter_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                field('workspace.finance.filter_kind'.tr(), filter.kind, {
                  'all': 'workspace.finance.kind_all'.tr(),
                  'RECEIPT': 'workspace.finance.kind_receipt'.tr(),
                  'PAYMENT': 'workspace.finance.kind_payment'.tr(),
                }, (v) => update(filter.copyWith(kind: v))),
                field('workspace.finance.filter_link'.tr(), filter.link, {
                  'all': 'workspace.finance.link_all'.tr(),
                  'ALLOCATION': 'workspace.finance.link_allocation'.tr(),
                  'RELATED': 'workspace.finance.link_related'.tr(),
                }, (v) => update(filter.copyWith(link: v))),
                field('workspace.finance.filter_status'.tr(), filter.status, {
                  'all': 'workspace.finance.status_all'.tr(),
                  'APPROVED': 'workspace.finance.status_approved'.tr(),
                  'PENDING': 'workspace.finance.status_pending'.tr(),
                  'DRAFT': 'workspace.finance.status_draft'.tr(),
                }, (v) => update(filter.copyWith(status: v))),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: filter.facets == 0
                        ? null
                        : () {
                            onChanged(VoucherFilter.none);
                            Navigator.of(sheetContext).pop();
                          },
                    child: Text('workspace.finance.clear_filter'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
