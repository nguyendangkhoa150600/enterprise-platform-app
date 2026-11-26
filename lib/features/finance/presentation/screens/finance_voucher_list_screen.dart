import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../utils/finance_csv_exporter.dart';
import '../widgets/common/finance_export_button.dart';
import '../widgets/common/finance_error_banner.dart';
import '../../../../utils/app_toast.dart';
import '../../domain/models/finance_models.dart';
import '../finance_routes.dart';
import '../utils/finance_format.dart';
import '../utils/finance_labels.dart';
import '../utils/finance_scope.dart';
import '../widgets/common/finance_page_guard.dart';
import '../widgets/common/finance_ui.dart';
import '../widgets/voucher_list/voucher_actions_sheet.dart';
import '../widgets/voucher_list/voucher_bulk_bar.dart';
import '../widgets/voucher_list/voucher_filter_sheet.dart';
import '../widgets/voucher_list/voucher_list_card.dart';
import '../widgets/voucher_list/voucher_list_filters.dart';
import '../widgets/voucher_list/voucher_list_period_bar.dart';
import '../widgets/voucher_list/voucher_list_summary.dart';

/// Danh sách phiếu thu / phiếu chi / lệnh chuyển tiền (web `voucher-list-screen.tsx`), bố cục mobile:
/// kỳ xem, tổng kết kỳ, tìm + tab trạng thái + phạm vi, bộ lọc phụ ở bottom sheet, thẻ phiếu cuộn vô hạn.
class FinanceVoucherListScreen extends StatefulWidget {
  final FinanceVoucherKind kind;
  /// mine | to-approve | to-post | awaiting-post
  final String? initialScope;
  final FinanceVoucherStatus? initialStatus;

  /// Lọc sẵn theo tài khoản và xem toàn bộ thời gian (web `?accountId=…&month=all` từ màn Tài khoản).
  final String? initialAccountId;
  const FinanceVoucherListScreen({
    super.key,
    required this.kind,
    this.initialScope,
    this.initialStatus,
    this.initialAccountId,
  });

  @override
  State<FinanceVoucherListScreen> createState() => _FinanceVoucherListScreenState();
}

class _FinanceVoucherListScreenState extends State<FinanceVoucherListScreen> {
  static const int _pageSize = 20;
  final FinanceScope _scope = FinanceScope.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  // Bộ lọc (giống web). Kỳ mặc định: tháng hiện tại; null = toàn bộ thời gian (khi đó mới lọc Từ ngày / Đến ngày).
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _from;
  DateTime? _to;
  FinanceVoucherStatus? _status;
  late VoucherListScope _listScope;
  String _search = '';
  String _accountId = '';
  String _reasonId = '';
  String _projectId = '';

  // Danh mục cho bộ lọc phụ. Dự án lấy từ Workspace; không có thì ẩn ô lọc dự án.
  List<FinanceAccount> _accounts = const [];
  FinanceCatalogs? _catalogs;
  List<FinanceWorkspaceProject> _projects = const [];

  // Dữ liệu trang.
  FinanceVoucherList? _data;
  final List<FinanceVoucherSummary> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _seq = 0;

  // Duyệt hàng loạt: chỉ phiếu đang chờ duyệt trực tiếp mới chọn được.
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  FinanceVoucherKind get _kind => widget.kind;
  bool get _isTransfer => _kind == FinanceVoucherKind.transfer;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    final accountId = widget.initialAccountId;
    if (accountId != null && accountId.isNotEmpty) {
      _accountId = accountId;
      _month = null;
    }
    _listScope = VoucherListScope.fromApi(widget.initialScope);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Tải khi được phép mở trang (gọi từ [FinancePageGuard.onAllowed], cả sau khi thử tải lại quyền).
  void _init() {
    _load();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([_scope.repository.getAccounts(), _scope.repository.getCatalogs()]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<FinanceAccount>;
        _catalogs = results[1] as FinanceCatalogs;
      });
    } catch (_) {
      // Như web: thiếu danh mục thì chỉ thiếu ô lọc, danh sách vẫn chạy.
    }
    if (_isTransfer) return;
    try {
      final projects = await _scope.repository.getWorkspaceProjectOptions();
      if (!mounted) return;
      setState(() => _projects = projects.items);
    } catch (_) {}
  }

  FinanceVoucherQuery _query(int page) {
    String? from;
    String? to;
    final m = _month;
    if (m != null) {
      final r = financeMonthRange(m);
      from = financeApiDate(r.from);
      to = financeApiDate(r.to);
    } else {
      from = _from == null ? null : financeApiDate(_from!);
      to = _to == null ? null : financeApiDate(_to!);
    }
    return FinanceVoucherQuery(
      kind: _kind,
      status: _status,
      scope: _listScope.api,
      source: _listScope == VoucherListScope.procedure ? 'procedure' : null,
      search: _search,
      accountId: _accountId,
      reasonId: _isTransfer ? null : _reasonId,
      projectId: _isTransfer ? null : _projectId,
      from: from,
      to: to,
      page: page,
      pageSize: _pageSize,
    );
  }

  /// Tải lại từ trang 1 (đổi bộ lọc, kéo làm mới, sau thao tác).
  Future<void> _load() async {
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    try {
      final result = await _scope.repository.getVouchers(_query(1));
      if (!mounted || mine != _seq) return;
      setState(() {
        _data = result;
        _page = 1;
        _items
          ..clear()
          ..addAll(result.items);
        _selected.removeWhere((id) => !_items.any((v) => v.id == id && _selectable(v)));
        _error = null;
        _loading = false;
      });
      _fillViewport();
    } catch (e) {
      _scope.onError(e);
      if (!mounted || mine != _seq) return;
      setState(() {
        _error = financeErrorMessage(e, 'finance.voucher_list.load_error');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final data = _data;
    if (_loading || _loadingMore || data == null || !data.hasMore) return;
    final mine = _seq;
    setState(() => _loadingMore = true);
    try {
      final result = await _scope.repository.getVouchers(_query(_page + 1));
      if (!mounted || mine != _seq) return;
      setState(() {
        _data = result;
        _page = result.page;
        final known = _items.map((v) => v.id).toSet();
        _items.addAll(result.items.where((v) => !known.contains(v.id)));
        _loadingMore = false;
      });
      _fillViewport();
    } catch (e) {
      _scope.onError(e);
      if (!mounted || mine != _seq) return;
      setState(() => _loadingMore = false);
      AppToast.error(context, financeErrorMessage(e, 'finance.voucher_list.load_error'));
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.extentAfter < 400) _loadMore();
  }

  /// Trang đầu chưa đủ cao để cuộn (màn lớn): tự tải tiếp đến khi đầy màn hoặc hết phiếu.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_scrollCtrl.position.extentAfter < 400) _loadMore();
    });
  }

  /// Đổi bộ lọc thì về trang 1.
  void _apply(VoidCallback change) {
    setState(change);
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _search) return;
      _apply(() => _search = next);
    });
  }

  Future<void> _openFilters() async {
    final fields = <VoucherFilterField>[
      VoucherFilterField(
        key: 'account',
        label: 'finance.voucher_list.filter_account'.tr(),
        placeholder: 'finance.voucher_list.any_account'.tr(),
        options: [for (final a in _accounts) (id: a.id, label: a.name)],
      ),
      if (!_isTransfer && _projects.isNotEmpty)
        VoucherFilterField(
          key: 'project',
          label: 'finance.voucher_list.filter_project'.tr(),
          placeholder: 'finance.voucher_list.any_project'.tr(),
          options: [for (final p in _projects) (id: p.id, label: p.label)],
        ),
      if (!_isTransfer)
        VoucherFilterField(
          key: 'reason',
          label: _kind.label('reason_label'),
          placeholder: 'finance.voucher_list.any_reason'.tr(args: {'reason': _kind.label('reason_label').toLowerCase()}),
          options: [for (final r in _catalogs?.reasonsOf(_kind) ?? const <FinanceReason>[]) (id: r.id, label: r.name)],
        ),
    ];
    final result = await showVoucherFilterSheet(
      context,
      fields: fields,
      values: {'account': _accountId, 'project': _projectId, 'reason': _reasonId},
    );
    if (!mounted || result == null) return;
    _apply(() {
      _accountId = result['account'] ?? '';
      _projectId = result['project'] ?? '';
      _reasonId = result['reason'] ?? '';
    });
  }

  int get _activeFilterCount =>
      [_accountId, if (!_isTransfer) _projectId, if (!_isTransfer) _reasonId].where((v) => v.isNotEmpty).length;

  /* ------------------------------- Điều hướng ------------------------------- */

  Future<void> _openDetail(FinanceVoucherSummary v) async {
    final changed = await FinanceRoutes.openVoucherDetail(context, v.id);
    if (!mounted) return;
    if (changed) _load();
  }

  Future<void> _create() async {
    final saved = await FinanceRoutes.openVoucherForm(context, _kind);
    if (!mounted) return;
    if (saved != null) _load();
  }

  /* --------------------------- Thao tác trên một phiếu --------------------------- */

  Future<void> _openMenu(FinanceVoucherSummary row) async {
    final pick = await showVoucherActionsSheet(context, row,
        canCreate: _scope.capabilities.value?.of(_kind).create ?? false);
    if (!mounted || pick == null) return;
    switch (pick.action) {
      case VoucherMenuAction.edit:
        final saved = await FinanceRoutes.openVoucherForm(context, _kind, voucherId: row.id);
        if (!mounted) return;
        if (saved != null) _load();
      case VoucherMenuAction.duplicate:
        final saved = await FinanceRoutes.openVoucherForm(context, _kind, fromVoucherId: row.id);
        if (!mounted) return;
        if (saved != null) _load();
      case VoucherMenuAction.approve:
        final ok = await showFinanceConfirm(
          context,
          title: 'finance.voucher_list.approve_title'.tr(),
          message: (pick.approvalMode == FinanceApprovalMode.procedure
                  ? 'finance.voucher_list.approve_procedure_msg'
                  : 'finance.voucher_list.approve_direct_msg')
              .tr(),
          confirmLabel: 'finance.voucher_list.approve_ok'.tr(),
        );
        if (!mounted || !ok) return;
        await _run(
          () => pick.approvalMode == FinanceApprovalMode.procedure
              ? _scope.repository.procedureAction(row.id, action: 'approve', idempotencyKey: _idempotencyKey())
              : _scope.repository.approveVoucher(row.id),
          'finance.voucher_list.toast_approved',
        );
      case VoucherMenuAction.cancel:
        final reason = await showFinanceReasonPrompt(
          context,
          title: 'finance.voucher_list.cancel_title'.tr(),
          label: 'finance.voucher_list.cancel_reason_label'.tr(),
          hint: 'finance.voucher_list.cancel_reason_hint'.tr(),
          confirmLabel: 'finance.voucher_list.cancel_ok'.tr(),
          danger: true,
        );
        if (!mounted || reason == null) return;
        await _run(() => _scope.repository.cancelVoucher(row.id, note: reason), 'finance.voucher_list.toast_cancelled');
      case VoucherMenuAction.delete:
        final ok = await showFinanceConfirm(
          context,
          title: 'finance.voucher_list.delete_title'.tr(),
          message: 'finance.voucher_list.delete_msg'.tr(),
          confirmLabel: 'finance.voucher_list.delete_ok'.tr(),
          danger: true,
        );
        if (!mounted || !ok) return;
        await _run(() => _scope.repository.deleteVoucher(row.id), 'finance.voucher_list.toast_deleted');
    }
  }

  Future<void> _run(Future<Object?> Function() action, String successKey) async {
    try {
      await action();
      if (!mounted) return;
      AppToast.success(context, successKey.tr());
      _load();
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      AppToast.error(context, financeErrorMessage(e));
    }
  }

  /// Mã thao tác chống gửi lặp cho hồ sơ quy trình (web `crypto.randomUUID()`).
  String _idempotencyKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /* ------------------------------ Duyệt hàng loạt ------------------------------ */

  bool _selectable(FinanceVoucherSummary v) =>
      v.status == FinanceVoucherStatus.pending && v.approvalMode == FinanceApprovalMode.direct;

  void _toggle(FinanceVoucherSummary v) {
    if (!_selectable(v)) {
      AppToast.error(context, 'finance.voucher_list.bulk_only_direct'.tr());
      return;
    }
    if (!_selected.contains(v.id) && _selected.length >= kFinanceBulkApproveMax) {
      AppToast.error(context, 'finance.voucher_list.bulk_max'.tr(args: {'max': kFinanceBulkApproveMax}));
      return;
    }
    setState(() => _selected.contains(v.id) ? _selected.remove(v.id) : _selected.add(v.id));
  }

  void _setSelecting(bool on) => setState(() {
        _selecting = on;
        if (!on) _selected.clear();
      });

  Future<void> _bulkApprove() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await showFinanceConfirm(
      context,
      title: 'finance.voucher_list.bulk_confirm_title'.tr(args: {'count': ids.length}),
      message: 'finance.voucher_list.bulk_confirm_msg'.tr(),
      confirmLabel: 'finance.voucher_list.approve_ok'.tr(),
    );
    if (!mounted || !ok) return;
    setState(() => _bulkBusy = true);
    try {
      final result = await _scope.repository.bulkApprove(ids);
      if (!mounted) return;
      if (result.approved.isNotEmpty) {
        AppToast.success(context, 'finance.voucher_list.bulk_done'.tr(args: {'count': result.approved.length}));
      }
      setState(() {
        _selected
          ..clear()
          ..addAll(result.failed.map((f) => f.id));
        _bulkBusy = false;
      });
      _load();
      if (result.failed.isNotEmpty) await showVoucherBulkFailures(context, result);
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      setState(() => _bulkBusy = false);
      AppToast.error(context, financeErrorMessage(e, 'finance.voucher_list.bulk_error'));
    }
  }

  /* ---------------------------------- Giao diện ---------------------------------- */

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FinanceCapabilities?>(
      valueListenable: _scope.capabilities,
      builder: (context, caps, _) {
        final canCreate = caps?.of(_kind).create ?? false;
        final canApprove = caps?.of(_kind).approve ?? false;
        final selecting = _selecting && canApprove;
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && selecting) _setSelecting(false);
          },
          child: Scaffold(
            backgroundColor: FinanceColors.bg,
            appBar: financeAppBar(
              context,
              selecting ? 'finance.voucher_list.bulk_action'.tr() : _kind.label('list_title'),
              actions: [
                // Web "Xuất Excel": các phiếu đang hiện theo bộ lọc.
                if (!selecting)
                  FinanceExportButton(
                    compact: true,
                    label: 'finance.export.button_excel'.tr(),
                    onExport: _items.isEmpty ? null : () => FinanceCsvExporter.exportVouchers(_kind, List.of(_items)),
                  ),
                if (canApprove && !selecting)
                  IconButton(
                    tooltip: 'finance.voucher_list.bulk_action'.tr(),
                    icon: const Icon(Icons.done_all_rounded),
                    onPressed: () => _setSelecting(true),
                  ),
                if (selecting)
                  IconButton(
                    tooltip: 'common.close'.tr(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _setSelecting(false),
                  ),
              ],
            ),
            body: FinancePageGuard(
              page: FinancePageAccess.ofKind(_kind),
              onAllowed: _init,
              builder: (context, caps) => _body(caps, selecting),
            ),
            floatingActionButton: canCreate && !selecting && FinancePageAccess.ofKind(_kind).canOpen(caps)
                ? FloatingActionButton.extended(
                    backgroundColor: FinanceColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('finance.voucher_list.create'.tr()),
                  )
                : null,
            bottomNavigationBar: selecting
                ? VoucherBulkBar(
                    count: _selected.length,
                    busy: _bulkBusy,
                    onClear: () => setState(_selected.clear),
                    onApprove: _bulkApprove,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _body(FinanceCapabilities caps, bool selecting) {
    final data = _data;
    final canApprove = caps.of(_kind).approve;
    final scopes = VoucherListScope.values.where((s) => s.visibleFor(_kind, canApprove)).toList();
    return RefreshIndicator(
      color: FinanceColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            sliver: SliverList.list(children: [
              FinanceCard(
                child: VoucherListPeriodBar(
                  month: _month,
                  from: _from,
                  to: _to,
                  onMonthChanged: (m) => _apply(() => _month = m),
                  onFromChanged: (d) => _apply(() => _from = d),
                  onToChanged: (d) => _apply(() => _to = d),
                ),
              ),
              if (data != null) VoucherListSummary(data: data),
              VoucherListFilters(
                searchController: _searchCtrl,
                onSearchChanged: _onSearchChanged,
                status: _status,
                statusCounts: data?.statusCounts ?? const {},
                onStatusChanged: (s) => _apply(() => _status = s),
                scopes: scopes,
                scope: _listScope,
                onScopeChanged: (s) => _apply(() => _listScope = s),
                activeFilterCount: _activeFilterCount,
                onOpenFilters: _openFilters,
              ),
              const SizedBox(height: 12),
            ]),
          ),
          ..._listSlivers(selecting),
        ],
      ),
    );
  }

  List<Widget> _listSlivers(bool selecting) {
    if (_loading && _items.isEmpty) {
      return const [SliverToBoxAdapter(child: FinanceStateView(loading: true))];
    }
    if (_error != null && _items.isEmpty) {
      return [SliverToBoxAdapter(child: FinanceStateView(error: _error, onRetry: _load))];
    }
    // Web: lỗi tải luôn hiện thành dải báo phía trên bảng, kể cả khi còn dòng cũ.
    final errorBanner = (_error != null && _items.isNotEmpty)
        ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FinanceBanner(message: _error!),
            ),
          )
        : null;
    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: FinanceStateView(
            emptyText: 'finance.voucher_list.empty'.tr(args: {'singular': _kind.label('singular')}),
            emptyIcon: Icons.receipt_long_outlined,
          ),
        ),
      ];
    }
    return [
      ?errorBanner,
      if (_loading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 2, color: FinanceColors.primary),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        sliver: SliverList.builder(
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) {
              return _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: FinanceColors.primary))),
                    )
                  : const SizedBox.shrink();
            }
            final v = _items[i];
            final selectable = _selectable(v);
            return VoucherListCard(
              voucher: v,
              selectionMode: selecting,
              selectable: selectable,
              selected: _selected.contains(v.id),
              onTap: () => selecting ? _toggle(v) : _openDetail(v),
              onLongPress: !selecting && (_scope.capabilities.value?.of(_kind).approve ?? false) && selectable
                  ? () {
                      _setSelecting(true);
                      _toggle(v);
                    }
                  : null,
              onMore: () => _openMenu(v),
            );
          },
        ),
      ),
    ];
  }
}
