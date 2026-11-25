import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_csv_exporter.dart';
import '../common/finance_export_button.dart';
import '../../../domain/models/finance_models.dart';
import '../../finance_routes.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_scope.dart';
import '../common/finance_ui.dart';
import '../common/finance_error_banner.dart';

/// Số dòng mỗi lần tải (web `LEDGER_PAGE_SIZE`); "Hiện tất cả" tải tối đa [_allLimit].
const int _pageSize = 60;
const int _allLimit = 5000;

/// Báo cáo thu chi dạng sổ (web `LedgerReport`): dư đầu kỳ, từng chứng từ kèm tồn quỹ chạy, cộng phát sinh.
class FinanceReportLedgerView extends StatefulWidget {
  final String from;
  final String to;
  final String accountId;
  final int refreshKey;
  final Widget header;

  const FinanceReportLedgerView({
    super.key,
    required this.from,
    required this.to,
    required this.accountId,
    required this.refreshKey,
    required this.header,
  });

  @override
  State<FinanceReportLedgerView> createState() => _FinanceReportLedgerViewState();
}

class _FinanceReportLedgerViewState extends State<FinanceReportLedgerView> {
  final _scope = FinanceScope.instance;
  final ScrollController _scroll = ScrollController();
  FinanceLedgerReport? _report;
  List<FinanceLedgerReportRow> _rows = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  // Mỗi lần đổi bộ lọc là một "phiên" mới: kết quả phiên cũ về muộn thì bỏ.
  int _session = 0;

  int get _total => _report?.total ?? 0;
  bool get _hasMore => _rows.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant FinanceReportLedgerView old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from ||
        old.to != widget.to ||
        old.accountId != widget.accountId ||
        old.refreshKey != widget.refreshKey) {
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) _loadMore(_pageSize);
  }

  /// Như sentinel của web: nội dung chưa đủ dài để cuộn thì tự tải thêm.
  void _checkFill() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });

  Future<FinanceLedgerReport> _fetch(int offset, int limit) => _scope.repository.getLedgerReport(
        from: widget.from,
        to: widget.to,
        accountId: widget.accountId.isEmpty ? null : widget.accountId,
        offset: offset,
        limit: limit,
      );

  Future<void> _load() async {
    if (widget.from.isEmpty || widget.to.isEmpty) return;
    final mine = ++_session;
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    try {
      final first = await _fetch(0, _pageSize);
      if (!mounted || mine != _session) return;
      setState(() {
        _report = first;
        _rows = first.items;
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
      _checkFill();
    } catch (e) {
      _scope.onError(e);
      if (!mounted || mine != _session) return;
      setState(() {
        _error = financeErrorMessage(e, 'finance.reports.load_error');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore(int limit) async {
    final report = _report;
    if (report == null || _loading || _loadingMore || _rows.length >= report.total) return;
    final mine = _session;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch(_rows.length, limit);
      if (!mounted || mine != _session) return;
      setState(() {
        if (_rows.length == next.offset) _rows = [..._rows, ...next.items];
      });
      _checkFill();
    } catch (e) {
      _scope.onError(e);
      if (!mounted || mine != _session) return;
      setState(() => _error = financeErrorMessage(e, 'finance.reports.load_more_error'));
    } finally {
      if (mounted && mine == _session) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(FinanceLedgerReportRow row) async {
    final changed = await FinanceRoutes.openVoucherDetail(context, row.voucherId);
    if (!mounted) return;
    if (changed) _load();
  }

  /// Web: xuất toàn bộ dòng của kỳ (đã tải đủ thì dùng luôn, chưa thì tải một lần tối đa [_allLimit]).
  Future<void> _export(FinanceLedgerReport report) async {
    final all = _rows.length >= report.total ? _rows : (await _fetch(0, _allLimit)).items;
    await FinanceCsvExporter.exportLedger(report, all);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final pre = <Widget>[
      widget.header,
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'finance.reports.ledger_title'
                    .tr(args: {'from': formatFinanceDate(widget.from), 'to': formatFinanceDate(widget.to)}),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: FinanceColors.text),
              ),
            ),
            const SizedBox(width: 8),
            FinanceExportButton(
              label: 'finance.export.button_export'.tr(),
              errorKey: 'finance.export.failed',
              onExport: report == null ? null : () => _export(report),
            ),
          ],
        ),
      ),
      if (_error != null)
        report == null ? FinanceStateView(error: _error, onRetry: _load) : FinanceBanner(message: _error!),
      if (_loading && report == null) const FinanceStateView(loading: true),
      if (report != null) ...[
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        _SummaryRow(label: 'finance.reports.opening_row'.tr(), balance: report.openingBalance),
        if (_rows.isEmpty) FinanceStateView(emptyText: 'finance.reports.ledger_empty'.tr()),
      ],
    ];
    final rows = report == null ? const <FinanceLedgerReportRow>[] : _rows;
    final post = report == null ? const <Widget>[] : _footer(report);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: pre.length + rows.length + post.length,
        itemBuilder: (context, i) {
          if (i < pre.length) return pre[i];
          final r = i - pre.length;
          if (r < rows.length) {
            return _LedgerRowCard(index: r + 1, row: rows[r], onTap: () => _open(rows[r]));
          }
          return post[r - rows.length];
        },
      ),
    );
  }

  List<Widget> _footer(FinanceLedgerReport report) {
    return [
      if (!_hasMore)
        _SummaryRow(
          label: 'finance.reports.total_row'.tr(),
          receipts: report.totalReceipts,
          payments: report.totalPayments,
          balance: report.closingBalance,
        ),
      const SizedBox(height: 4),
      if (_hasMore)
        Column(
          children: [
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Text(
              'finance.reports.showing_rows'.tr(args: {'count': _rows.length, 'total': _total}),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted),
            ),
            TextButton(
              onPressed: _loadingMore ? null : () => _loadMore(math.min(_total - _rows.length, _allLimit)),
              child: Text('finance.reports.show_all'.tr()),
            ),
          ],
        )
      else
        Text(
          'finance.reports.shown_all'.tr(args: {'total': _total}),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: FinanceColors.muted),
        ),
    ];
  }
}

/// Dòng "Dư đầu kỳ" / "Cộng phát sinh".
class _SummaryRow extends StatelessWidget {
  final String label;
  final double? receipts;
  final double? payments;
  final double balance;
  const _SummaryRow({required this.label, required this.balance, this.receipts, this.payments});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(formatFinanceMoney(balance),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
              ),
            ],
          ),
          if (receipts != null && payments != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _money('finance.reports.col_receipt'.tr(), receipts!, FinanceColors.income),
                _money('finance.reports.col_payment'.tr(), payments!, const Color(0xFFDC2626)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _money(String label, double v, Color color) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
        TextSpan(
            text: formatFinanceMoney(v), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      ]));
}

class _LedgerRowCard extends StatelessWidget {
  final int index;
  final FinanceLedgerReportRow row;
  final VoidCallback onTap;
  const _LedgerRowCard({required this.index, required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isReceipt = row.receipt != 0;
    final amount = isReceipt ? row.receipt : row.payment;
    final hasAmount = row.receipt != 0 || row.payment != 0;
    const meta = TextStyle(fontSize: 12, color: FinanceColors.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FinanceColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('$index. ', style: meta),
                    Expanded(
                      child: Text(row.voucherCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700, color: FinanceColors.primary)),
                    ),
                    if (hasAmount)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isReceipt ? '+' : '-'}${formatFinanceMoney(amount)}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isReceipt ? FinanceColors.income : const Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${row.isReversal ? 'finance.reports.reversal_prefix'.tr() : ''}${row.content}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: FinanceColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'finance.reports.posted_on'.tr(args: {'date': formatFinanceDate(row.postedDate)})} · ${row.accountName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if ((row.createdByName ?? '').isNotEmpty) row.createdByName!,
                          formatFinanceDate(row.createdAt),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'finance.reports.balance_after'.tr(args: {'amount': formatFinanceMoney(row.balanceAfter)}),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
