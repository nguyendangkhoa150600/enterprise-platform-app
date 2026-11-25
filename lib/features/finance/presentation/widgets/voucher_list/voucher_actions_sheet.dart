import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_scope.dart';
import '../common/finance_ui.dart';

/// Thao tác nhanh trên một phiếu (web `voucher-context-menu.ts`).
enum VoucherMenuAction { edit, approve, cancel, delete, duplicate }

/// Hành động người dùng chọn, kèm cách duyệt của phiếu (để chọn đường duyệt và lời xác nhận).
typedef VoucherMenuPick = ({VoucherMenuAction action, FinanceApprovalMode approvalMode});

/// Sheet "⋯" của một dòng phiếu. Như web: tải phiếu đầy đủ rồi dựng menu từ `permissions` máy chủ đã tính.
/// [canCreate]: lập được loại phiếu này → luôn có "Nhân bản" (web: không phụ thuộc trạng thái hay chủ phiếu).
Future<VoucherMenuPick?> showVoucherActionsSheet(BuildContext context, FinanceVoucherSummary row, {bool canCreate = false}) {
  return showModalBottomSheet<VoucherMenuPick>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _VoucherActionsSheet(row: row, canCreate: canCreate),
  );
}

class _VoucherActionsSheet extends StatefulWidget {
  final FinanceVoucherSummary row;
  final bool canCreate;
  const _VoucherActionsSheet({required this.row, required this.canCreate});

  @override
  State<_VoucherActionsSheet> createState() => _VoucherActionsSheetState();
}

class _VoucherActionsSheetState extends State<_VoucherActionsSheet> {
  FinanceVoucher? _voucher;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await FinanceScope.instance.repository.getVoucher(widget.row.id);
      if (!mounted) return;
      setState(() => _voucher = v);
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = financeErrorMessage(e, 'finance.voucher_list.menu_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _voucher;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                '${'finance.voucher_list.menu_title'.tr()} · ${widget.row.code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: FinanceColors.text),
              ),
            ),
            if (_error != null)
              FinanceStateView(error: _error)
            else if (v == null)
              const FinanceStateView(loading: true)
            else
              ..._entries(v),
          ],
        ),
      ),
    );
  }

  List<Widget> _entries(FinanceVoucher v) {
    final can = v.permissions;
    final items = <Widget>[
      if (can.canEdit) _item(VoucherMenuAction.edit, Icons.edit_outlined, 'finance.voucher_list.action_edit', v),
      if (can.canApprove)
        _item(VoucherMenuAction.approve, Icons.check_circle_outline_rounded, 'finance.voucher_list.action_approve', v),
      if (can.canCancel)
        _item(VoucherMenuAction.cancel, Icons.block_rounded, 'finance.voucher_list.action_cancel', v, danger: true),
      if (can.canDelete)
        _item(VoucherMenuAction.delete, Icons.delete_outline_rounded, 'finance.voucher_list.action_delete', v,
            danger: true),
      if (widget.canCreate)
        _item(VoucherMenuAction.duplicate, Icons.content_copy_rounded, 'finance.voucher_list.action_duplicate', v),
    ];
    if (items.isEmpty) {
      return [FinanceStateView(emptyText: 'finance.voucher_list.menu_empty'.tr(), emptyIcon: Icons.more_horiz_rounded)];
    }
    return items;
  }

  Widget _item(VoucherMenuAction action, IconData icon, String labelKey, FinanceVoucher v, {bool danger = false}) {
    final color = danger ? const Color(0xFFDC2626) : FinanceColors.text;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(labelKey.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      onTap: () => Navigator.pop<VoucherMenuPick>(context, (action: action, approvalMode: v.approvalMode)),
    );
  }
}
