import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/contracts/contracts_repository.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../../domain/crm_capabilities.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_material_picker.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../common/crm_warehouse_select.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'crm_contract_form_sheet.dart';
import 'crm_contract_terms.dart';
import 'crm_fulfillment_ui.dart';

/// Chi tiết hợp đồng (web `contracts/contract-detail.tsx`, T4-15): thông tin, dòng giá khung (kho giữ hàng từng
/// dòng), lưới đợt thanh toán (tổng phải bằng 100% giá trị), đơn bán gắn hợp đồng, tài liệu, nhật ký; xác nhận (giữ
/// hàng ở Kho), huỷ, hoàn thành, thanh lý.
class CrmContractDetailScreen extends StatefulWidget {
  final String contractId;
  const CrmContractDetailScreen({super.key, required this.contractId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmContractDetailScreen> createState() => _CrmContractDetailScreenState();
}

class _CrmContractDetailScreenState extends State<CrmContractDetailScreen> {
  final ContractsRepository _repo = ContractsRepository.instance;
  CrmContractDetail? _detail;
  String? _error;
  bool _busy = false;
  List<CrmTermDraft> _terms = [];
  String _termsBaseline = '';
  List<CrmMaterialStock> _stock = const [];
  String _stockKey = '';

  @override
  void dispose() {
    for (final t in _terms) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final next = await _repo.getContract(widget.contractId);
      if (!mounted) return;
      _apply(next);
      setState(() => _error = null);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.contracts.load_failed'));
    }
  }

  /// Nhận bản mới của hợp đồng: đặt lại lưới đợt thanh toán và tồn kho theo dòng (web `setDetail` + `setTerms`).
  void _apply(CrmContractDetail next) {
    _disposeLater(_terms);
    _terms = next.paymentTerms.map(CrmTermDraft.fromTerm).toList();
    _termsBaseline = _signature(_terms);
    setState(() => _detail = next);
    _loadStock(next);
  }

  /// Bỏ controller của lưới cũ sau khung hình kế (ô nhập còn gắn controller tới lúc dựng lại).
  void _disposeLater(List<CrmTermDraft> old) {
    if (old.isEmpty) return;
    final copy = List<CrmTermDraft>.of(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final t in copy) {
        t.dispose();
      }
    });
  }

  String _signature(List<CrmTermDraft> terms) => terms.map((t) => t.signature).join('\u0002');

  bool get _termsDirty => _signature(_terms) != _termsBaseline;

  /// Tồn khả dụng theo kho của mặt hàng trong hợp đồng Nháp (chọn kho giữ hàng từng dòng, D3-37).
  Future<void> _loadStock(CrmContractDetail detail) async {
    final key = detail.status == 'DRAFT'
        ? {for (final l in detail.lines.where((l) => !l.isService)) l.materialId}.join(',')
        : '';
    if (key == _stockKey) return;
    _stockKey = key;
    if (key.isEmpty) {
      setState(() => _stock = const []);
      return;
    }
    try {
      final rows = await CrmScope.instance.repository.loadMaterialStock(key.split(','));
      if (!mounted || key != _stockKey) return;
      setState(() => _stock = rows);
    } catch (_) {
      if (mounted && key == _stockKey) setState(() => _stock = const []);
    }
  }

  /// Web `run`: thao tác ghi, nhận bản mới, báo kết quả.
  Future<bool> _run(Future<CrmContractDetail> Function() work, {String? success}) async {
    setState(() => _busy = true);
    try {
      final next = await work();
      if (!mounted) return true;
      _apply(next);
      if (success != null) showCrmSnack(context, success);
      return true;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (mounted) showCrmSnack(context, crmErrorMessage(e, 'crm.contracts.action_failed'), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<CrmContractDetail> _replaceLines(CrmContractDetail d, List<Map<String, dynamic>> lines) =>
      _repo.updateContract(d.id, {'revision': d.revision, 'lines': lines});

  Future<bool> _act(CrmContractDetail d, String action, {String? reason}) => _run(
    () => _repo.contractAction(d.id, action, d.revision, reason: reason),
    success: 'crm.contracts.done.$action'.tr(),
  );

  Future<void> _confirm(CrmContractDetail d) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.contracts.confirm_title'.tr(),
      message: 'crm.contracts.confirm_message'.tr(),
      confirmLabel: 'crm.contracts.confirm_ok'.tr(),
    );
    if (ok && mounted) await _act(d, 'confirm');
  }

  Future<void> _askReason(CrmContractDetail d, String action) async {
    await showCrmReasonPrompt(
      context,
      title: 'crm.contracts.reason.$action.title'.tr(),
      label: 'crm.contracts.reason.$action.label'.tr(),
      confirmLabel: 'crm.common.confirm'.tr(),
      danger: action == 'cancel',
      maxLength: 2000,
      onSubmit: (r) async => await _act(d, action, reason: r) ? null : 'crm.common.error_generic'.tr(),
    );
  }

  Future<void> _edit(CrmContractDetail d) async {
    final saved = await showCrmContractForm(context, contract: d);
    if (saved == null || !mounted) return;
    _apply(saved);
    showCrmSnack(context, 'crm.contracts.saved'.tr());
  }

  Future<void> _addLine(CrmContractDetail d) async {
    await showCrmMaterialPicker(
      context,
      title: 'crm.contracts.lines.add_title'.tr(),
      withPrice: true,
      quantityOptional: d.type != 'SALE',
      onPick: (picked) async {
        // Lỗi ném lại để sheet giữ nguyên và hiện lời nhắn.
        final next = await _replaceLines(d, [
          ...d.lines.map((l) => l.toRequest()),
          {
            'materialId': picked.material.id,
            'quantity': picked.quantity,
            'unitPrice': picked.unitPrice ?? 0,
            'vatRate': picked.vatRate,
          },
        ]);
        if (!mounted) return;
        _apply(next);
        showCrmSnack(context, 'crm.contracts.lines.added'.tr());
      },
    );
  }

  Future<void> _removeLine(CrmContractDetail d, CrmContractLine line) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.contracts.lines.remove_confirm'.tr(),
      confirmLabel: 'crm.contracts.remove'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _replaceLines(d, d.lines.where((l) => l.id != line.id).map((l) => l.toRequest()).toList()),
      success: 'crm.contracts.lines.removed'.tr(),
    );
  }

  Future<void> _changeLineWarehouse(CrmContractDetail d, CrmContractLine line, String? code) => _run(
    () => _replaceLines(d, [
      for (final l in d.lines)
        l.id == line.id ? l.toRequest(warehouseCode: code, replaceWarehouse: true) : l.toRequest(),
    ]),
    success: 'crm.contracts.lines.warehouse_changed'.tr(),
  );

  void _addTerm() => setState(
    () => _terms = [
      ..._terms,
      CrmTermDraft(
        key: 'new-${DateTime.now().microsecondsSinceEpoch}',
        name: 'crm.contracts.terms.default_name'.tr(args: {'n': _terms.length + 1}),
        mode: 'percent',
        value: '',
        condition: 'SIGN',
        dueDate: '',
        dueDays: '',
        note: '',
      ),
    ],
  );

  void _removeTerm(int index) {
    final removed = _terms[index];
    setState(() => _terms = [..._terms]..removeAt(index));
    _disposeLater([removed]);
  }

  void _resetTerms(CrmContractDetail d) {
    _disposeLater(_terms);
    setState(() => _terms = d.paymentTerms.map(CrmTermDraft.fromTerm).toList());
  }

  Future<void> _saveTerms(CrmContractDetail d) => _run(
    () => _repo.savePaymentTerms(d.id, d.revision, [for (var i = 0; i < _terms.length; i++) _terms[i].toRequest(i)]),
    success: 'crm.contracts.terms.saved'.tr(),
  );

  Future<void> _trigger(CrmContractDetail d, CrmPaymentTerm term) async {
    final done = await showCrmTermTriggerSheet(
      context,
      term: term,
      onSubmit: (date) async {
        await _repo.triggerPaymentTerm(d.id, term.id, date);
      },
    );
    if (!done || !mounted) return;
    showCrmSnack(context, 'crm.contracts.terms.triggered'.tr());
    await _load();
  }

  Future<void> _openThen(Future<void> Function() open) async {
    await open();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(
        context,
        d == null ? CrmView.contracts.label : 'crm.contracts.detail_title'.tr(args: {'code': d.code}),
        subtitle: d?.title,
      ),
      body: CrmPageGuard(
        view: CrmView.contracts,
        onAllowed: _load,
        builder: (context, status) {
          if (d == null) {
            if (_error != null) return CrmStateView(error: _error, onRetry: _load);
            return const CrmStateView(loading: true);
          }
          return RefreshIndicator(onRefresh: _load, child: _content(d, status.capabilities));
        },
      ),
    );
  }

  Widget _content(CrmContractDetail d, CrmCapabilities caps) {
    final actions = crmContractActions(d.status, caps);
    final editable = actions.contains(CrmContractAction.edit);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _infoCard(d, actions),
        _linesCard(d, editable),
        CrmContractTermsCard(
          detail: d,
          terms: _terms,
          editable: editable,
          dirty: _termsDirty,
          busy: _busy,
          caps: caps,
          onChanged: () => setState(() {}),
          onAdd: _addTerm,
          onRemove: _removeTerm,
          onSave: () => _saveTerms(d),
          onReset: () => _resetTerms(d),
          onTrigger: (term) => _trigger(d, term),
        ),
        _ordersCard(d),
        CrmDocumentsPanel(entityType: 'contract', entityId: d.id, showTitle: true),
        const SizedBox(height: 12),
        CrmHistoryCard(
          history: d.history,
          statusLabel: (s) => kCrmContractStatuses.contains(s) ? crmContractStatusLabel(s) : null,
        ),
      ],
    );
  }

  Widget _infoCard(CrmContractDetail d, List<CrmContractAction> actions) {
    final scope = CrmScope.instance;
    final reservation = d.reservation;
    return CrmCard(
      title: 'crm.contracts.info'.tr(),
      trailing: CrmStatusPill(label: crmContractStatusLabel(d.status), tone: crmContractStatusTone(d.status)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmInfoRow(label: 'crm.contracts.f.title'.tr(), value: d.title),
          CrmInfoRow(label: 'crm.contracts.f.type'.tr(), value: crmContractTypeLabel(d.type)),
          CrmInfoRow(
            label: 'crm.contracts.f.customer'.tr(),
            child: CrmLinkText(
              '${d.customerCode} - ${d.customerName}',
              onTap: () => _openThen(() => CrmRoutes.openCustomer(context, d.customerId)),
            ),
          ),
          if (d.quoteId != null)
            CrmInfoRow(
              label: 'crm.contracts.f.quote'.tr(),
              child: CrmLinkText(
                d.quoteCode ?? '',
                onTap: () => _openThen(() => CrmRoutes.openQuote(context, d.quoteId!)),
              ),
            ),
          CrmInfoRow(label: 'crm.contracts.f.validity'.tr(), value: crmValidityText(d.validFrom, d.validTo)),
          if (d.signedDate != null && d.signedDate!.isNotEmpty)
            CrmInfoRow(label: 'crm.contracts.f.signed_date'.tr(), value: formatCrmDay(d.signedDate)),
          CrmInfoRow(label: 'crm.contracts.f.value'.tr(), value: formatCrmMoney(d.value)),
          if (d.warrantyMonths != null)
            CrmInfoRow(
              label: 'crm.contracts.f.warranty'.tr(),
              value: 'crm.contracts.f.months'.tr(args: {'n': d.warrantyMonths}),
            ),
          CrmInfoRow(
            label: 'crm.contracts.f.warehouse'.tr(),
            value: d.warehouseCode ?? 'crm.contracts.not_chosen'.tr(),
          ),
          CrmInfoRow(
            label: 'crm.contracts.f.reservation'.tr(),
            value: reservation == null
                ? 'crm.contracts.f.reservation_none'.tr()
                : [
                    reservation.reservationCode,
                    crmReservationStatusLabel(reservation.status),
                    if (reservation.expiresAt != null)
                      'crm.contracts.f.reservation_until'.tr(args: {'at': formatCrmDateTime(reservation.expiresAt)}),
                  ].join(' · '),
          ),
          CrmInfoRow(label: 'crm.contracts.f.owner'.tr(), value: scope.personName(d.ownerUserId)),
          if (d.note != null && d.note!.isNotEmpty) CrmInfoRow(label: 'crm.contracts.f.note'.tr(), value: d.note),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.contains(CrmContractAction.edit))
                  CrmButton(label: 'crm.contracts.edit'.tr(), outlined: true, onPressed: _busy ? null : () => _edit(d)),
                if (actions.contains(CrmContractAction.confirm))
                  CrmButton(
                    label: 'crm.contracts.confirm'.tr(),
                    onPressed: _busy || _termsDirty ? null : () => _confirm(d),
                  ),
                if (actions.contains(CrmContractAction.complete))
                  CrmButton(
                    label: 'crm.contracts.complete'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _askReason(d, 'complete'),
                  ),
                if (actions.contains(CrmContractAction.liquidate))
                  CrmButton(
                    label: 'crm.contracts.liquidate'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _askReason(d, 'liquidate'),
                  ),
                if (actions.contains(CrmContractAction.cancel))
                  CrmButton(
                    label: 'crm.contracts.cancel'.tr(),
                    outlined: true,
                    danger: true,
                    onPressed: _busy ? null : () => _askReason(d, 'cancel'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<CrmCatalogMaterialStock>? _stockOf(String materialId) {
    for (final s in _stock) {
      if (s.materialId == materialId) return s.byWarehouse;
    }
    return null;
  }

  Widget _linesCard(CrmContractDetail d, bool editable) {
    return CrmCard(
      title: 'crm.contracts.lines.title'.tr(),
      trailing: editable
          ? TextButton.icon(
              onPressed: _busy ? null : () => _addLine(d),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('crm.contracts.lines.add'.tr()),
            )
          : null,
      child: d.lines.isEmpty
          ? Text('crm.contracts.lines.empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final line in d.lines) _lineTile(d, line, editable)],
            ),
    );
  }

  Widget _lineTile(CrmContractDetail d, CrmContractLine line, bool editable) {
    final Widget warehouse;
    if (line.isService) {
      warehouse = Text(
        'crm.contracts.lines.no_reserve'.tr(),
        style: const TextStyle(fontSize: 13, color: CrmColors.muted),
      );
    } else if (editable) {
      warehouse = CrmWarehouseSelect(
        value: line.warehouseCode,
        placeholder: d.warehouseCode != null
            ? 'crm.contracts.lines.by_contract'.tr(args: {'code': d.warehouseCode})
            : 'crm.warehouse.placeholder'.tr(),
        stock: _stockOf(line.materialId),
        enabled: !_busy,
        onChanged: (code) => _changeLineWarehouse(d, line, code),
      );
    } else {
      warehouse = Text(
        line.warehouseCode ??
            (d.warehouseCode != null
                ? 'crm.contracts.lines.by_contract_suffix'.tr(args: {'code': d.warehouseCode})
                : 'crm.contracts.not_chosen'.tr()),
        style: const TextStyle(fontSize: 13, color: CrmColors.text),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CrmColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CrmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CrmCodeBadge('#${line.lineNo}'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${line.materialCode} ${line.materialName}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
                ),
              ),
              if (line.isService) CrmStatusPill(label: 'crm.contracts.lines.service'.tr(), dense: true),
              if (editable)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'crm.contracts.remove'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: CrmColors.danger),
                  onPressed: _busy ? null : () => _removeLine(d, line),
                ),
            ],
          ),
          const SizedBox(height: 4),
          CrmInfoRow(
            label: 'crm.contracts.lines.quantity'.tr(),
            value: line.quantity == null
                ? 'crm.contracts.lines.by_order'.tr()
                : '${formatCrmQuantity(line.quantity)} ${line.unit}',
          ),
          CrmInfoRow(label: 'crm.contracts.lines.frame_price'.tr(), value: formatCrmMoney(line.unitPrice)),
          CrmInfoRow(label: 'crm.contracts.lines.vat'.tr(), value: formatCrmPercent(line.vatRate)),
          CrmInfoRow(
            label: 'crm.contracts.lines.amount'.tr(),
            value: line.lineAmount == null ? '' : formatCrmMoney(line.lineAmount),
          ),
          CrmInfoRow(label: 'crm.contracts.lines.warehouse'.tr(), child: warehouse),
        ],
      ),
    );
  }

  Widget _ordersCard(CrmContractDetail d) {
    return CrmCard(
      title: 'crm.contracts.orders_title'.tr(),
      child: d.orders.isEmpty
          ? Text('crm.contracts.orders_empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              children: [
                for (final o in d.orders)
                  InkWell(
                    onTap: () => _openThen(() => CrmRoutes.openOrder(context, o.id)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.code,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: CrmColors.link,
                                  ),
                                ),
                                Text(
                                  formatCrmDay(o.orderDate),
                                  style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CrmStatusPill(
                                dense: true,
                                label: crmOrderStatusLabel(o.status),
                                tone: crmOrderStatusTone(o.status),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCrmMoney(o.totalAmount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
