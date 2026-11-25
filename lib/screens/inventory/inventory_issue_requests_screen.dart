import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/utils/formatters.dart';
import '../../features/inventory/data/documents/stock_document_api.dart';
import '../../features/inventory/domain/documents/stock_document_logic.dart';
import '../../features/inventory/domain/documents/stock_document_models.dart';
import '../../features/inventory/presentation/documents/document_widgets.dart';
import '../../features/inventory/presentation/documents/issue_request_workbench_sheet.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';

/// Yêu cầu xuất từ đơn bán (web `IssueRequestPanel`): chứng từ xuất NHÁP (xuất bán, xuất bảo hành) do Bán hàng
/// tạo, gắn giữ hàng. Chạm một yêu cầu để chọn lô, serial và ghi sổ.
class InventoryIssueRequestsScreen extends StatefulWidget {
  /// Nhúng trong tab "Xuất/nhập kho" của trang Kho hàng: ẩn thanh tiêu đề riêng.
  final bool embedded;

  const InventoryIssueRequestsScreen({super.key, this.embedded = false});

  @override
  State<InventoryIssueRequestsScreen> createState() => _InventoryIssueRequestsScreenState();
}

class _InventoryIssueRequestsScreenState extends State<InventoryIssueRequestsScreen> {
  final _api = StockDocumentApi.instance;
  DocRefs _refs = DocRefs.empty;
  List<StockDoc> _documents = [];
  List<ReservationRow> _reservations = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  String _docType = '';
  String _sourceType = '';
  String _warehouseCode = '';

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _loadRefs();
    _reload();
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
      final results = await Future.wait([
        _api.loadDocuments(
          docTypes: _docType.isNotEmpty ? [_docType] : kIssueRequestTypes,
          status: 'DRAFT',
          warehouseCode: _warehouseCode.isEmpty ? null : _warehouseCode,
          limit: 200,
        ),
        _api.reservations(),
      ]);
      if (!mounted || gen != _generation) return;
      setState(() {
        _documents = (results[0] as StockDocPage).items;
        _reservations = results[1] as List<ReservationRow>;
        _loading = false;
      });
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = inventoryErrorMessage(e, 'inventory.documents.error.load_requests');
      });
    }
  }

  /// Lọc nguồn ở client: danh sách nguồn lấy từ chính các yêu cầu đang có.
  List<DocOption> get _sourceOptions {
    final values = _documents.map((d) => d.sourceType ?? '').where((v) => v.isNotEmpty).toSet();
    return [
      DocOption('', 'inventory.documents.filter.all_sources'.tr()),
      for (final v in values) DocOption(v, sourceTypeLabel(v), v),
    ];
  }

  Future<void> _open(StockDoc doc) async {
    var refs = _refs;
    if (refs.materials.isEmpty) {
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
    await showIssueRequestWorkbench(
      context,
      document: doc,
      reservations: _reservations,
      refs: refs,
      canWrite: InventoryScope.instance.capabilities.value.canWriteTransactions,
      onSaved: (_, message) {
        showDocSnack(context, message);
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _documents.where((d) => _sourceType.isEmpty || d.sourceType == _sourceType).toList();
    final body = Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('inventory.documents.requests.title'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                const SizedBox(height: 2),
                Text('inventory.documents.requests.count'.tr(args: {'n': visible.length}),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
              ]),
            ),
            IconButton(
              tooltip: 'inventory.documents.common.reload'.tr(),
              onPressed: _loading ? null : _reload,
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.slate600),
            ),
          ]),
          const SizedBox(height: 10),
          DocSelect(
            label: 'inventory.documents.field.type'.tr(),
            options: [
              DocOption('', 'inventory.documents.requests.all_types'.tr()),
              for (final t in kIssueRequestTypes) DocOption(t, docTypeLabel(t)),
            ],
            value: _docType,
            onChanged: (v) {
              setState(() => _docType = v);
              _reload();
            },
          ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DocSelect(
                label: 'inventory.documents.field.source'.tr(),
                options: _sourceOptions,
                value: _sourceType,
                onChanged: (v) => setState(() => _sourceType = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DocSelect(
                label: 'inventory.documents.field.warehouse'.tr(),
                options: [
                  DocOption('', 'inventory.documents.filter.all_warehouses'.tr()),
                  for (final w in _refs.warehouses) DocOption(w.code, w.label),
                ],
                value: _warehouseCode,
                onChanged: (v) {
                  setState(() => _warehouseCode = v);
                  _reload();
                },
              ),
            ),
          ]),
        ]),
      ),
      const Divider(height: 1, color: kDocBorder),
      Expanded(
        child: _loading && visible.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_error != null) ...[DocBanner(_error!, error: true), const SizedBox(height: 10)],
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    if (visible.isEmpty && !_loading && _error == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('inventory.documents.requests.empty'.tr(),
                              style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                        ),
                      ),
                    for (final doc in visible) ...[_card(doc), const SizedBox(height: 8)],
                    if (visible.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('inventory.documents.requests.hint'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                      ),
                  ],
                ),
              ),
      ),
    ]);
    if (widget.embedded) return Container(color: AppColors.slate50, child: body);
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('inventory.documents.requests.title'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: body,
    );
  }

  Widget _card(StockDoc doc) {
    const muted = TextStyle(fontSize: 12, color: AppColors.slate500);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(doc),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kDocBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(doc.code,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            Text(doc.warehouseCode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700)),
          ]),
          const SizedBox(height: 2),
          Text('${docTypeLabel(doc.docType)} · ${Formatters.formatDate(doc.documentDate)}', style: muted),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                '${sourceTypeLabel(doc.sourceType)}${(doc.sourceId ?? '').isNotEmpty ? ' · ${doc.sourceId!.length > 8 ? doc.sourceId!.substring(0, 8) : doc.sourceId!}' : ''}',
                style: muted,
              ),
            ),
            Text(
              'inventory.documents.movements.quantity'.tr(args: {'n': formatQty(doc.totalQuantity)}),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ]),
        ]),
      ),
    );
  }
}
