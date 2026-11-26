import 'package:flutter/material.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../utils/app_toast.dart';
import '../utils/inventory_scope.dart';
import 'stock_import_service.dart';
import 'stock_import_sheet.dart';

/// Nút "Nhập Excel" của tab Nhà kho (web warehouse-stock-tab.tsx `onOpenBulkImport` +
/// inventory-screen.tsx `handleBulkImportData`): nạp tồn đa kho, tạo mã mới, báo kết quả rồi nạp lại.
class StockImportWarehouseFlow {
  StockImportWarehouseFlow._();

  static Future<void> run(
    BuildContext context, {
    required String firstWarehouseCode,
    required Future<void> Function() onImported,
  }) async {
    final lines = await StockImportSheet.show(context, defaultWarehouseCode: firstWarehouseCode);
    if (lines == null || !context.mounted) return;
    if (!InventoryScope.instance.capabilities.value.canWriteTransactions) {
      AppToast.error(context, 'inventory.stock_import.no_write_permission'.tr());
      return;
    }
    if (lines.isEmpty) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text('inventory.stock_import.importing'.tr())),
          ]),
        ),
      ),
    );
    try {
      final result = await StockImportService.instance.applyBulkImport(
        lines,
        fallbackWarehouseCode: firstWarehouseCode,
        // Ghi chú lưu vào sổ cái (dữ liệu, không phải nhãn): giữ nguyên văn như web để sổ
        // không đổi ngôn ngữ theo máy người nhập.
        defaultNote: 'Bổ sung dữ liệu đa kho từ tệp Excel',
      );
      navigator.pop();
      if (!context.mounted) return;
      final parts = <String>[];
      if (result.transactionCodes.isNotEmpty) {
        parts.add('inventory.ledger.outcome_posted'.tr(args: {
          'text': 'inventory.stock_import.bulk_done'.tr(args: {'n': result.transactionCodes.length}),
          'codes': result.transactionCodes.join(', '),
        }));
      }
      if (result.pendingCodes.isNotEmpty) {
        parts.add('inventory.ledger.outcome_pending'
            .tr(args: {'n': result.pendingCodes.length, 'codes': result.pendingCodes.join(', ')}));
      }
      AppToast.success(context, '${parts.join('. ')}.');
      await onImported();
    } catch (e) {
      navigator.pop();
      InventoryScope.instance.onError(e);
      if (!context.mounted) return;
      AppToast.error(context, inventoryErrorMessage(e, 'inventory.stock_import.bulk_error'));
    }
  }
}
