import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/ledger/ledger_models.dart';
import '../utils/inventory_csv_exporter.dart';
import '../utils/inventory_scope.dart';
import 'ledger_format.dart';

/// "Nhu cầu cấp phát vật tư từ Quy trình (Bảng kê CSV)" — web material-requisitions-card.tsx.
class LedgerRequisitionsCard extends StatefulWidget {
  final List<ProcedureRequisition> requisitions;
  final bool loading;
  final LedgerWorkspace workspace;
  final bool canWriteTransactions;
  final void Function(ProcedureRequisition req) onOpenIssue;
  final void Function(String materialCode)? onOpenTransfer;
  final void Function(String materialCode)? onCheckStock;

  const LedgerRequisitionsCard({
    super.key,
    required this.requisitions,
    required this.loading,
    required this.workspace,
    required this.canWriteTransactions,
    required this.onOpenIssue,
    this.onOpenTransfer,
    this.onCheckStock,
  });

  @override
  State<LedgerRequisitionsCard> createState() => _LedgerRequisitionsCardState();
}

class _LedgerRequisitionsCardState extends State<LedgerRequisitionsCard> {
  String? _expanded;

  static const _blue = Color(0xFF2563EB);

  Future<void> _downloadCsv(ProcedureRequisition req) async {
    final rows = <List<Object?>>[
      [
        'inventory.ledger.req_csv_code'.tr(),
        'inventory.ledger.req_csv_name'.tr(),
        'inventory.ledger.req_csv_qty'.tr(),
        'inventory.ledger.req_csv_unit'.tr(),
      ],
      ...req.lines.map((l) => [l.materialCode, l.materialName ?? '', l.quantity, l.unit ?? '']),
    ];
    final name = req.csvFileName.endsWith('.csv')
        ? req.csvFileName.substring(0, req.csvFileName.length - 4)
        : req.csvFileName;
    try {
      await InventoryCsvExporter.share(name, rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(inventoryErrorMessage(e)),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqs = widget.requisitions;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: _blue, width: 4),
          top: BorderSide(color: AppColors.slate200),
          right: BorderSide(color: AppColors.slate200),
          bottom: BorderSide(color: AppColors.slate200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.table_chart_outlined, size: 18, color: _blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('inventory.ledger.req_title'.tr(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                    const SizedBox(height: 2),
                    Text('inventory.ledger.req_subtitle'.tr(),
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                widget.loading
                    ? 'inventory.ledger.req_updating'.tr()
                    : 'inventory.ledger.req_count'.tr(args: {'n': reqs.length}),
                bg: reqs.isNotEmpty ? const Color(0xFFDBEAFE) : AppColors.slate100,
                fg: reqs.isNotEmpty ? const Color(0xFF1D4ED8) : AppColors.slate500,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.loading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('inventory.ledger.req_scanning'.tr(),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
            )
          else if (reqs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.slate300),
              ),
              child: Text('inventory.ledger.req_empty'.tr(),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
            )
          else
            ...reqs.map((r) => Padding(padding: const EdgeInsets.only(top: 8), child: _buildRequisition(r))),
        ],
      ),
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg, Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _tierBadge(String tier, String text) {
    switch (tier) {
      case 'single_ready':
        return _pill(text, bg: const Color(0xFFECFDF5), fg: const Color(0xFF047857), border: const Color(0xFFA7F3D0));
      case 'transfer_needed':
        return _pill(text, bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309), border: const Color(0xFFFDE68A));
      default:
        return _pill(text, bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), border: const Color(0xFFFECACA));
    }
  }

  Widget _buildRequisition(ProcedureRequisition req) {
    final expanded = _expanded == req.code;
    final approved = req.isApproved;
    final total = req.lines.fold<double>(0, (s, l) => s + l.quantity);
    var single = 0, transfer = 0, shortage = 0;
    for (final l in req.lines) {
      final t = LedgerFormat.requisitionTier(widget.workspace, l.materialCode, l.quantity).tier;
      if (t == 'single_ready') {
        single++;
      } else if (t == 'transfer_needed') {
        transfer++;
      } else {
        shortage++;
      }
    }

    final Widget status = req.fulfilmentStatus == 'PARTIAL'
        ? _pill('inventory.ledger.req_partial'.tr(),
            bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309), border: const Color(0xFFFDE68A))
        : approved
            ? _pill('inventory.ledger.req_approved'.tr(),
                bg: const Color(0xFFECFDF5), fg: const Color(0xFF047857), border: const Color(0xFFA7F3D0))
            : _pill('inventory.ledger.req_pending'.tr(),
                bg: AppColors.slate100, fg: AppColors.slate600, border: AppColors.slate200);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = expanded ? null : req.code),
            child: Container(
              color: expanded ? AppColors.slate50 : Colors.white,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(req.code,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Color(0xFF1D4ED8))),
                      ),
                      const Spacer(),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.slate500),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(req.title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                  if (req.assetCode != null)
                    Text('inventory.ledger.req_asset'.tr(args: {'code': req.assetCode}),
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    status,
                    if (single > 0) _tierBadge('single_ready', 'inventory.ledger.req_tier_single'.tr(args: {'n': single})),
                    if (transfer > 0)
                      _tierBadge('transfer_needed', 'inventory.ledger.req_tier_transfer'.tr(args: {'n': transfer})),
                    if (shortage > 0) _tierBadge('shortage', 'inventory.ledger.req_tier_shortage'.tr(args: {'n': shortage})),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    _meta(Icons.inventory_2_outlined,
                        'inventory.ledger.req_lines'.tr(args: {'n': req.lines.length, 'total': LedgerFormat.number(total)})),
                    _meta(Icons.description_outlined, req.csvFileName),
                    _meta(Icons.schedule, LedgerFormat.date(req.startedAt)),
                  ]),
                ],
              ),
            ),
          ),
          if (expanded) _buildExpanded(req, approved),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.slate500),
        const SizedBox(width: 3),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500))),
      ]);

  Widget _buildExpanded(ProcedureRequisition req, bool approved) {
    final canIssue = widget.canWriteTransactions && approved;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('inventory.ledger.req_detail_heading'.tr(args: {'n': req.lines.length}),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _downloadCsv(req),
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text('inventory.ledger.req_download_csv'.tr()),
              style: _outlined(),
            ),
            if (widget.onCheckStock != null && req.lines.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => widget.onCheckStock!(req.lines.first.materialCode),
                icon: const Icon(Icons.inventory_outlined, size: 15, color: AppColors.emerald600),
                label: Text('inventory.ledger.req_check_stock'.tr()),
                style: _outlined(),
              ),
            ElevatedButton.icon(
              onPressed: canIssue ? () => widget.onOpenIssue(req) : null,
              icon: const Icon(Icons.north_east, size: 15),
              label: Text(req.lines.length > 1
                  ? 'inventory.ledger.req_process_n'.tr(args: {'n': req.lines.length})
                  : 'inventory.ledger.req_process'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (req.lines.isEmpty)
            Text('inventory.ledger.req_no_lines'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate400, fontStyle: FontStyle.italic))
          else
            ...req.lines.map((l) => _buildLine(req, l, canIssue)),
        ],
      ),
    );
  }

  ButtonStyle _outlined() => OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate700,
        side: const BorderSide(color: AppColors.slate300),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _buildLine(ProcedureRequisition req, RequisitionLine line, bool canIssue) {
    final r = LedgerFormat.requisitionTier(widget.workspace, line.materialCode, line.quantity);
    final avail = LedgerFormat.number(r.totalAvail);
    final tierText = switch (r.tier) {
      'single_ready' => 'inventory.ledger.req_line_single'.tr(args: {'n': avail}),
      'transfer_needed' => 'inventory.ledger.req_line_transfer'.tr(args: {'n': avail}),
      _ => 'inventory.ledger.req_line_shortage'.tr(args: {'n': avail}),
    };
    final actionText = switch (r.tier) {
      'single_ready' => 'inventory.ledger.req_action_single'.tr(),
      'transfer_needed' => 'inventory.ledger.req_action_transfer'.tr(),
      _ => 'inventory.ledger.req_action_shortage'.tr(),
    };
    final actionColor = switch (r.tier) {
      'single_ready' => const Color(0xFF16A34A),
      'transfer_needed' => const Color(0xFFD97706),
      _ => _blue,
    };
    // Tồn từng kho (web hiện ở tooltip).
    final breakdown = widget.workspace.stock.where((s) => s.materialCode == line.materialCode).map((s) {
      final wh = widget.workspace.warehouseByCode(s.warehouseCode);
      return 'inventory.ledger.req_breakdown_row'.tr(args: {
        'name': wh?.name ?? s.warehouseCode,
        'code': s.warehouseCode,
        'avail': LedgerFormat.number(s.available),
        'qty': LedgerFormat.number(s.quantity),
      });
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(line.materialCode,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
                  Text(line.materialName ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.slate800)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('inventory.ledger.req_need'.tr(),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
                Text('${LedgerFormat.number(line.quantity)} ${line.unit ?? ''}'.trim(),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
              ]),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: breakdown.isEmpty
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(line.materialCode, style: const TextStyle(fontSize: 15)),
                        content: Text(breakdown.join('\n'), style: const TextStyle(fontSize: 13)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx), child: Text('inventory.ledger.close'.tr())),
                        ],
                      ),
                    ),
            child: _tierBadge(r.tier, tierText),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (widget.onCheckStock != null)
              OutlinedButton.icon(
                onPressed: () => widget.onCheckStock!(line.materialCode),
                icon: const Icon(Icons.visibility_outlined, size: 13),
                label: Text('inventory.ledger.req_peek'.tr()),
                style: _small(AppColors.slate600, AppColors.slate300),
              ),
            if (r.tier == 'transfer_needed' && widget.onOpenTransfer != null && widget.canWriteTransactions)
              OutlinedButton.icon(
                onPressed: () => widget.onOpenTransfer!(line.materialCode),
                icon: const Icon(Icons.swap_horiz, size: 13),
                label: Text('inventory.ledger.req_transfer'.tr()),
                style: _small(const Color(0xFFB45309), const Color(0xFFFCD34D)),
              ),
            TextButton(
              onPressed: canIssue ? () => widget.onOpenIssue(req) : null,
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
              ),
              child: Text(actionText),
            ),
          ]),
        ],
      ),
    );
  }

  ButtonStyle _small(Color fg, Color border) => OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      );
}
