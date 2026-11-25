import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/presentation/documents/document_widgets.dart';
import '../../../theme/colors.dart';
import '../inventory_documents_screen.dart';
import '../inventory_issue_requests_screen.dart';

/// Tab "Xuất/nhập kho" của trang Kho hàng (web `StockMovementHub`): ba góc nhìn Tất cả (danh sách gộp),
/// Chờ duyệt (kèm số lượng do server trả cùng danh sách gộp), Yêu cầu xuất từ đơn bán.
class InventoryStockMovementTab extends StatefulWidget {
  const InventoryStockMovementTab({super.key});

  @override
  State<InventoryStockMovementTab> createState() => _InventoryStockMovementTabState();
}

enum _MovementView { all, pending, requests }

class _InventoryStockMovementTabState extends State<InventoryStockMovementTab> {
  _MovementView _view = _MovementView.all;
  int? _pendingCount;

  String _label(_MovementView v) => switch (v) {
        _MovementView.all => 'inventory.documents.view_all'.tr(),
        _MovementView.pending => (_pendingCount ?? 0) > 0
            ? 'inventory.documents.view_pending_count'.tr(args: {'n': formatQty(_pendingCount)})
            : 'inventory.documents.view_pending'.tr(),
        _MovementView.requests => 'inventory.documents.view_requests'.tr(),
      };

  void _onPendingCount(int n) {
    if (!mounted || n == _pendingCount) return;
    setState(() => _pendingCount = n);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in _MovementView.values) ...[_chip(v), const SizedBox(width: 6)],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: kDocBorder),
        Expanded(
          child: switch (_view) {
            _MovementView.all => InventoryDocumentsScreen(
                key: const ValueKey('all'),
                embedded: true,
                onPendingCount: _onPendingCount,
              ),
            _MovementView.pending =>
              const InventoryDocumentsScreen(key: ValueKey('pending'), initialStatus: 'PENDING', embedded: true),
            _MovementView.requests => const InventoryIssueRequestsScreen(embedded: true),
          },
        ),
      ],
    );
  }

  Widget _chip(_MovementView v) {
    final selected = v == _view;
    return Material(
      color: selected ? kDocBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _view = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            _label(v),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}
