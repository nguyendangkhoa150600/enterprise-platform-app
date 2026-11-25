import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/utils/formatters.dart';
import '../../features/inventory/data/documents/stock_document_api.dart';
import '../../features/inventory/domain/documents/stock_document_logic.dart';
import '../../features/inventory/domain/documents/stock_document_models.dart';
import '../../features/inventory/domain/inventory_capabilities.dart';
import '../../features/inventory/presentation/documents/document_widgets.dart';
import '../../features/inventory/presentation/documents/legacy_entry_sheet.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';
import 'components/inventory_document_create_dialog.dart';
import 'components/inventory_document_detail_sheet.dart';

/// Tab "Xuất/nhập kho" — góc nhìn "Tất cả" (web `MovementList`: danh sách gộp chứng từ và bút toán cũ từ
/// `GET /stock-movements`) và "Chờ duyệt" (web `StockDocumentApproval`, khi [initialStatus] = `PENDING`).
class InventoryDocumentsScreen extends StatefulWidget {
  /// `PENDING`: góc nhìn Chờ duyệt. Giá trị khác: đặt sẵn bộ lọc trạng thái của danh sách gộp.
  final String? initialStatus;
  final String? title;
  final String? subtitle;

  /// Nhúng trong tab "Xuất/nhập kho" của trang Kho hàng: ẩn thanh tiêu đề riêng.
  final bool embedded;

  /// Số chứng từ Chờ duyệt server trả kèm danh sách gộp, để hiện trên nhãn góc nhìn.
  final ValueChanged<int>? onPendingCount;

  const InventoryDocumentsScreen({
    super.key,
    this.initialStatus,
    this.embedded = false,
    this.title,
    this.subtitle,
    this.onPendingCount,
  });

  @override
  State<InventoryDocumentsScreen> createState() => _InventoryDocumentsScreenState();
}

class _InventoryDocumentsScreenState extends State<InventoryDocumentsScreen> {
  static const int _pageSize = 20;
  final _api = StockDocumentApi.instance;

  bool get _approvalMode => widget.initialStatus == 'PENDING';

  DocRefs _refs = DocRefs.empty;

  // Bộ lọc
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String _sourceType = '';
  String _docType = '';
  late String _status = _approvalMode ? '' : (widget.initialStatus ?? '');
  String _warehouseCode = '';
  String? _fromDate;
  String? _toDate;
  bool _filtersOpen = false;

  // Danh sách gộp
  List<StockMovementRow> _rows = [];
  // Chờ duyệt
  List<StockDoc> _pending = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _loadRefs();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    try {
      final refs = await _api.refs();
      if (!mounted) return;
      setState(() => _refs = refs);
    } catch (e) {
      InventoryScope.instance.onError(e);
    }
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_approvalMode) {
        final page = await _api.loadDocuments(
          status: 'PENDING',
          docType: _docType.isEmpty ? null : _docType,
          warehouseCode: _warehouseCode.isEmpty ? null : _warehouseCode,
          limit: 100,
        );
        if (!mounted || gen != _generation) return;
        setState(() {
          _pending = page.items;
          _total = page.total;
          _loading = false;
        });
      } else {
        final page = await _fetchMovements(0);
        if (!mounted || gen != _generation) return;
        setState(() {
          _rows = page.rows;
          _total = page.total;
          _loading = false;
        });
        widget.onPendingCount?.call(page.pendingCount);
      }
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = inventoryErrorMessage(
            e, _approvalMode ? 'inventory.documents.error.load_documents' : 'inventory.documents.error.load_movements');
      });
    }
  }

  Future<StockMovementPage> _fetchMovements(int offset) => _api.loadMovements(
        search: _search,
        sourceType: _sourceType,
        docType: _docType,
        status: _status,
        warehouseCode: _warehouseCode,
        fromDate: _fromDate,
        toDate: _toDate,
        limit: _pageSize,
        offset: offset,
      );

  Future<void> _loadMore() async {
    if (_approvalMode || _loading || _loadingMore || _rows.length >= _total) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchMovements(_rows.length);
      if (!mounted || gen != _generation) return;
      setState(() {
        _rows = [..._rows, ...page.rows];
        _total = page.total;
        _loadingMore = false;
      });
      widget.onPendingCount?.call(page.pendingCount);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted || gen != _generation) return;
      setState(() {
        _loadingMore = false;
        _error = inventoryErrorMessage(e, 'inventory.documents.error.load_movements');
      });
    }
  }

  void _filterChanged(VoidCallback apply) {
    setState(apply);
    _reload();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final next = text.trim();
      if (next == _search) return;
      _search = next;
      _reload();
    });
  }

  // ---------------------------------------------------------------- Chứng từ: mở, sửa, lập

  Future<void> _openDocument(String id) async {
    try {
      final doc = await _api.load(id);
      if (!mounted) return;
      await _showDetail(doc);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      showDocSnack(context, inventoryErrorMessage(e, 'inventory.documents.error.open_document'), error: true);
    }
  }

  Future<void> _showDetail(StockDoc doc) async {
    final toEdit = await InventoryDocumentDetailSheet.show(
      context,
      doc,
      allowEdit: !_approvalMode,
      closeOnChange: _approvalMode,
      onChanged: (_, _) => _reload(),
    );
    if (toEdit == null || !mounted) return;
    await _openForm(DocumentDraft.fromDocument(toEdit), documentId: toEdit.id);
  }

  Future<void> _openForm(DocumentDraft draft, {String? documentId}) async {
    var refs = _refs;
    if (refs.warehouses.isEmpty && refs.materials.isEmpty) {
      try {
        refs = await _api.refs(force: true);
        if (!mounted) return;
        setState(() => _refs = refs);
      } catch (e) {
        InventoryScope.instance.onError(e);
        if (!mounted) return;
        showDocSnack(context, inventoryErrorMessage(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    final result = await InventoryDocumentCreateDialog.show(context, initial: draft, refs: refs, documentId: documentId);
    if (result == null || !mounted) return;
    showDocSnack(context, result.message);
    _reload();
    await _showDetail(result.document);
  }

  void _createDocument() {
    final firstActive = _refs.warehouses.where((w) => w.isActive).firstOrNull?.code ?? '';
    _openForm(DocumentDraft.empty('RECEIPT_PURCHASE', firstActive));
  }

  // ---------------------------------------------------------------- Giao diện

  List<DocOption> get _warehouseOptions => [
        DocOption('', 'inventory.documents.filter.all_warehouses'.tr()),
        for (final w in _refs.warehouses) DocOption(w.code, w.label),
      ];

  List<DocOption> get _typeOptions => [
        DocOption('', 'inventory.documents.filter.all_types'.tr()),
        for (final t in kStockDocumentTypes) DocOption(t, docTypeLabel(t)),
      ];

  @override
  Widget build(BuildContext context) {
    final body = ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) => Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _approvalMode ? _approvalHeader(caps) : _movementHeader(caps),
        ),
        const Divider(height: 1, color: kDocBorder),
        Expanded(child: _listBody()),
      ]),
    );
    if (widget.embedded) return Container(color: AppColors.slate50, child: body);
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.title ??
                (_approvalMode ? 'inventory.documents.pending.title'.tr() : 'inventory.documents.movements.title'.tr()),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (widget.subtitle != null)
            Text(widget.subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
        ]),
      ),
      body: body,
    );
  }

  Widget _titleRow(String title, String count, List<Widget> actions) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
            const SizedBox(height: 2),
            Text(count, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ]),
        ),
        ...actions,
      ]);

  Widget _reloadButton() => IconButton(
        tooltip: 'inventory.documents.common.reload'.tr(),
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, size: 20, color: AppColors.slate600),
      );

  Widget _movementHeader(InventoryCapabilities caps) {
    final activeFilters = [_sourceType, _docType, _status, _warehouseCode, _fromDate ?? '', _toDate ?? '']
        .where((v) => v.isNotEmpty)
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _titleRow(
        'inventory.documents.movements.title'.tr(),
        'inventory.documents.movements.count'.tr(args: {'n': formatQty(_total)}),
        [
          _reloadButton(),
          if (caps.canWriteTransactions)
            ElevatedButton.icon(
              style: docButtonStyle(primary: true),
              onPressed: _createDocument,
              icon: const Icon(Icons.note_add_outlined, size: 16),
              label: Text('inventory.documents.movements.create'.tr()),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: docInputDecoration(hint: 'inventory.documents.filter.search_hint'.tr()).copyWith(
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
            ),
            onChanged: _onSearch,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.slate300),
            foregroundColor: AppColors.slate700,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.tune, size: 16),
          label: Text(activeFilters > 0
              ? 'inventory.documents.filter.toggle_count'.tr(args: {'n': activeFilters})
              : 'inventory.documents.filter.toggle'.tr()),
        ),
      ]),
      if (_filtersOpen) ...[
        const SizedBox(height: 10),
        _pairRow(
          DocSelect(
            label: 'inventory.documents.field.source_origin'.tr(),
            options: [
              DocOption('', 'inventory.documents.filter.all_sources'.tr()),
              for (final s in kMovementSourceCodes) DocOption(s, sourceTypeLabel(s)),
            ],
            value: _sourceType,
            onChanged: (v) => _filterChanged(() => _sourceType = v),
          ),
          DocSelect(
            label: 'inventory.documents.field.type'.tr(),
            options: _typeOptions,
            value: _docType,
            onChanged: (v) => _filterChanged(() => _docType = v),
          ),
        ),
        const SizedBox(height: 8),
        _pairRow(
          DocSelect(
            label: 'inventory.documents.field.status'.tr(),
            options: [
              DocOption('', 'inventory.documents.filter.all_statuses'.tr()),
              for (final s in kStockDocumentStatuses) DocOption(s, docStatusLabel(s)),
            ],
            value: _status,
            onChanged: (v) => _filterChanged(() => _status = v),
          ),
          DocSelect(
            label: 'inventory.documents.field.warehouse'.tr(),
            options: _warehouseOptions,
            value: _warehouseCode,
            onChanged: (v) => _filterChanged(() => _warehouseCode = v),
          ),
        ),
        const SizedBox(height: 8),
        _pairRow(
          DocDateField(
            label: 'inventory.documents.filter.from_date'.tr(),
            value: _fromDate,
            onChanged: (v) => _filterChanged(() => _fromDate = v),
          ),
          DocDateField(
            label: 'inventory.documents.filter.to_date'.tr(),
            value: _toDate,
            onChanged: (v) => _filterChanged(() => _toDate = v),
          ),
        ),
      ],
    ]);
  }

  Widget _pairRow(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ]);

  Widget _approvalHeader(InventoryCapabilities caps) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _titleRow(
        'inventory.documents.pending.title'.tr(),
        'inventory.documents.pending.count'.tr(args: {'n': formatQty(_total)}),
        [_reloadButton()],
      ),
      if (!caps.canApproveDocuments) ...[
        const SizedBox(height: 8),
        DocBanner('inventory.documents.pending.view_only'.tr()),
      ],
      const SizedBox(height: 10),
      _pairRow(
        DocSelect(
          label: 'inventory.documents.field.type'.tr(),
          options: _typeOptions,
          value: _docType,
          onChanged: (v) => _filterChanged(() => _docType = v),
        ),
        DocSelect(
          label: 'inventory.documents.field.warehouse'.tr(),
          options: _warehouseOptions,
          value: _warehouseCode,
          onChanged: (v) => _filterChanged(() => _warehouseCode = v),
        ),
      ),
    ]);
  }

  Widget _listBody() {
    final count = _approvalMode ? _pending.length : _rows.length;
    if (_loading && count == 0) return const Center(child: CircularProgressIndicator());
    final children = <Widget>[
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DocBanner(
            _error!,
            error: true,
            trailing: _approvalMode
                ? null
                : TextButton(onPressed: _reload, child: Text('inventory.documents.common.retry'.tr())),
          ),
        ),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (count == 0 && !_loading && _error == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(
              _approvalMode ? 'inventory.documents.pending.empty'.tr() : 'inventory.documents.movements.empty'.tr(),
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      if (_approvalMode)
        for (final doc in _pending) ...[_pendingCard(doc), const SizedBox(height: 8)]
      else
        for (final row in _rows) ...[_movementCard(row), const SizedBox(height: 8)],
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
    ];
    return RefreshIndicator(
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) _loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: children,
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kDocBorder),
      );

  static const _muted = TextStyle(fontSize: 12, color: AppColors.slate500);

  Widget _movementCard(StockMovementRow row) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => row.isLegacy ? showLegacyEntrySheet(context, row) : _openDocument(row.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.code,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                if (row.isLegacy) Text('inventory.documents.movements.legacy'.tr(), style: _muted),
              ]),
            ),
            DocStatusBadge(row.status),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text(movementTypeLabel(row),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
            ),
            Text(warehousePairLabel(row.warehouseCode, row.targetWarehouseCode),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ]),
          const SizedBox(height: 4),
          Text(movementMaterialLabel(row),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate700), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Text(Formatters.formatDate(row.movementDate), style: _muted),
            const Text('  ·  ', style: _muted),
            Text(sourceTypeLabel(row.sourceType), style: _muted),
            const Spacer(),
            Text(
              'inventory.documents.movements.quantity'.tr(args: {'n': formatQty(row.quantityTotal)}),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ]),
          const SizedBox(height: 2),
          UserNameText(row.createdBy, prefix: 'inventory.documents.movements.created_by'.tr(), style: _muted),
        ]),
      ),
    );
  }

  Widget _pendingCard(StockDoc doc) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDetail(doc),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(doc.code,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            Text(warehousePairLabel(doc.warehouseCode, doc.targetWarehouseCode),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ]),
          const SizedBox(height: 4),
          Text(docTypeLabel(doc.docType),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
          const SizedBox(height: 4),
          Row(children: [
            Text(Formatters.formatDate(doc.documentDate), style: _muted),
            const Spacer(),
            Text(
              'inventory.documents.pending.lines'.tr(args: {'n': doc.lines.length, 'qty': formatQty(doc.totalQuantity)}),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ]),
          const SizedBox(height: 4),
          Text('inventory.documents.field.note_value'.tr(args: {'note': doc.note ?? '—'}),
              style: _muted, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          DocumentActionBar(
            key: ValueKey('${doc.id}:${doc.status}'),
            document: doc,
            exclude: const [DocAction.cancel, DocAction.edit],
            onChanged: (_, message) {
              showDocSnack(context, message);
              _reload();
            },
          ),
        ]),
      ),
    );
  }
}
