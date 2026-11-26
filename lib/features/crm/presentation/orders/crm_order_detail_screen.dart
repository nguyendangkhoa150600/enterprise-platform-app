import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/orders/orders_repository.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/orders/crm_order_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_material_picker.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../common/crm_warehouse_select.dart';
import '../contracts/crm_fulfillment_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../documents/crm_documents_panel.dart';
import '../utils/crm_scope.dart';
import 'crm_order_create_sheet.dart';
import 'crm_order_receivable_panel.dart';
import 'crm_order_sheets.dart';

/// Chi tiết đơn bán (web `orders/order-detail.tsx`, T4-16): thông tin, ghi chú thông tin đơn, công nợ / duyệt vượt
/// hạn mức, dòng hàng (bảng giá, kho giữ hàng, đã giữ, đã lập đợt, đã giao, serial, giá vốn thực tế), kế hoạch giao
/// (yêu cầu xuất kho, cờ giao trễ), tài liệu, nhật ký; xác nhận (giữ hàng tất cả hoặc không), huỷ, đóng.
class CrmOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const CrmOrderDetailScreen({super.key, required this.orderId});

  /// Màn đã dựng xong (chỉ để theo dõi; màn chi tiết không có ô Trang chủ).
  static const bool ready = true;

  @override
  State<CrmOrderDetailScreen> createState() => _CrmOrderDetailScreenState();
}

class _CrmOrderDetailScreenState extends State<CrmOrderDetailScreen> {
  final OrdersRepository _repo = OrdersRepository.instance;
  CrmOrderDetail? _detail;
  String? _error;
  bool _busy = false;
  List<CrmMaterialStock> _stock = const [];
  String _stockKey = '';
  List<CrmPriceListOption> _priceLists = const [];
  bool _priceListsLoaded = false;
  String? _priceListError;

  Future<void> _load() async {
    _loadPriceLists();
    try {
      final next = await _repo.getOrder(widget.orderId);
      if (!mounted) return;
      _apply(next);
      setState(() => _error = null);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.orders.load_failed'));
    }
  }

  Future<void> _loadPriceLists() async {
    if (_priceListsLoaded) return;
    try {
      final rows = await _repo.listPriceLists();
      if (mounted) setState(() => _priceLists = rows);
    } catch (_) {
      // Lỗi: danh sách bảng giá rỗng.
    } finally {
      if (mounted) setState(() => _priceListsLoaded = true);
    }
  }

  void _apply(CrmOrderDetail next) {
    setState(() => _detail = next);
    _loadStock(next);
  }

  /// Tồn khả dụng theo kho của các mặt hàng trong đơn (lỗi Kho thì không hiện gợi ý tồn).
  Future<void> _loadStock(CrmOrderDetail d) async {
    final key = d.lines.map((l) => l.materialId).join(',');
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

  /// Web `run`.
  Future<bool> _run(Future<CrmOrderDetail> Function() work, {String? success}) async {
    setState(() => _busy = true);
    try {
      final next = await work();
      if (!mounted) return true;
      _apply(next);
      if (success != null) showCrmSnack(context, success);
      return true;
    } catch (e) {
      CrmScope.instance.onError(e);
      if (mounted) showCrmSnack(context, crmErrorMessage(e, 'crm.orders.action_failed'), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _act(CrmOrderDetail d, String action, {String? reason}) =>
      _run(() => _repo.orderAction(d.id, action, d.revision, reason: reason), success: 'crm.orders.done.$action'.tr());

  Future<void> _confirm(CrmOrderDetail d) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.orders.confirm_title'.tr(),
      message: 'crm.orders.confirm_message'.tr(),
      confirmLabel: 'crm.orders.confirm_ok'.tr(),
    );
    if (ok && mounted) await _act(d, 'confirm');
  }

  Future<void> _askReason(CrmOrderDetail d, String action) async {
    await showCrmReasonPrompt(
      context,
      title: 'crm.orders.reason.$action.title'.tr(),
      label: 'crm.orders.reason.$action.label'.tr(),
      confirmLabel: 'crm.common.confirm'.tr(),
      danger: action == 'cancel',
      maxLength: 2000,
      onSubmit: (r) async => await _act(d, action, reason: r) ? null : 'crm.common.error_generic'.tr(),
    );
  }

  Future<void> _editHeader(CrmOrderDetail d) async {
    final warehouses = {for (final s in _stock) ...s.byWarehouse.map((e) => e.warehouseCode)}.toList()..sort();
    final done = await showCrmOrderHeaderSheet(
      context,
      order: d,
      warehouses: warehouses,
      onSave: (patch) async {
        final next = await _repo.updateOrder(d.id, {'revision': d.revision, ...patch});
        if (mounted) _apply(next);
      },
    );
    if (done && mounted) showCrmSnack(context, 'crm.orders.saved'.tr());
  }

  Future<void> _editInfoNote(CrmOrderDetail d) async {
    await showCrmOrderInfoNoteSheet(
      context,
      initial: d.infoNote,
      onSave: (note) async {
        final next = await _repo.saveInfoNote(d.id, d.revision, note);
        if (mounted) _apply(next);
      },
    );
  }

  Future<void> _applyPriceList(CrmOrderDetail d, String next) async {
    setState(() {
      _priceListError = null;
      _busy = true;
    });
    try {
      final saved = await _repo.updateOrder(d.id, {'revision': d.revision, 'priceListId': next.isEmpty ? null : next});
      if (!mounted) return;
      _apply(saved);
      showCrmSnack(
        context,
        d.lines.isNotEmpty ? 'crm.orders.price_list_changed'.tr() : 'crm.orders.price_list_chosen'.tr(),
      );
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      final message = crmErrorMessage(e, 'crm.orders.price_list_failed');
      setState(() => _priceListError = message);
      showCrmSnack(context, message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePriceList(CrmOrderDetail d, String next) async {
    if (next == (d.priceListId ?? '')) return;
    if (d.lines.isNotEmpty) {
      final ok = await showCrmConfirm(
        context,
        title: 'crm.orders.price_list_change_title'.tr(),
        message: 'crm.orders.price_list_change_message'.tr(),
        confirmLabel: 'crm.orders.agree'.tr(),
      );
      if (!ok || !mounted) return;
    }
    await _applyPriceList(d, next);
  }

  Future<void> _addLine(CrmOrderDetail d) async {
    await showCrmMaterialPicker(
      context,
      title: 'crm.orders.lines.add_title'.tr(),
      withOverridePrice: true,
      onPick: (picked) async {
        final next = await _repo.updateOrder(d.id, {
          'revision': d.revision,
          'lines': [
            ...d.lines.map((l) => l.toRequest()),
            {
              'materialId': picked.material.id,
              'quantity': picked.quantity ?? 1,
              'overrideUnitPrice': picked.unitPrice,
              'overrideVatRate': picked.overrideVatRate,
            },
          ],
        });
        if (!mounted) return;
        _apply(next);
        showCrmSnack(context, 'crm.orders.lines.added'.tr());
      },
    );
  }

  Future<void> _removeLine(CrmOrderDetail d, CrmOrderLine line) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.orders.lines.remove_title'.tr(),
      message: 'crm.orders.lines.remove_message'.tr(),
      confirmLabel: 'crm.orders.remove'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repo.updateOrder(d.id, {
        'revision': d.revision,
        'lines': d.lines.where((l) => l.id != line.id).map((l) => l.toRequest()).toList(),
      }),
      success: 'crm.orders.lines.removed'.tr(),
    );
  }

  Future<void> _changeLineWarehouse(CrmOrderDetail d, CrmOrderLine line, String? code) => _run(
    () => _repo.updateOrder(d.id, {
      'revision': d.revision,
      'lineWarehouses': [
        {'lineId': line.id, 'warehouseCode': code},
      ],
    }),
    success: 'crm.orders.lines.warehouse_changed'.tr(),
  );

  Future<void> _plan(CrmOrderDetail d, [CrmDeliveryPlan? delivery]) async {
    final done = await showCrmDeliverySheet(
      context,
      order: d,
      delivery: delivery,
      onSave: (body) async {
        final next = await _repo.saveDelivery(d.id, delivery?.id, {'revision': d.revision, ...body});
        if (mounted) _apply(next);
      },
    );
    if (done && mounted) showCrmSnack(context, 'crm.orders.delivery.saved'.tr());
  }

  Future<void> _cancelDelivery(CrmOrderDetail d, CrmDeliveryPlan delivery) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.orders.delivery.cancel_confirm'.tr(),
      confirmLabel: 'crm.orders.remove'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repo.deliveryAction(d.id, delivery.id, 'cancel', d.revision),
      success: 'crm.orders.delivery.cancelled'.tr(),
    );
  }

  Future<void> _requestIssue(CrmOrderDetail d, CrmDeliveryPlan delivery) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.orders.delivery.request_title'.tr(),
      message: 'crm.orders.delivery.request_message'.tr(),
      confirmLabel: 'crm.orders.delivery.request_ok'.tr(),
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repo.deliveryAction(d.id, delivery.id, 'request-issue', d.revision),
      success: 'crm.orders.delivery.requested'.tr(),
    );
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
        d == null ? CrmView.orders.label : 'crm.orders.detail_title'.tr(args: {'code': d.code}),
        subtitle: d == null ? null : '${d.summary.customerCode} - ${d.summary.customerName}',
      ),
      body: CrmPageGuard(
        view: CrmView.orders,
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

  Widget _content(CrmOrderDetail d, CrmCapabilities caps) {
    final actions = crmOrderActions(d, caps);
    final linesEditable = actions.contains(CrmOrderAction.edit) && d.source != 'QUOTE';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _infoCard(d, caps, actions, linesEditable),
        _linesCard(d, actions, linesEditable),
        _deliveriesCard(d, caps, actions),
        CrmDocumentsPanel(entityType: 'sales_order', entityId: d.id, showTitle: true),
        const SizedBox(height: 12),
        CrmHistoryCard(
          history: d.history,
          statusLabel: (s) => kCrmOrderStatuses.contains(s) ? crmOrderStatusLabel(s) : null,
        ),
      ],
    );
  }

  Widget _infoCard(CrmOrderDetail d, CrmCapabilities caps, List<CrmOrderAction> actions, bool linesEditable) {
    final s = d.summary;
    final scope = CrmScope.instance;
    final canEditNote = (caps.isTenantAdmin || caps.canWriteOrder) && d.status != 'CANCELLED';
    return CrmCard(
      title: 'crm.orders.info'.tr(),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (s.late) CrmStatusPill(label: 'crm.orders.late'.tr(), tone: CrmTone.danger),
          CrmStatusPill(label: crmOrderStatusLabel(d.status), tone: crmOrderStatusTone(d.status)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrmInfoRow(
            label: 'crm.orders.f.customer'.tr(),
            child: CrmLinkText(
              '${s.customerCode} - ${s.customerName}',
              onTap: () => _openThen(() => CrmRoutes.openCustomer(context, s.customerId)),
            ),
          ),
          CrmInfoRow(
            label: 'crm.orders.f.source'.tr(),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(crmOrderSourceLabel(d.source), style: const TextStyle(fontSize: 13, color: CrmColors.text)),
                if (s.contractId != null)
                  CrmLinkText(
                    s.contractCode ?? '',
                    onTap: () => _openThen(() => CrmRoutes.openContract(context, s.contractId!)),
                  ),
                if (s.quoteId != null)
                  CrmLinkText(
                    s.quoteCode ?? '',
                    onTap: () => _openThen(() => CrmRoutes.openQuote(context, s.quoteId!)),
                  ),
              ],
            ),
          ),
          CrmInfoRow(label: 'crm.orders.f.order_date'.tr(), value: formatCrmDay(s.orderDate)),
          CrmInfoRow(
            label: 'crm.orders.f.expected'.tr(),
            value: (s.expectedDeliveryDate ?? '').isEmpty
                ? 'crm.orders.not_set'.tr()
                : formatCrmDay(s.expectedDeliveryDate),
          ),
          CrmInfoRow(label: 'crm.orders.f.warehouse'.tr(), value: d.warehouseCode ?? 'crm.contracts.not_chosen'.tr()),
          if (!linesEditable)
            CrmInfoRow(
              label: 'crm.orders.price_list'.tr(),
              value: (d.priceListName ?? '').isEmpty
                  ? 'crm.contracts.not_chosen'.tr()
                  : [crmPriceListDisplayName(d.priceListName, d.priceListStatus), ?d.priceListCode].join(' '),
            ),
          if (d.reservationExpiresAt != null)
            CrmInfoRow(label: 'crm.orders.f.reservation_until'.tr(), value: formatCrmDateTime(d.reservationExpiresAt)),
          if ((d.deliveryAddress ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.orders.f.address'.tr(), value: d.deliveryAddress),
          CrmInfoRow(label: 'crm.orders.f.owner'.tr(), value: scope.personName(s.ownerUserId)),
          if ((d.cancelReason ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.orders.f.cancel_reason'.tr(), value: d.cancelReason),
          if ((d.closeReason ?? '').isNotEmpty)
            CrmInfoRow(label: 'crm.orders.f.close_reason'.tr(), value: d.closeReason),
          if ((d.note ?? '').isNotEmpty) CrmInfoRow(label: 'crm.orders.f.note'.tr(), value: d.note),
          if (d.status == 'DELIVERED')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'crm.orders.delivered_hint'.tr(),
                style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
              ),
            ),
          const Divider(height: 20, color: CrmColors.divider),
          Text(
            'crm.orders.info_note.title'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CrmColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            d.infoNote ?? 'crm.orders.info_note.empty'.tr(),
            style: TextStyle(fontSize: 13, color: d.infoNote == null ? CrmColors.muted : CrmColors.text),
          ),
          if (d.infoNote != null && d.infoNotedAt != null)
            Text(
              '${d.infoNotedBy != null ? scope.personName(d.infoNotedBy) : 'crm.contracts.system'.tr()} · ${formatCrmDateTime(d.infoNotedAt)}',
              style: const TextStyle(fontSize: 11.5, color: CrmColors.faint),
            ),
          if (canEditNote)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _editInfoNote(d),
                child: Text(d.infoNote != null ? 'crm.orders.info_note.edit'.tr() : 'crm.orders.info_note.add'.tr()),
              ),
            ),
          CrmOrderReceivablePanel(
            detail: d,
            caps: caps,
            busy: _busy,
            onOpenReceivables: () => _openThen(() => CrmRoutes.openReceivables(context, d.customerId)),
            onApprove: () =>
                _run(() => _repo.decideCredit(d.id, 'approve'), success: 'crm.orders.credit.approved'.tr()),
            onReject: (reason) => _run(
              () => _repo.decideCredit(d.id, 'reject', reason: reason),
              success: 'crm.orders.credit.rejected'.tr(),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.contains(CrmOrderAction.edit))
                  CrmButton(
                    label: 'crm.orders.edit_header'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _editHeader(d),
                  ),
                if (actions.contains(CrmOrderAction.confirm))
                  CrmButton(label: 'crm.orders.confirm'.tr(), onPressed: _busy ? null : () => _confirm(d)),
                if (actions.contains(CrmOrderAction.plan))
                  CrmButton(
                    label: 'crm.orders.delivery.add'.tr(),
                    icon: Icons.add_rounded,
                    outlined: true,
                    onPressed: _busy || d.lines.isEmpty ? null : () => _plan(d),
                  ),
                if (actions.contains(CrmOrderAction.close))
                  CrmButton(
                    label: 'crm.orders.close'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _askReason(d, 'close'),
                  ),
                if (actions.contains(CrmOrderAction.cancel))
                  CrmButton(
                    label: 'crm.orders.cancel'.tr(),
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

  Widget _linesCard(CrmOrderDetail d, List<CrmOrderAction> actions, bool linesEditable) {
    final priceDate = d.priceDate ?? crmTodayVn();
    final priceOptions = crmPriceListOptions(
      _priceLists,
      priceDate,
      currentId: d.priceListId,
      currentCode: d.priceListCode,
      currentName: d.priceListName,
      currentStatus: d.priceListStatus,
    );
    final stockText = _stock
        .where((s) => s.kind != 'SERVICE')
        .map(
          (s) =>
              '${s.materialCode} (${s.byWarehouse.isEmpty ? 'crm.orders.lines.out_of_stock'.tr() : s.byWarehouse.map((e) => '${e.warehouseCode}: ${formatCrmQuantity(e.available)}').join(', ')})',
        )
        .join('; ');
    return CrmCard(
      title: 'crm.orders.lines.title'.tr(),
      trailing: linesEditable
          ? TextButton.icon(
              onPressed: _busy || d.priceListId == null ? null : () => _addLine(d),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('crm.orders.lines.add'.tr()),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (linesEditable)
            CrmField(
              label: 'crm.orders.price_list'.tr(),
              required: true,
              error: _priceListError,
              hint: _priceListsLoaded && priceOptions.isEmpty
                  ? 'crm.orders.price_list_none'.tr()
                  : d.priceListId != null
                  ? 'crm.orders.price_list_hint'.tr()
                  : 'crm.orders.price_list_pick_first'.tr(),
              child: CrmPriceListField(
                options: priceOptions,
                value: d.priceListId,
                enabled: !_busy,
                onChanged: (v) => _choosePriceList(d, v),
              ),
            ),
          if (d.lines.isEmpty)
            Text(
              linesEditable ? 'crm.orders.lines.empty_editable'.tr() : 'crm.orders.lines.empty'.tr(),
              style: const TextStyle(fontSize: 13, color: CrmColors.muted),
            )
          else
            for (final line in d.lines) _lineTile(d, line, actions.contains(CrmOrderAction.edit), linesEditable),
          const Divider(height: 20, color: CrmColors.divider),
          CrmInfoRow(label: 'crm.orders.totals.net'.tr(), value: formatCrmMoney(d.totals.netAmount)),
          if (d.totals.shippingAmount != 0)
            CrmInfoRow(label: 'crm.orders.totals.shipping'.tr(), value: formatCrmMoney(d.totals.shippingAmount)),
          CrmInfoRow(label: 'crm.orders.totals.vat'.tr(), value: formatCrmMoney(d.totals.vatAmount)),
          CrmInfoRow(
            label: 'crm.orders.totals.total'.tr(),
            child: Text(
              formatCrmMoney(d.totals.totalAmount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CrmColors.text),
            ),
          ),
          if (_stock.any((s) => s.byWarehouse.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'crm.orders.lines.stock_hint'.tr(args: {'list': stockText}),
                style: const TextStyle(fontSize: 12, color: CrmColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lineTile(CrmOrderDetail d, CrmOrderLine line, bool warehouseEditable, bool linesEditable) {
    final Widget warehouse;
    if (line.isService) {
      warehouse = Text(
        'crm.contracts.lines.no_reserve'.tr(),
        style: const TextStyle(fontSize: 13, color: CrmColors.muted),
      );
    } else if (warehouseEditable) {
      warehouse = CrmWarehouseSelect(
        value: line.warehouseCode,
        placeholder: d.warehouseCode != null
            ? 'crm.orders.by_order'.tr(args: {'code': d.warehouseCode})
            : 'crm.warehouse.placeholder'.tr(),
        stock: _stockOf(line.materialId),
        enabled: !_busy,
        onChanged: (code) => _changeLineWarehouse(d, line, code),
      );
    } else {
      warehouse = Text(
        line.warehouseCode ??
            (d.warehouseCode != null
                ? 'crm.orders.by_order_suffix'.tr(args: {'code': d.warehouseCode})
                : 'crm.contracts.not_chosen'.tr()),
        style: const TextStyle(fontSize: 13, color: CrmColors.text),
      );
    }
    final Widget reservation;
    if (line.isService) {
      reservation = Text(
        'crm.contracts.lines.no_reserve'.tr(),
        style: const TextStyle(fontSize: 13, color: CrmColors.muted),
      );
    } else if (line.reservationStatus != null) {
      reservation = Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(formatCrmQuantity(line.reservedQuantity), style: const TextStyle(fontSize: 13)),
          CrmStatusPill(
            dense: true,
            tone: line.reservationStatus == 'HELD'
                ? CrmTone.success
                : line.reservationStatus == 'EXPIRED'
                ? CrmTone.danger
                : CrmTone.neutral,
            label:
                '${crmReservationStatusLabel(line.reservationStatus)}${line.reservationSource == 'CONTRACT' ? ' ${'crm.orders.lines.from_contract'.tr()}' : ''}',
          ),
        ],
      );
    } else {
      reservation = Text(
        'crm.orders.lines.not_reserved'.tr(),
        style: const TextStyle(fontSize: 13, color: CrmColors.muted),
      );
    }
    final partial = line.deliveredQuantity > 0 && line.deliveredQuantity < line.quantity;
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
              if (linesEditable)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'crm.orders.remove'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: CrmColors.danger),
                  onPressed: _busy ? null : () => _removeLine(d, line),
                ),
            ],
          ),
          const SizedBox(height: 4),
          CrmInfoRow(
            label: 'crm.orders.lines.quantity'.tr(),
            value: '${formatCrmQuantity(line.quantity)} ${line.unit}',
          ),
          CrmInfoRow(label: 'crm.orders.lines.warehouse'.tr(), child: warehouse),
          CrmInfoRow(
            label: 'crm.orders.lines.price_source'.tr(),
            value: [crmPriceSourceLabel(line.priceSource), ?line.priceReferenceCode].join(' '),
          ),
          CrmInfoRow(label: 'crm.orders.lines.discount'.tr(), value: formatCrmPercent(line.discountPercent)),
          CrmInfoRow(label: 'crm.orders.lines.unit_price'.tr(), value: formatCrmMoney(line.unitPrice)),
          CrmInfoRow(label: 'crm.orders.lines.amount'.tr(), value: formatCrmMoney(line.lineAmount)),
          CrmInfoRow(
            label: 'crm.orders.lines.vat'.tr(),
            value: line.overrideVatRate != null
                ? '${formatCrmPercent(line.vatRate)} ${'crm.orders.lines.vat_manual'.tr()}'
                : formatCrmPercent(line.vatRate),
          ),
          CrmInfoRow(label: 'crm.orders.lines.reservation'.tr(), child: reservation),
          CrmInfoRow(label: 'crm.orders.lines.planned'.tr(), value: formatCrmQuantity(line.plannedQuantity)),
          CrmInfoRow(
            label: 'crm.orders.lines.delivered'.tr(),
            child: Text(
              formatCrmQuantity(line.deliveredQuantity),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: partial ? CrmColors.danger : CrmColors.text,
              ),
            ),
          ),
          if (line.deliveredQuantity != 0)
            CrmInfoRow(label: 'crm.orders.lines.actual_cost'.tr(), value: formatCrmMoney(line.actualCost)),
          if (line.serials.isNotEmpty)
            CrmInfoRow(label: 'crm.orders.lines.serials'.tr(), value: line.serials.join(', ')),
        ],
      ),
    );
  }

  Widget _deliveriesCard(CrmOrderDetail d, CrmCapabilities caps, List<CrmOrderAction> actions) {
    final canWriteOrder = caps.isTenantAdmin || caps.canWriteOrder;
    return CrmCard(
      title: 'crm.orders.delivery.title'.tr(),
      child: d.deliveries.isEmpty
          ? Text('crm.orders.delivery.empty'.tr(), style: const TextStyle(fontSize: 13, color: CrmColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final delivery in d.deliveries)
                  _deliveryTile(
                    d,
                    delivery,
                    canWrite: actions.contains(CrmOrderAction.plan) || crmCanRequestDelivery(d.status, delivery),
                    canRequest: crmCanRequestDelivery(d.status, delivery) && canWriteOrder,
                  ),
              ],
            ),
    );
  }

  Widget _deliveryTile(CrmOrderDetail d, CrmDeliveryPlan delivery, {required bool canWrite, required bool canRequest}) {
    final meta = [
      'crm.orders.delivery.date'.tr(args: {'d': formatCrmDay(delivery.plannedDate)}),
      'crm.orders.delivery.warehouse_short'.tr(
        args: {'code': delivery.warehouseCode ?? 'crm.orders.delivery.by_order'.tr()},
      ),
      if ((delivery.address ?? '').isNotEmpty) delivery.address!,
      if ((delivery.issueDocumentCode ?? '').isNotEmpty)
        'crm.orders.delivery.document'.tr(args: {'code': delivery.issueDocumentCode}),
    ].join(' · ');
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
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CrmCodeBadge(delivery.code),
              CrmStatusPill(
                dense: true,
                label: crmDeliveryStatusLabel(delivery.status),
                tone: crmDeliveryStatusTone(delivery.status),
              ),
              if (delivery.late) CrmStatusPill(dense: true, label: 'crm.orders.late'.tr(), tone: CrmTone.danger),
            ],
          ),
          const SizedBox(height: 6),
          Text(meta, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
          const SizedBox(height: 6),
          for (final line in delivery.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'crm.orders.delivery.line_no'.tr(args: {'no': line.lineNo})} ${line.materialCode} ${line.materialName}${line.materialKind == 'SERVICE' ? ' ${'crm.orders.delivery.service_note'.tr()}' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CrmColors.text),
                  ),
                  Text(
                    [
                      'crm.orders.delivery.planned'.tr(
                        args: {'qty': formatCrmQuantity(line.plannedQuantity), 'unit': line.unit},
                      ),
                      'crm.orders.delivery.delivered'.tr(args: {'qty': formatCrmQuantity(line.deliveredQuantity)}),
                      if (line.deliveredQuantity != 0)
                        'crm.orders.delivery.actual_cost'.tr(args: {'amount': formatCrmMoney(line.actualCost)}),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                  ),
                  if (line.serials.isNotEmpty)
                    Text(
                      'crm.orders.delivery.serials'.tr(args: {'list': line.serials.join(', ')}),
                      style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                    ),
                ],
              ),
            ),
          if ((delivery.status == 'PLANNED' && canWrite) || canRequest) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (delivery.status == 'PLANNED' && canWrite) ...[
                  CrmButton(
                    label: 'crm.orders.delivery.edit'.tr(),
                    outlined: true,
                    onPressed: _busy ? null : () => _plan(d, delivery),
                  ),
                  CrmButton(
                    label: 'crm.orders.delivery.cancel'.tr(),
                    outlined: true,
                    danger: true,
                    onPressed: _busy ? null : () => _cancelDelivery(d, delivery),
                  ),
                ],
                if (canRequest)
                  CrmButton(
                    label: 'crm.orders.delivery.request'.tr(),
                    icon: Icons.local_shipping_outlined,
                    onPressed: _busy ? null : () => _requestIssue(d, delivery),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
