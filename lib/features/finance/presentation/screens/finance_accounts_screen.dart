import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../utils/finance_csv_exporter.dart';
import '../widgets/common/finance_export_button.dart';
import '../../../../utils/app_toast.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_scope.dart';
import '../widgets/accounts/finance_account_card.dart';
import '../widgets/accounts/finance_account_form_sheet.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';

/// "Danh sách tài khoản" (web `AccountsScreen`): số dư, số phiếu, tổng thu/chi từng tài khoản;
/// thêm/sửa khi có quyền quản lý tài khoản; mở "Sổ tài khoản".
class FinanceAccountsScreen extends StatefulWidget {
  const FinanceAccountsScreen({super.key});

  @override
  State<FinanceAccountsScreen> createState() => _FinanceAccountsScreenState();
}

class _FinanceAccountsScreenState extends State<FinanceAccountsScreen> {
  final FinanceScope _scope = FinanceScope.instance;
  List<FinanceAccount> _accounts = const [];
  bool _showInactive = false;
  bool _loading = true;
  bool _loaded = false;
  String? _error;

  // Ô tìm kiếm (bổ sung trên mobile, web không có): lọc ngay trên danh sách đã tải.
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Khớp tên, mã, số tài khoản, ngân hàng, chủ tài khoản; không phân biệt dấu.
  List<FinanceAccount> get _visible {
    final q = financeFold(_query);
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) {
      final hay = financeFold(
          [a.name, a.code, a.accountNumber ?? '', a.bankName ?? '', a.accountHolder ?? ''].join(' '));
      return hay.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _scope.repository.getAccounts(includeInactive: _showInactive);
      if (!mounted) return;
      setState(() {
        _accounts = list;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      setState(() => _error = financeErrorMessage(e, 'finance.accounts.error_load'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([FinanceAccount? account]) async {
    final saved = await showFinanceAccountForm(
      context,
      account: account,
      onSave: (id, body) async {
        try {
          await _scope.repository.saveAccount(id, body);
        } catch (e) {
          _scope.onError(e);
          rethrow;
        }
      },
    );
    if (!mounted || !saved) return;
    AppToast.success(context, account != null ? 'finance.accounts.updated'.tr() : 'finance.accounts.added'.tr());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceColors.bg,
      appBar: financeAppBar(context, 'finance.accounts.title'.tr(), actions: [
        // Chỉ hiện thao tác khi được mở trang (web: nút nằm trong trang, màn chặn thì không có).
        ValueListenableBuilder<FinanceCapabilities?>(
          valueListenable: _scope.capabilities,
          builder: (context, caps, _) {
            if (!FinancePage.accounts.canOpen(caps)) return const SizedBox.shrink();
            return Row(mainAxisSize: MainAxisSize.min, children: [
              FinanceExportButton(
                compact: true,
                label: 'finance.export.button_excel'.tr(),
                onExport: _accounts.isEmpty ? null : () => FinanceCsvExporter.exportAccounts(List.of(_accounts)),
              ),
              IconButton(
                tooltip: 'common.refresh'.tr(),
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loading ? null : _load,
              ),
            ]);
          },
        ),
      ]),
      floatingActionButton: ValueListenableBuilder<FinanceCapabilities?>(
        valueListenable: _scope.capabilities,
        builder: (context, caps, _) => (caps != null && FinancePage.accounts.canOpen(caps) && caps.canManageAccounts)
            ? FloatingActionButton.extended(
                backgroundColor: FinanceColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: Text('finance.accounts.add'.tr()),
              )
            : const SizedBox.shrink(),
      ),
      body: FinancePageGuard(
        page: FinancePage.accounts,
        // Chỉ gọi /accounts sau khi được phép mở trang.
        onAllowed: _load,
        builder: (context, caps) => _body(caps.canManageAccounts, caps),
      ),
    );
  }

  Widget _body(bool canManage, FinanceCapabilities caps) {
    if (_loading && !_loaded) return const FinanceStateView(loading: true);
    if (_error != null && !_loaded) return FinanceStateView(error: _error, onRetry: _load);

    // Web: tổng số dư chỉ cộng các tài khoản đang hoạt động (tính trên các tài khoản đang hiện).
    final visible = _visible;
    final total = visible.where((a) => a.isActive).fold<double>(0, (s, a) => s + (a.balance ?? 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'finance.accounts.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: FinanceColors.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'common.clear'.tr(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: FinanceColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: FinanceColors.border),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('finance.accounts.show_inactive'.tr(),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
              ),
              Switch.adaptive(
                value: _showInactive,
                onChanged: (v) {
                  setState(() => _showInactive = v);
                  _load();
                },
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'finance.accounts.summary'.tr(args: {'count': visible.length})),
                const TextSpan(text: ' '),
                TextSpan(
                  text: formatFinanceMoney(total),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: FinanceColors.text),
                ),
              ]),
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: FinanceColors.primary),
          if (_accounts.isEmpty)
            FinanceStateView(emptyText: 'finance.accounts.empty'.tr(), emptyIcon: Icons.account_balance_outlined)
          else if (visible.isEmpty)
            FinanceStateView(emptyText: 'finance.accounts.search_empty'.tr(), emptyIcon: Icons.search_off_rounded)
          else
            for (final a in visible)
              FinanceAccountCard(
                account: a,
                onLedger: () => FinanceRoutes.openAccountLedger(context, a),
                onEdit: canManage ? () => _openForm(a) : null,
                // Web: bấm số phiếu → danh sách phiếu loại đó của tài khoản, mọi tháng (cần quyền mở loại phiếu).
                onOpenKind: (kind) {
                  if (!caps.canOpenKind(kind)) return;
                  FinanceRoutes.openVoucherList(context, kind, accountId: a.id);
                },
              ),
        ],
      ),
    );
  }
}
