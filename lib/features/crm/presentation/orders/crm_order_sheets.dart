import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../../domain/orders/crm_order_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_warehouse_select.dart';
import '../contracts/crm_fulfillment_ui.dart';
import '../utils/crm_scope.dart';

/// Biểu mẫu của chi tiết đơn bán (web `DeliveryDialog`, `OrderHeaderDialog`, `OrderInfoNote`). Mỗi sheet nhận [onSave]
/// gọi API; lỗi thì sheet giữ nguyên và hiện lời nhắn; xong thì đóng và trả true.

Future<bool> _open(BuildContext context, WidgetBuilder builder) async =>
    (await showCrmSheet<bool>(context, builder: builder)) == true;

/// Chạy [work] trong sheet: bật trạng thái lưu, lỗi → lời nhắn, xong → đóng.
Future<void> _submit(State state, void Function(bool saving, String? error) set, Future<void> Function() work) async {
  set(true, null);
  try {
    await work();
    if (!state.mounted) return;
    Navigator.of(state.context).pop(true);
  } catch (e) {
    CrmScope.instance.onError(e);
    if (!state.mounted) return;
    set(false, crmErrorMessage(e, 'crm.orders.action_failed'));
  }
}

// ---------------------------------------------------------------------------
// Đợt giao
// ---------------------------------------------------------------------------

/// Lập hoặc sửa một đợt giao: ngày, kho xuất, địa chỉ, số lượng từng dòng (web `DeliveryDialog`). [onSave] nhận thân
/// `SaveDeliveryPlanRequest` (chưa có `revision`).
Future<bool> showCrmDeliverySheet(
  BuildContext context, {
  required CrmOrderDetail order,
  CrmDeliveryPlan? delivery,
  required Future<void> Function(Map<String, dynamic> body) onSave,
}) => _open(context, (_) => _DeliverySheet(order: order, delivery: delivery, onSave: onSave));

class _DeliverySheet extends StatefulWidget {
  final CrmOrderDetail order;
  final CrmDeliveryPlan? delivery;
  final Future<void> Function(Map<String, dynamic> body) onSave;
  const _DeliverySheet({required this.order, this.delivery, required this.onSave});

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  late final Map<String, double> _remaining = crmRemainingToPlan(widget.order, widget.delivery);
  late String _plannedDate = widget.delivery?.plannedDate ?? widget.order.summary.expectedDeliveryDate ?? '';
  late String? _warehouseCode = widget.delivery?.warehouseCode ?? widget.order.warehouseCode;
  late final TextEditingController _address = TextEditingController(
    text: widget.delivery?.address ?? widget.order.deliveryAddress ?? '',
  );
  late final TextEditingController _note = TextEditingController(text: widget.delivery?.note ?? '');
  final Map<String, TextEditingController> _quantities = {};
  List<CrmWarehouseOption> _warehouses = const [];
  String? _warehouseError;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final line in widget.order.lines) {
      double? own;
      for (final entry in widget.delivery?.lines ?? const <CrmDeliveryLine>[]) {
        if (entry.orderLineId == line.id) own = entry.plannedQuantity;
      }
      final text = own != null
          ? _plain(own)
          : widget.delivery != null
          ? ''
          : _plain(_remaining[line.id] ?? 0);
      _quantities[line.id] = TextEditingController(text: text);
    }
    _loadWarehouses();
  }

  static String _plain(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _loadWarehouses() async {
    try {
      // Web: `loadWarehouses(initial ? [initial] : [])` — lấy thêm kho đang chọn để kho đã ngừng vẫn có tên.
      final initial = widget.delivery?.warehouseCode ?? widget.order.warehouseCode;
      final rows = await CrmScope.instance.repository.loadWarehouseOptions(
        codes: initial == null || initial.isEmpty ? null : [initial],
      );
      if (!mounted) return;
      setState(() => _warehouses = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _warehouseError = crmErrorMessage(e, 'crm.orders.delivery.warehouse_error'));
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    for (final c in _quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_plannedDate.isEmpty) return setState(() => _error = 'crm.orders.delivery.date_required'.tr());
    final lines = <Map<String, dynamic>>[];
    for (final line in widget.order.lines) {
      final q = parseCrmNumber(_quantities[line.id]?.text ?? '') ?? 0;
      if (q > 0) lines.add({'orderLineId': line.id, 'quantity': q});
    }
    if (lines.isEmpty) return setState(() => _error = 'crm.orders.delivery.lines_required'.tr());
    final address = _address.text.trim();
    final note = _note.text.trim();
    await _submit(
      this,
      (saving, error) => setState(() {
        _saving = saving;
        _error = error;
      }),
      () => widget.onSave({
        'plannedDate': _plannedDate,
        'warehouseCode': (_warehouseCode ?? '').trim().isEmpty ? null : _warehouseCode!.trim(),
        'address': address.isEmpty ? null : address,
        'note': note.isEmpty ? null : note,
        'lines': lines,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final delivery = widget.delivery;
    return CrmFormSheet(
      title: delivery == null
          ? 'crm.orders.delivery.add_title'.tr()
          : 'crm.orders.delivery.edit_title'.tr(args: {'code': delivery.code}),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.orders.f.expected'.tr(),
          required: true,
          child: CrmDateField(value: _plannedDate, onChanged: (v) => setState(() => _plannedDate = v)),
        ),
        CrmField(
          label: 'crm.orders.delivery.warehouse'.tr(),
          hint: _warehouseError ?? 'crm.orders.delivery.warehouse_hint'.tr(),
          child: CrmSelectField(
            value: _warehouseCode,
            options: crmWarehouseOptions(_warehouses, _warehouseCode),
            clearable: true,
            placeholder: order.warehouseCode != null
                ? 'crm.orders.by_order'.tr(args: {'code': order.warehouseCode})
                : 'crm.orders.delivery.warehouse_placeholder'.tr(),
            searchHint: 'crm.warehouse.search'.tr(),
            emptyText: 'crm.warehouse.empty'.tr(),
            onChanged: (s) => setState(() => _warehouseCode = s.value),
          ),
        ),
        CrmField(
          label: 'crm.orders.f.address'.tr(),
          child: TextField(controller: _address, maxLength: 500, decoration: crmInputDecoration()),
        ),
        for (final line in order.lines)
          CrmField(
            label: 'crm.orders.delivery.line_label'.tr(args: {'no': line.lineNo, 'code': line.materialCode}),
            hint: 'crm.orders.delivery.line_hint'.tr(
              args: {
                'qty': formatCrmQuantity(line.quantity),
                'unit': line.unit,
                'remaining': formatCrmQuantity(_remaining[line.id] ?? 0),
              },
            ),
            child: TextField(
              controller: _quantities[line.id],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: crmInputDecoration(),
            ),
          ),
        CrmField(
          label: 'crm.orders.f.note'.tr(),
          child: TextField(
            controller: _note,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thông tin giao hàng của đơn Nháp
// ---------------------------------------------------------------------------

/// Sửa thông tin giao (web `OrderHeaderDialog`). [warehouses] là các kho đang có hàng (gợi ý).
Future<bool> showCrmOrderHeaderSheet(
  BuildContext context, {
  required CrmOrderDetail order,
  required List<String> warehouses,
  required Future<void> Function(Map<String, dynamic> patch) onSave,
}) => _open(context, (_) => _HeaderSheet(order: order, warehouses: warehouses, onSave: onSave));

class _HeaderSheet extends StatefulWidget {
  final CrmOrderDetail order;
  final List<String> warehouses;
  final Future<void> Function(Map<String, dynamic> patch) onSave;
  const _HeaderSheet({required this.order, required this.warehouses, required this.onSave});

  @override
  State<_HeaderSheet> createState() => _HeaderSheetState();
}

class _HeaderSheetState extends State<_HeaderSheet> {
  late String _expected = widget.order.summary.expectedDeliveryDate ?? '';
  late String? _warehouseCode = widget.order.warehouseCode;
  late final TextEditingController _address = TextEditingController(text: widget.order.deliveryAddress ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.order.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final address = _address.text.trim();
    final note = _note.text.trim();
    await _submit(
      this,
      (saving, error) => setState(() {
        _saving = saving;
        _error = error;
      }),
      () => widget.onSave({
        'expectedDeliveryDate': _expected.isEmpty ? null : _expected,
        'warehouseCode': (_warehouseCode ?? '').trim().isEmpty ? null : _warehouseCode!.trim(),
        'deliveryAddress': address.isEmpty ? null : address,
        'note': note.isEmpty ? null : note,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.warehouses;
    return CrmFormSheet(
      title: 'crm.orders.header.title'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.orders.f.expected'.tr(),
          hint: 'crm.orders.expected_hint'.tr(),
          child: CrmDateField(value: _expected, onChanged: (v) => setState(() => _expected = v)),
        ),
        CrmField(
          label: 'crm.orders.f.warehouse'.tr(),
          hint: [
            'crm.orders.header.warehouse_hint'.tr(),
            if (warehouses.isNotEmpty)
              'crm.orders.header.warehouses_with_stock'.tr(args: {'list': warehouses.join(', ')}),
          ].join(' '),
          child: CrmWarehouseSelect(
            value: _warehouseCode,
            placeholder: 'crm.orders.warehouse_placeholder'.tr(),
            onChanged: (code) => setState(() => _warehouseCode = code),
          ),
        ),
        CrmField(
          label: 'crm.orders.f.address'.tr(),
          child: TextField(controller: _address, maxLength: 500, decoration: crmInputDecoration()),
        ),
        CrmField(
          label: 'crm.orders.f.note'.tr(),
          child: TextField(
            controller: _note,
            maxLength: 4000,
            minLines: 3,
            maxLines: 6,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ghi chú thông tin đơn hàng (P2F-03)
// ---------------------------------------------------------------------------

/// Sửa "Ghi chú thông tin đơn hàng" (web `OrderInfoNote`): rỗng là xoá; tối đa [kCrmOrderInfoNoteMax] ký tự.
Future<bool> showCrmOrderInfoNoteSheet(
  BuildContext context, {
  required String? initial,
  required Future<void> Function(String? note) onSave,
}) => _open(context, (_) => _InfoNoteSheet(initial: initial, onSave: onSave));

class _InfoNoteSheet extends StatefulWidget {
  final String? initial;
  final Future<void> Function(String? note) onSave;
  const _InfoNoteSheet({required this.initial, required this.onSave});

  @override
  State<_InfoNoteSheet> createState() => _InfoNoteSheetState();
}

class _InfoNoteSheetState extends State<_InfoNoteSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initial ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _text.text.trim();
    if (value.length > kCrmOrderInfoNoteMax) {
      return setState(() => _error = 'crm.orders.info_note.too_long'.tr(args: {'max': kCrmOrderInfoNoteMax}));
    }
    await _submit(
      this,
      (saving, error) => setState(() {
        _saving = saving;
        _error = error;
      }),
      () => widget.onSave(value.isEmpty ? null : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.orders.info_note.title'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.orders.info_note.label'.tr(),
          hint: 'crm.orders.info_note.hint'.tr(args: {'max': kCrmOrderInfoNoteMax}),
          child: TextField(
            controller: _text,
            maxLength: kCrmOrderInfoNoteMax,
            minLines: 6,
            maxLines: 10,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}
