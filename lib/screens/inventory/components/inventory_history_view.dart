import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/ledger/ledger_repository.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/domain/ledger/ledger_models.dart';
import '../../../features/inventory/presentation/ledger/batch_requisition_sheet.dart';
import '../../../features/inventory/presentation/ledger/item_profile_sheet.dart';
import '../../../features/inventory/presentation/ledger/ledger_format.dart';
import '../../../features/inventory/presentation/ledger/requisitions_card.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../models/inventory_models.dart';
import '../../../theme/colors.dart';
import 'inventory_movement_dialog.dart';
import 'movement_detail_sheet.dart';

/// Tab "Lịch sử xuất nhập" của trang Kho hàng — web transaction-hub.tsx (hideSubTabs):
/// yêu cầu cấp vật tư từ Quy trình + Sổ cái giao dịch kho (lọc, phân trang, chi tiết).
/// Tự nạp dữ liệu từ Inventory API như web; tham số cũ giữ để tương thích màn cha.
class InventoryHistoryView extends StatefulWidget {
  final List<StockTransaction> transactions;
  final List<InventoryItem> items;
  final List<WarehouseItem>? warehouses;
  final bool isLoading;

  /// Gọi sau khi ghi phiếu / cấp vật tư để các tab khác của màn cha nạp lại.
  final Future<void> Function() onRefresh;

  const InventoryHistoryView({
    super.key,
    required this.transactions,
    this.items = const [],
    this.warehouses,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<InventoryHistoryView> createState() => _InventoryHistoryViewState();
}

class _InventoryHistoryViewState extends State<InventoryHistoryView> with SingleTickerProviderStateMixin {
  static const _pageSizes = [15, 30, 45, 60];
  final LedgerRepository _repo = LedgerRepository.instance;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _headerAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1.0);
  late final Animation<Offset> _headerSlide = Tween<Offset>(begin: const Offset(0, -1.05), end: Offset.zero)
      .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
  bool _headerVisible = true;

  // Dữ liệu
  bool _loading = true;
  String? _loadError;
  LedgerWorkspace _ws = LedgerWorkspace.empty;
  List<LedgerRow> _ledger = const [];
  Map<String, String> _userNames = const {};
  List<ProcedureRequisition> _requisitions = const [];
  bool _loadingRequisitions = false;
  String? _requisitionError;

  // Bộ lọc (web: ledgerTypeFilter / ledgerWarehouseFilter / ledgerSearch / page / pageSize)
  String _typeFilter = 'all'; // all | IMPORT | EXPORT
  String _warehouseFilter = 'all'; // all | warehouseId
  String _search = '';
  int _page = 1;
  int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.offset <= 15) _showHeader();
    });
    InventoryScope.instance.ensureCapabilities();
    _reload();
    _reloadRequisitions();
    _repo.loadUserNames().then((names) {
      if (mounted) setState(() => _userNames = names);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  /// Web `reload`: mỗi nguồn nạp độc lập; một nguồn lỗi không làm mất phần đã nạp.
  Future<void> _reload() async {
    setState(() => _loadError = null);
    Object? firstError;
    final failed = <String>[];
    await Future.wait([
      _repo.loadWorkspace().then((ws) {
        if (mounted) setState(() => _ws = ws);
      }).catchError((Object e) {
        firstError ??= e;
        failed.add('inventory.ledger.part_stock'.tr());
      }),
      _repo.loadLedger().then((rows) {
        if (mounted) setState(() => _ledger = rows);
      }).catchError((Object e) {
        firstError ??= e;
        failed.add('inventory.ledger.part_ledger'.tr());
      }),
    ]);
    if (!mounted) return;
    if (firstError != null) InventoryScope.instance.onError(firstError!);
    setState(() {
      _loading = false;
      _loadError = failed.isEmpty
          ? null
          : 'inventory.ledger.load_failed'.tr(args: {'parts': failed.join(', '), 'detail': inventoryErrorMessage(firstError)});
    });
  }

  Future<void> _reloadRequisitions() async {
    setState(() => _loadingRequisitions = true);
    try {
      final list = await _repo.loadRequisitions();
      if (!mounted) return;
      setState(() {
        _requisitions = list;
        _requisitionError = null;
        _loadingRequisitions = false;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loadingRequisitions = false;
        final msg = e is Exception ? inventoryErrorMessage(e, '') : '';
        _requisitionError = msg.isNotEmpty
            ? 'inventory.ledger.req_load_error_msg'.tr(args: {'msg': msg})
            : 'inventory.ledger.req_load_error'.tr();
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_reload(), _reloadRequisitions()]);
  }

  // ---- Floating header (Rule 5.4) ----
  void _showHeader() {
    if (!_headerVisible) {
      _headerVisible = true;
      _headerAnim.forward();
    }
  }

  void _hideHeader() {
    if (_headerVisible) {
      _headerVisible = false;
      _headerAnim.reverse();
    }
  }

  bool _onUserScroll(UserScrollNotification n) {
    if (_searchFocusNode.hasFocus) return false;
    if (_scrollController.hasClients && _scrollController.offset <= 15) {
      _showHeader();
      return false;
    }
    if (n.direction == ScrollDirection.reverse) {
      _hideHeader();
    } else if (n.direction == ScrollDirection.forward) {
      _showHeader();
    }
    return false;
  }

  void _scrollTop() {
    if (_scrollController.hasClients && _scrollController.offset > 0) _scrollController.jumpTo(0);
    _showHeader();
  }

  // ---- Lọc như web ----
  List<LedgerRow> get _filtered {
    final q = _search.trim().toLowerCase();
    return _ledger.where((row) {
      if (_typeFilter != 'all') {
        final isReceipt = row.isReceiptRow;
        if (_typeFilter == 'IMPORT' && !isReceipt) return false;
        if (_typeFilter == 'EXPORT' && isReceipt) return false;
      }
      if (_warehouseFilter != 'all' && row.warehouseId != _warehouseFilter) return false;
      if (q.isNotEmpty) {
        final mat = _ws.materialById(row.materialId);
        final matchCode = row.transactionCode.toLowerCase().contains(q);
        final matchMat = (mat?.code.toLowerCase().contains(q) ?? false) || (mat?.name.toLowerCase().contains(q) ?? false);
        if (!matchCode && !matchMat) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasFilter => _typeFilter != 'all' || _warehouseFilter != 'all' || _search.trim().isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _typeFilter = 'all';
      _warehouseFilter = 'all';
      _search = '';
      _page = 1;
    });
    _scrollTop();
  }

  // ---- Hành động ----
  void _openDetail(LedgerRow row) {
    MovementDetailSheet.show(context, transaction: row, workspace: _ws, ledger: _ledger, userNames: _userNames);
  }

  Future<void> _openIssue(ProcedureRequisition req) async {
    final message = await BatchRequisitionSheet.show(context, req: req, workspace: _ws);
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF15803D)));
    // Đọc lại trạng thái cấp từ server: yêu cầu đã cấp tự rời danh sách.
    await _reloadRequisitions();
    await _reload();
    await widget.onRefresh();
  }

  void _openTransfer(String materialCode) {
    InventoryMovementDialog.show(
      context,
      items: widget.items,
      initialKind: 'transfer',
      initialMaterialCode: materialCode,
      title: 'inventory.ledger.transfer_title'.tr(args: {'code': materialCode}),
      withReservations: false,
      onSubmitted: () async {
        await _reload();
        await widget.onRefresh();
      },
    );
  }

  void _openProfile(String code) {
    if (code.isEmpty) return;
    LedgerItemProfileSheet.show(context, code: code, workspace: _ws);
  }

  // ---- Giao diện ----
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) => _content(caps),
    );
  }

  Widget _content(InventoryCapabilities caps) {
    final filtered = _filtered;
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(1, totalPages);
    final paged = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();
    const headerHeight = 150.0;

    return Stack(children: [
      NotificationListener<UserScrollNotification>(
        onNotification: _onUserScroll,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          edgeOffset: 140,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, headerHeight, 16, 24),
            children: [
              if (_loadError != null) _alert(_loadError!, onRetry: _reload, red: true),
              if (_requisitionError != null) _alert(_requisitionError!, onRetry: _reloadRequisitions),
              if (_requisitions.isNotEmpty || _loadingRequisitions) ...[
                LedgerRequisitionsCard(
                  requisitions: _requisitions,
                  loading: _loadingRequisitions,
                  workspace: _ws,
                  canWriteTransactions: caps.canWriteTransactions,
                  onOpenIssue: _openIssue,
                  onOpenTransfer: caps.canWriteTransactions ? _openTransfer : null,
                  onCheckStock: _openProfile,
                ),
                const SizedBox(height: 12),
              ],
              _ledgerHeader(filtered.length),
              const SizedBox(height: 10),
              if (paged.isEmpty)
                _empty()
              else
                ...paged.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _rowCard(r))),
              if (filtered.isNotEmpty) _pager(page, totalPages, filtered.length),
            ],
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ClipRect(
          child: SlideTransition(
            position: _headerSlide,
            child: AnimatedBuilder(
              animation: _headerAnim,
              builder: (context, child) => IgnorePointer(ignoring: _headerAnim.value == 0, child: child),
              child: _filterBar(),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _alert(String text, {required VoidCallback onRetry, bool red = false}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: red ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: red ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
        ),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12.5, color: red ? const Color(0xFF991B1B) : const Color(0xFF78350F)))),
          OutlinedButton(onPressed: onRetry, child: Text('inventory.ledger.reload'.tr())),
        ]),
      );

  Widget _filterBar() {
    final chips = [
      ('all', 'inventory.ledger.filter_type_all'.tr()),
      ('IMPORT', 'inventory.ledger.type_in'.tr()),
      ('EXPORT', 'inventory.ledger.type_out'.tr()),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.slate200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate200),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() {
                  _search = v;
                  _page = 1;
                }),
                style: const TextStyle(fontSize: 13, color: AppColors.slate900),
                decoration: InputDecoration(
                  hintText: 'inventory.ledger.search_placeholder'.tr(),
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.slate400),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.slate500),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _search = '';
                              _page = 1;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          if (_hasFilter) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _clearFilters,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
              child: Text('inventory.ledger.clear_filters'.tr(), style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips
                .map((c) => _chip(c.$2, _typeFilter == c.$1, () {
                      setState(() {
                        _typeFilter = c.$1;
                        _page = 1;
                      });
                      _scrollTop();
                    }, dark: false))
                .toList(),
          ),
        ),
        if (_ws.warehouses.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('inventory.ledger.filter_wh_all'.tr(), _warehouseFilter == 'all', () {
                setState(() {
                  _warehouseFilter = 'all';
                  _page = 1;
                });
                _scrollTop();
              }),
              ..._ws.warehouses.map((w) => _chip(
                    w.name.isNotEmpty ? '${w.code} — ${w.name}' : w.code,
                    _warehouseFilter == w.id,
                    () {
                      setState(() {
                        _warehouseFilter = w.id;
                        _page = 1;
                      });
                      _scrollTop();
                    },
                  )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool dark = true}) {
    final selColor = dark ? AppColors.slate900 : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: selected ? selColor : (dark ? Colors.white : AppColors.slate100),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? selColor : AppColors.slate300),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.slate600,
              )),
        ),
      ),
    );
  }

  Widget _ledgerHeader(int count) => Row(children: [
        Expanded(
          child: Text('inventory.ledger.ledger_title'.tr(),
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
        ),
        Text('inventory.ledger.ledger_count'.tr(args: {'n': count}),
            style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      ]);

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          const Icon(Icons.history_outlined, size: 44, color: AppColors.slate400),
          const SizedBox(height: 10),
          Text('inventory.ledger.empty'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        ]),
      );

  Widget _rowCard(LedgerRow row) {
    final material = _ws.materialById(row.materialId);
    final warehouse = _ws.warehouseById(row.warehouseId);
    final isReceipt = row.quantity > 0;
    final color = isReceipt ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final bg = isReceipt ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    return InkWell(
      onTap: () => _openDetail(row),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(row.transactionCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate900)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(LedgerFormat.hubTypeLabel(row.type),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(material?.code ?? row.materialId,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                  if (material != null && !material.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.slate300)),
                      child: Text('inventory.ledger.inactive'.tr(),
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                    ),
                ]),
                if (material != null)
                  Text(material.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              ]),
            ),
            const SizedBox(width: 8),
            Text('${isReceipt ? '+' : ''}${LedgerFormat.number(row.quantity)} ${material?.unit ?? ''}'.trim(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.warehouse_outlined, size: 13, color: AppColors.slate500),
            const SizedBox(width: 4),
            Expanded(
              child: Text(warehouse?.name ?? row.warehouseId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
            ),
            Text(LedgerFormat.dateTime(row.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ]),
          const SizedBox(height: 6),
          Text(row.note != null ? LedgerFormat.noteDates(row.note!) : '—',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _openDetail(row),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 13),
              label: Text('inventory.ledger.detail_button'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slate900,
                backgroundColor: const Color(0xFFEFF6FF),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pager(int page, int totalPages, int count) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('inventory.ledger.pager_info'.tr(args: {'page': page, 'pages': totalPages, 'n': count}),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
            ),
            Text('inventory.ledger.pager_show'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(width: 4),
            PopupMenuButton<int>(
              initialValue: _pageSize,
              onSelected: (v) => setState(() {
                _pageSize = v;
                _page = 1;
              }),
              itemBuilder: (_) => _pageSizes
                  .map((v) => PopupMenuItem(value: v, child: Text('inventory.ledger.pager_size'.tr(args: {'n': v}))))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.slate300)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('inventory.ledger.pager_size'.tr(args: {'n': _pageSize}), style: const TextStyle(fontSize: 12)),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: page <= 1
                  ? null
                  : () {
                      setState(() => _page = page - 1);
                      _scrollTop();
                    },
              child: Text('inventory.ledger.pager_prev'.tr()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$page / $totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate900)),
            ),
            OutlinedButton(
              onPressed: page >= totalPages
                  ? null
                  : () {
                      setState(() => _page = page + 1);
                      _scrollTop();
                    },
              child: Text('inventory.ledger.pager_next'.tr()),
            ),
          ]),
        ]),
      );
}
