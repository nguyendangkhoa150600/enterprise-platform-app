import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../utils/crm_scope.dart';
import 'crm_format.dart';
import 'crm_select.dart';

/// Tuỳ chọn kho (web `warehouseOptions`): kho đang hoạt động; kho đang chọn luôn có mặt (kể cả đã ngừng — badge
/// "mã · ngừng"; không có trong danh sách thì thêm đầu danh sách bằng chính mã).
List<CrmSelectOption> crmWarehouseOptions(List<CrmWarehouseOption> warehouses, String? current) {
  final options = warehouses
      .where((w) => w.isActive || w.code == current)
      .map(
        (w) => CrmSelectOption(
          value: w.code,
          label: w.name,
          badge: w.isActive ? w.code : 'crm.warehouse.inactive_badge'.tr(args: {'code': w.code}),
        ),
      )
      .toList();
  if (current != null && current.isNotEmpty && !options.any((o) => o.value == current)) {
    options.insert(0, CrmSelectOption(value: current, label: current, badge: current));
  }
  return options;
}

/// Ô chọn kho của phân hệ Kho (web `WarehouseSelect`): danh sách kho tải một lần trong phiên. Có [stock] (tồn khả
/// dụng theo kho của mặt hàng) thì mỗi kho ghi "Khả dụng n". [onChanged] nhận mã kho, null khi bỏ chọn.
class CrmWarehouseSelect extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? placeholder;
  final List<CrmCatalogMaterialStock>? stock;
  final bool enabled;

  const CrmWarehouseSelect({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.stock,
    this.enabled = true,
  });

  @override
  State<CrmWarehouseSelect> createState() => _CrmWarehouseSelectState();
}

class _CrmWarehouseSelectState extends State<CrmWarehouseSelect> {
  List<CrmWarehouseOption> _warehouses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await CrmScope.instance.repository.loadWarehouseOptions();
      if (!mounted) return;
      setState(() => _warehouses = rows);
    } catch (_) {
      // Lỗi tải kho: ô chọn trống (web bỏ qua lỗi).
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final available = {for (final s in stock ?? const <CrmCatalogMaterialStock>[]) s.warehouseCode: s.available};
    final options = crmWarehouseOptions(_warehouses, widget.value)
        .map(
          (o) => stock == null
              ? o
              : CrmSelectOption(
                  value: o.value,
                  label: o.label,
                  badge: o.badge,
                  description: 'crm.warehouse.available'.tr(args: {'qty': formatCrmQuantity(available[o.value] ?? 0)}),
                ),
        )
        .toList();
    return CrmSelectField(
      value: widget.value,
      options: options,
      placeholder: widget.placeholder ?? 'crm.warehouse.placeholder'.tr(),
      searchHint: 'crm.warehouse.search'.tr(),
      emptyText: 'crm.warehouse.empty'.tr(),
      clearable: true,
      enabled: widget.enabled,
      onChanged: (selection) => widget.onChanged(selection.value),
    );
  }
}
