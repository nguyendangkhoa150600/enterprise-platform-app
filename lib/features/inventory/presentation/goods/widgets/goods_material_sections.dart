import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../theme/colors.dart';
import '../../../../../utils/user_resolver.dart';
import '../../../data/goods/goods_models.dart';
import '../../../data/goods/goods_repository.dart';
import '../goods_format.dart';
import 'goods_ui.dart';

/// Tồn của một mặt hàng theo từng kho, kèm tổng (web `MaterialStockSection`). Dịch vụ không quản lý tồn.
class GoodsStockSection extends StatelessWidget {
  final GoodsMaterial material;
  final List<GoodsStockRow> stock;
  final String Function(String warehouseId) warehouseName;

  const GoodsStockSection({super.key, required this.material, required this.stock, required this.warehouseName});

  @override
  Widget build(BuildContext context) {
    if (material.isService) return GoodsMessage(text: 'inventory.goods.stock_service'.tr());
    final rows = stock.where((r) => r.materialId == material.id || r.materialCode == material.code).toList();
    if (rows.isEmpty) return GoodsMessage(text: 'inventory.goods.stock_empty'.tr());
    final total = rows.fold<double>(0, (s, r) => s + r.quantity);
    final available = rows.fold<double>(0, (s, r) => s + r.available);

    Widget line(String wh, String qty, String reserved, String avail, {bool bold = false}) {
      final style = TextStyle(fontSize: 12.5, color: AppColors.slate800, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(flex: 4, child: Text(wh, style: style)),
          Expanded(flex: 3, child: Text(qty, style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(reserved, style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(avail, style: style, textAlign: TextAlign.right)),
        ]),
      );
    }

    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate500);
    return Column(children: [
      Row(children: [
        Expanded(flex: 4, child: Text('inventory.goods.col_warehouse'.tr(), style: head)),
        Expanded(flex: 3, child: Text('inventory.goods.on_hand'.tr(), style: head, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('inventory.goods.reserved'.tr(), style: head, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: Text('inventory.goods.available'.tr(), style: head, textAlign: TextAlign.right)),
      ]),
      const Divider(height: 12, color: AppColors.slate100),
      ...rows.map((r) => line(
            warehouseName(r.warehouseId),
            '${GoodsFormat.number(r.quantity)} ${material.unit}',
            GoodsFormat.number(r.quantityReserved),
            GoodsFormat.number(r.available),
          )),
      const Divider(height: 12, color: AppColors.slate100),
      line('inventory.goods.total'.tr(), '${GoodsFormat.number(total)} ${material.unit}', '',
          GoodsFormat.number(available),
          bold: true),
    ]);
  }
}

/// Lịch sử nhập, xuất, điều chuyển của một mã (100 dòng gần nhất; web `MaterialHistorySection`).
/// Dịch vụ không có tồn nên không gọi API.
class GoodsHistorySection extends StatefulWidget {
  final GoodsMaterial material;
  final String Function(String warehouseId) warehouseName;

  /// Chỉ hiện phát sinh của kho này; null là mọi kho.
  final String? warehouseId;

  const GoodsHistorySection({super.key, required this.material, required this.warehouseName, this.warehouseId});

  @override
  State<GoodsHistorySection> createState() => _GoodsHistorySectionState();
}

class _GoodsHistorySectionState extends State<GoodsHistorySection> {
  List<GoodsLedgerRow>? _rows;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    UserResolver.ensureLoaded();
  }

  Future<void> _load() async {
    if (widget.material.isService) return;
    setState(() {
      _rows = null;
      _error = false;
    });
    try {
      final rows = await GoodsRepository.instance.loadHistory(widget.material.code, limit: 100);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.material.isService) return GoodsMessage(text: 'inventory.goods.history_service'.tr());
    if (_error) return GoodsMessage(text: 'inventory.goods.history_error'.tr(), isError: true, onRetry: _load);
    if (_rows == null) return GoodsMessage(text: 'inventory.goods.history_loading'.tr());
    final rows = widget.warehouseId == null ? _rows! : _rows!.where((r) => r.warehouseId == widget.warehouseId).toList();
    if (rows.isEmpty) return GoodsMessage(text: 'inventory.goods.history_empty'.tr());
    return ValueListenableBuilder<int>(
      valueListenable: UserResolver.changeNotifier,
      builder: (context, _, _) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 14, color: AppColors.slate100),
            _row(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(GoodsLedgerRow r) {
    final positive = r.quantity > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(GoodsFormat.transactionTypeLabel(r.type),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800)),
          ),
          Text(
            '${positive ? '+' : ''}${GoodsFormat.number(r.quantity)} ${widget.material.unit}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: positive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          '${GoodsFormat.dateTime(r.createdAt)} · ${widget.warehouseName(r.warehouseId)}',
          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 2),
        Text(
          'inventory.goods.history_ref'.tr(args: {
            'code': r.transactionCode,
            'user': UserResolver.resolveName(r.createdBy),
          }),
          style: const TextStyle(fontSize: 12, color: AppColors.slate600),
        ),
        if (r.documentNumber != null)
          Text('inventory.goods.history_invoice'.tr(args: {'n': r.documentNumber}),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      ],
    );
  }
}
