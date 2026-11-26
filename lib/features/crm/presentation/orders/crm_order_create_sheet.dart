import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/contracts/contracts_repository.dart';
import '../../data/orders/orders_repository.dart';
import '../../domain/contracts/crm_contract_models.dart';
import '../../domain/orders/crm_order_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_warehouse_select.dart';
import '../contracts/crm_fulfillment_ui.dart';
import '../utils/crm_scope.dart';

/// Web `priceListOptions`: bảng đang bật, còn hiệu lực tại [date]; mã ở mô tả. Bảng đang gắn mà không còn chọn được
/// vẫn có mặt để ô hiện đúng tên.
List<CrmSelectOption> crmPriceListOptions(
  List<CrmPriceListOption> lists,
  String date, {
  String? currentId,
  String? currentCode,
  String? currentName,
  String? currentStatus,
}) {
  final options = lists
      .where((l) => l.effectiveOn(date))
      .map((l) => CrmSelectOption(value: l.id, label: l.name, description: l.code))
      .toList();
  if (currentId != null && currentId.isNotEmpty && !options.any((o) => o.value == currentId)) {
    CrmPriceListOption? known;
    for (final l in lists) {
      if (l.id == currentId) known = l;
    }
    final name = currentName ?? known?.name ?? currentId;
    final status = currentStatus ?? known?.status;
    final display = crmPriceListDisplayName(name, status);
    options.add(
      CrmSelectOption(
        value: currentId,
        label: display.isEmpty ? name : display,
        description: currentCode ?? known?.code ?? '',
      ),
    );
  }
  return options;
}

/// Ô chọn "Bảng giá" (web `PriceListSelect`): bắt buộc, mặc định trống.
class CrmPriceListField extends StatelessWidget {
  final List<CrmSelectOption> options;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const CrmPriceListField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => CrmSelectField(
    value: value,
    options: options,
    enabled: enabled,
    placeholder: options.isEmpty ? 'crm.orders.price_list_none'.tr() : 'crm.orders.price_list_placeholder'.tr(),
    emptyText: options.isEmpty ? 'crm.orders.price_list_none'.tr() : 'crm.orders.price_list_empty'.tr(),
    onChanged: (s) {
      if (s.value != null) onChanged(s.value!);
    },
  );
}

/// Lập đơn trực tiếp cho khách, hoặc từ hợp đồng đang hiệu lực (web `CreateOrderDialog`). Bảng giá bắt buộc. Trả đơn
/// đã lập, null khi đóng.
Future<CrmOrderDetail?> showCrmCreateOrder(BuildContext context) =>
    showCrmSheet<CrmOrderDetail>(context, builder: (_) => const _CreateOrderSheet());

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet();

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  List<CrmContractSummary> _contracts = const [];
  List<CrmPriceListOption> _priceLists = const [];
  bool _priceListsLoaded = false;
  String? _contractId;
  String? _customerId;
  String? _customerLabel;
  String? _priceListId;
  String? _priceListError;
  String? _warehouseCode;
  String _expected = '';
  final TextEditingController _address = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final String _priceDate = crmTodayVn();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContracts();
    _loadPriceLists();
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadContracts() async {
    try {
      final page = await ContractsRepository.instance.listContracts(
        const CrmContractListQuery(status: 'ACTIVE', limit: 100),
      );
      if (!mounted) return;
      setState(() => _contracts = page.items);
    } catch (_) {
      // Web bỏ qua lỗi: ô chọn hợp đồng trống.
    }
  }

  Future<void> _loadPriceLists() async {
    try {
      final rows = await OrdersRepository.instance.listPriceLists();
      if (!mounted) return;
      setState(() => _priceLists = rows);
    } catch (_) {
      // Lỗi: danh sách bảng giá rỗng (web `usePriceLists`).
    } finally {
      if (mounted) setState(() => _priceListsLoaded = true);
    }
  }

  Future<void> _save() async {
    if ((_contractId ?? '').isEmpty && (_customerId ?? '').isEmpty) {
      return setState(() => _error = 'crm.orders.create.customer_required'.tr());
    }
    if ((_priceListId ?? '').isEmpty) {
      return setState(() => _priceListError = 'crm.orders.price_list_required'.tr());
    }
    final address = _address.text.trim();
    final note = _note.text.trim();
    setState(() {
      _priceListError = null;
      _saving = true;
      _error = null;
    });
    try {
      final hasContract = (_contractId ?? '').isNotEmpty;
      final created = await OrdersRepository.instance.createOrder({
        'contractId': hasContract ? _contractId : null,
        'customerId': hasContract ? null : _customerId,
        'priceListId': _priceListId,
        'warehouseCode': (_warehouseCode ?? '').trim().isEmpty ? null : _warehouseCode!.trim(),
        'expectedDeliveryDate': _expected.isEmpty ? null : _expected,
        'deliveryAddress': address.isEmpty ? null : address,
        'note': note.isEmpty ? null : note,
      });
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.orders.create.failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContract = (_contractId ?? '').isNotEmpty;
    final priceOptions = crmPriceListOptions(_priceLists, _priceDate);
    return CrmFormSheet(
      title: 'crm.orders.create.title'.tr(),
      subtitle: 'crm.orders.create.subtitle'.tr(),
      submitLabel: 'crm.orders.create.submit'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.orders.create.contract'.tr(),
          hint: 'crm.orders.create.contract_hint'.tr(),
          child: CrmSelectField(
            value: _contractId,
            clearable: true,
            placeholder: 'crm.orders.create.contract_placeholder'.tr(),
            options: [
              for (final c in _contracts)
                CrmSelectOption(value: c.id, label: c.title, badge: c.code, description: c.customerName),
            ],
            onChanged: (s) => setState(() => _contractId = s.value),
          ),
        ),
        CrmField(
          label: 'crm.orders.create.customer'.tr(),
          child: CrmCustomerSelectField(
            value: hasContract ? null : _customerId,
            selectedLabel: _customerLabel,
            clearable: true,
            enabled: !hasContract,
            onChanged: (c) => setState(() {
              _customerId = c?.id;
              _customerLabel = c?.name;
            }),
          ),
        ),
        CrmField(
          label: 'crm.orders.price_list'.tr(),
          required: true,
          error: _priceListError,
          hint: _priceListsLoaded && priceOptions.isEmpty
              ? 'crm.orders.price_list_none'.tr()
              : 'crm.orders.create.price_list_hint'.tr(),
          child: CrmPriceListField(
            options: priceOptions,
            value: _priceListId,
            onChanged: (v) => setState(() {
              _priceListId = v;
              _priceListError = null;
            }),
          ),
        ),
        CrmField(
          label: 'crm.orders.f.warehouse'.tr(),
          hint: 'crm.orders.create.warehouse_hint'.tr(),
          child: CrmWarehouseSelect(
            value: _warehouseCode,
            placeholder: 'crm.orders.warehouse_placeholder'.tr(),
            onChanged: (code) => setState(() => _warehouseCode = code),
          ),
        ),
        CrmField(
          label: 'crm.orders.f.expected'.tr(),
          hint: 'crm.orders.expected_hint'.tr(),
          child: CrmDateField(value: _expected, onChanged: (v) => setState(() => _expected = v)),
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
