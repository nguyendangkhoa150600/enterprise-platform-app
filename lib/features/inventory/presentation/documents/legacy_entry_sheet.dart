import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/documents/stock_document_logic.dart';
import '../../domain/documents/stock_document_models.dart';
import 'document_widgets.dart';

/// Bút toán từ trước khi có chứng từ (web `LegacyEntryDrawer`): chỉ xem, không có thao tác.
Future<void> showLegacyEntrySheet(BuildContext context, StockMovementRow entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DocSheetFrame(
      heightFactor: 0.75,
      title: Text('inventory.documents.legacy.title'.tr(args: {'code': entry.code}),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DocBanner('inventory.documents.legacy.notice'.tr()),
          const SizedBox(height: 14),
          DocInfoGrid([
            DocInfoCell('inventory.documents.field.type'.tr(), movementTypeLabel(entry)),
            DocInfoCell('inventory.documents.field.warehouse'.tr(), entry.warehouseCode),
            DocInfoCell('inventory.documents.legacy.occurred_at'.tr(), formatDateTimeText(entry.occurredAt)),
            DocInfoCell('inventory.documents.field.source_origin'.tr(), sourceTypeLabel(entry.sourceType)),
            DocInfoCell('inventory.documents.field.material'.tr(), entry.materialCode ?? '—', small: entry.materialName),
            DocInfoCell('inventory.documents.field.quantity'.tr(), formatQty(entry.quantityTotal)),
            DocInfoCell(
              'inventory.documents.legacy.recorded_by'.tr(),
              '',
              smallWidget: UserNameText(entry.createdBy,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900)),
            ),
          ]),
          if ((entry.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('inventory.documents.field.note_value'.tr(args: {'note': entry.note!}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ],
        ],
      ),
    ),
  );
}
