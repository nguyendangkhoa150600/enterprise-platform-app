import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_scope.dart';
import '../widgets/accounts/finance_ledger_entry_tile.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';

/// "Sổ tài khoản" (web `LedgerDrawer`): lọc từ/đến ngày, số dư đầu kỳ, bút toán kèm số dư sau, 20 dòng/trang.
/// Cần quyền xem số dư (server `canSeeBalances`) — cùng điều kiện mở trang Tài khoản.
class FinanceAccountLedgerScreen extends StatefulWidget {
  final FinanceAccount account;
  const FinanceAccountLedgerScreen({super.key, required this.account});

  @override
  State<FinanceAccountLedgerScreen> createState() => _FinanceAccountLedgerScreenState();
}

class _FinanceAccountLedgerScreenState extends State<FinanceAccountLedgerScreen> {
  static const int _pageSize = 20;
  final FinanceScope _scope = FinanceScope.instance;
  final ScrollController _scroll = ScrollController();

  String? _from;
  String? _to;
  final List<FinanceLedgerEntry> _items = [];
  FinanceAccountLedger? _last;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Tăng mỗi lần đổi bộ lọc để bỏ kết quả của lần tải cũ (web `active` flag).
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final data = await _scope.repository
          .getAccountLedger(widget.account.id, from: _from, to: _to, page: 1, pageSize: _pageSize);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(data.items);
        _last = data;
        _loading = false;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = financeErrorMessage(e, 'finance.accounts.ledger_error');
      });
    }
  }

  Future<void> _loadMore() async {
    final last = _last;
    if (_loading || _loadingMore || last == null || !last.hasMore) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final data = await _scope.repository
          .getAccountLedger(widget.account.id, from: _from, to: _to, page: last.page + 1, pageSize: _pageSize);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(data.items);
        _last = data;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted || gen != _generation) return;
      setState(() => _error = financeErrorMessage(e, 'finance.accounts.ledger_error'));
    } finally {
      if (mounted && gen == _generation) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final current = parseFinanceDate(isFrom ? _from : _to);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: (isFrom ? 'common.from_date' : 'common.to_date').tr(),
    );
    if (!mounted || picked == null) return;
    setState(() => isFrom ? _from = financeApiDate(picked) : _to = financeApiDate(picked));
    _reload();
  }

  void _clearDate(bool isFrom) {
    setState(() => isFrom ? _from = null : _to = null);
    _reload();
  }

  Future<void> _openEntry(FinanceLedgerEntry e) async {
    final changed = await FinanceRoutes.openVoucherDetail(context, e.voucherId);
    if (!mounted || !changed) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceColors.bg,
      appBar: financeAppBar(context, 'finance.accounts.ledger_title'.tr(args: {'name': widget.account.name})),
      body: FinancePageGuard(page: FinancePage.accounts, builder: (context, _) => _body()),
    );
  }

  Widget _body() {
    final opening = _last?.openingBalance ?? widget.account.openingBalance;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _DateChip(label: 'common.from_date'.tr(), value: _from, onTap: () => _pickDate(true), onClear: () => _clearDate(true))),
                  const SizedBox(width: 8),
                  Expanded(child: _DateChip(label: 'common.to_date'.tr(), value: _to, onTap: () => _pickDate(false), onClear: () => _clearDate(false))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('finance.accounts.ledger_opening'.tr(),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(formatFinanceMoney(opening),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: FinanceColors.border),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() {
    if (_loading && _items.isEmpty) return const FinanceStateView(loading: true);
    if (_error != null && _items.isEmpty) return FinanceStateView(error: _error, onRetry: _reload);
    return RefreshIndicator(
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [FinanceStateView(emptyText: 'finance.accounts.ledger_empty'.tr())],
            )
          : ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                FinanceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: FinanceColors.border),
                        FinanceLedgerEntryTile(entry: _items[i], onTap: () => _openEntry(_items[i])),
                      ],
                    ],
                  ),
                ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: FinanceColors.primary)),
                  )
                else if (_last?.hasMore ?? false)
                  Center(
                    child: TextButton(onPressed: _loadMore, child: Text('finance.accounts.load_more'.tr())),
                  ),
                if (_error != null && _items.isNotEmpty)
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
              ],
            ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateChip({required this.label, required this.value, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: has ? const Color(0xFFBFDBFE) : FinanceColors.border),
          color: has ? const Color(0xFFEFF6FF) : Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: FinanceColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(has ? formatFinanceDate(value) : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: has ? FinanceColors.text : FinanceColors.faint)),
            ),
            if (has)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.close_rounded, color: FinanceColors.muted),
                onPressed: onClear,
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
