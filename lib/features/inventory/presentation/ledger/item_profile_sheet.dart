import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../data/inventory_api_client.dart';
import '../../domain/ledger/ledger_models.dart';
import '../utils/inventory_scope.dart';
import 'ledger_format.dart';

/// "Hồ sơ {mã}" mở từ "Soi kho" / "Kiểm tra tồn kho" (web item-profile-dialog.tsx, `GET /items/:code`).
/// Bản mobile hiện thông tin chính của hồ sơ và tồn theo từng kho (chỉ đọc).
class LedgerItemProfileSheet extends StatefulWidget {
  final String code;
  final LedgerWorkspace workspace;
  const LedgerItemProfileSheet({super.key, required this.code, required this.workspace});

  static Future<void> show(BuildContext context, {required String code, required LedgerWorkspace workspace}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LedgerItemProfileSheet(code: code, workspace: workspace),
      );

  @override
  State<LedgerItemProfileSheet> createState() => _LedgerItemProfileSheetState();
}

class _LedgerItemProfileSheetState extends State<LedgerItemProfileSheet> {
  Map<String, dynamic>? _item;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await InventoryApiClient.instance.get('/items/${Uri.encodeComponent(widget.code)}');
      if (!mounted) return;
      setState(() => _item = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e, 'inventory.ledger.profile_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.workspace;
    final material = ws.materialByCode(widget.code);
    final stocks = ws.stock.where((s) => s.materialCode == widget.code).toList();
    final item = _item;
    String? v(String key) {
      final x = item?[key];
      return x == null || x.toString().isEmpty ? null : x.toString();
    }

    final fields = <(String, String?)>[
      ('inventory.ledger.profile_name', v('name') ?? material?.name),
      ('inventory.ledger.profile_unit', v('unit') ?? material?.unit),
      ('inventory.ledger.profile_type', v('type') ?? material?.type),
      ('inventory.ledger.profile_status', v('status')),
      ('inventory.ledger.profile_manufacturer', v('manufacturer')),
      ('inventory.ledger.profile_model', v('model')),
      ('inventory.ledger.profile_serial', v('serialNumber')),
      ('inventory.ledger.profile_location', v('location')),
    ].where((f) => f.$2 != null).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(children: [
            Expanded(
              child: Text('inventory.ledger.profile_title'.tr(args: {'code': widget.code}),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(children: [
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13))),
                  TextButton(onPressed: _load, child: Text('inventory.ledger.retry'.tr())),
                ]),
              )
            else if (item == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('inventory.ledger.profile_loading'.tr(),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500)),
              )
            else
              ...fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.$1.tr().toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                      const SizedBox(height: 2),
                      Text(f.$2!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
                    ]),
                  )),
            const SizedBox(height: 6),
            Text('inventory.ledger.profile_stock'.tr(),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
            const SizedBox(height: 8),
            if (stocks.isEmpty)
              Text('inventory.ledger.profile_no_stock'.tr(), style: const TextStyle(fontSize: 13, color: AppColors.slate500))
            else
              ...stocks.map((s) {
                final wh = ws.warehouseByCode(s.warehouseCode);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.slate200)),
                  child: Row(children: [
                    Expanded(
                      child: Text('${wh?.name ?? s.warehouseCode} (${s.warehouseCode})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      'inventory.ledger.profile_stock_row'.tr(args: {
                        'avail': LedgerFormat.number(s.available),
                        'qty': LedgerFormat.number(s.quantity),
                      }),
                      style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                    ),
                  ]),
                );
              }),
          ]),
        ),
      ]),
    );
  }
}
