import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../features/inventory/data/reports/inventory_reports_repository.dart';
import '../../features/inventory/domain/reports/inventory_report_models.dart';
import '../../features/inventory/presentation/reports/approval_report_view.dart';
import '../../features/inventory/presentation/reports/movement_report_view.dart';
import '../../features/inventory/presentation/reports/stock_report_view.dart';
import '../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../theme/colors.dart';

enum _ReportView { warehouse, lot, serial, movements, approvals }

/// Báo cáo kho (web `InventoryReports`, T7-09): tồn theo kho, lô, serial với bốn loại tồn;
/// nhập xuất theo kỳ; lịch sử chứng từ phải duyệt. Mỗi bảng xuất được toàn bộ tập đã lọc (CSV).
class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({super.key});

  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

class _InventoryReportsScreenState extends State<InventoryReportsScreen> {
  final _repo = InventoryReportsRepository.instance;
  _ReportView _view = _ReportView.warehouse;
  List<ReportWarehouse> _warehouses = const [];
  List<String> _categories = const [];

  @override
  void initState() {
    super.initState();
    InventoryScope.instance.ensureCapabilities();
    _loadLookups();
  }

  /// Kho và phân loại cho bộ lọc; lỗi thì bộ lọc chỉ còn "Mọi kho"/"Mọi phân loại", báo cáo vẫn xem được.
  Future<void> _loadLookups() async {
    try {
      final warehouses = await _repo.loadWarehouses();
      if (!mounted) return;
      setState(() => _warehouses = warehouses);
    } catch (e) {
      InventoryScope.instance.onError(e);
    }
    try {
      final categories = await _repo.loadTradeCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {}
  }

  String _label(_ReportView v) => switch (v) {
    _ReportView.warehouse => 'inventory.reports.view.warehouse'.tr(),
    _ReportView.lot => 'inventory.reports.view.lot'.tr(),
    _ReportView.serial => 'inventory.reports.view.serial'.tr(),
    _ReportView.movements => 'inventory.reports.view.movements'.tr(),
    _ReportView.approvals => 'inventory.reports.view.approvals'.tr(),
  };

  Widget _body() => switch (_view) {
    _ReportView.movements => MovementReportView(warehouses: _warehouses),
    _ReportView.approvals => ApprovalReportView(warehouses: _warehouses),
    _ReportView.warehouse => _stock(StockReportGroupBy.warehouse),
    _ReportView.lot => _stock(StockReportGroupBy.lot),
    _ReportView.serial => _stock(StockReportGroupBy.serial),
  };

  Widget _stock(StockReportGroupBy g) =>
      StockReportView(key: ValueKey(g), groupBy: g, warehouses: _warehouses, categories: _categories);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('inventory.reports.title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'inventory.reports.subtitle'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              children: _ReportView.values.map((v) {
                final active = v == _view;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_label(v)),
                    selected: active,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _view = v),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.slate600,
                    ),
                    selectedColor: const Color(0xFF021E73),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: active ? const Color(0xFF021E73) : AppColors.slate200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
