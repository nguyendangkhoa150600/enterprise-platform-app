import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/inventory/data/documents/stock_document_api.dart';
import '../../../features/inventory/domain/documents/stock_document_logic.dart';
import '../../../features/inventory/domain/documents/stock_document_models.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/presentation/documents/document_widgets.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';

/// Chạy một thao tác trạng thái trên server; trả chứng từ mới và câu thông báo (web `runDocumentAction`).
Future<({StockDoc document, String message})> runDocumentAction(DocAction action, StockDoc doc) async {
  final api = StockDocumentApi.instance;
  final code = {'code': doc.code};
  switch (action) {
    case DocAction.submit:
      return (document: await api.submit(doc.id), message: 'inventory.documents.msg.submitted'.tr(args: code));
    case DocAction.approve:
      return (document: await api.approve(doc.id), message: 'inventory.documents.msg.approved'.tr(args: code));
    case DocAction.post:
      return (document: await api.post(doc.id), message: 'inventory.documents.msg.posted'.tr(args: code));
    case DocAction.cancel:
      return (document: await api.cancel(doc.id), message: 'inventory.documents.msg.cancelled'.tr(args: code));
    case DocAction.reverse:
      final reversed = await api.reverse(doc.id);
      return (
        document: reversed,
        message: 'inventory.documents.msg.reversed'.tr(args: {'code': doc.code, 'newCode': reversed.code}),
      );
    case DocAction.edit:
    case DocAction.reject:
      throw StateError('unsupported');
  }
}

/// Nút thao tác của một chứng từ theo trạng thái và quyền (web `DocumentActionBar`); lỗi server hiện nguyên văn.
class DocumentActionBar extends StatefulWidget {
  final StockDoc document;
  final List<DocAction> exclude;
  final VoidCallback? onEdit;
  final void Function(StockDoc document, String message) onChanged;
  final WrapAlignment alignment;

  const DocumentActionBar({
    super.key,
    required this.document,
    required this.onChanged,
    this.exclude = const [],
    this.onEdit,
    this.alignment = WrapAlignment.end,
  });

  @override
  State<DocumentActionBar> createState() => _DocumentActionBarState();
}

class _DocumentActionBarState extends State<DocumentActionBar> {
  bool _busy = false;

  ({String title, String description})? _confirm(DocAction a) => switch (a) {
        DocAction.post => (
            title: 'inventory.documents.confirm.post_title'.tr(),
            description: 'inventory.documents.confirm.post_desc'.tr()
          ),
        DocAction.cancel => (
            title: 'inventory.documents.confirm.cancel_title'.tr(),
            description: 'inventory.documents.confirm.cancel_desc'.tr()
          ),
        DocAction.reverse => (
            title: 'inventory.documents.confirm.reverse_title'.tr(),
            description: 'inventory.documents.confirm.reverse_desc'.tr()
          ),
        _ => null,
      };

  Future<void> _run(DocAction action) async {
    final confirm = _confirm(action);
    if (confirm != null) {
      final ok = await confirmDocAction(
        context,
        title: confirm.title,
        description: confirm.description,
        okLabel: docActionLabel(action),
        danger: action != DocAction.post,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final result = await runDocumentAction(action, widget.document);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged(result.document, result.message);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      showDocSnack(context, inventoryErrorMessage(e, 'inventory.documents.error.action_failed'), error: true);
    }
  }

  Future<void> _reject() async {
    final reason = await askRejectReason(context, widget.document.code);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final rejected = await StockDocumentApi.instance.reject(widget.document.id, reason);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged(rejected, 'inventory.documents.msg.rejected'.tr(args: {'code': widget.document.code}));
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      showDocSnack(context, inventoryErrorMessage(e, 'inventory.documents.error.reject_failed'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InventoryCapabilities>(
      valueListenable: InventoryScope.instance.capabilities,
      builder: (context, caps, _) {
        final actions = availableDocumentActions(widget.document,
                canWrite: caps.canWriteTransactions, canApprove: caps.canApproveDocuments)
            .where((a) => !widget.exclude.contains(a) && (a != DocAction.edit || widget.onEdit != null))
            .toList();
        if (actions.isEmpty) return const SizedBox.shrink();
        return Wrap(
          alignment: widget.alignment,
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final a in actions)
              ElevatedButton(
                style: docButtonStyle(
                  primary: a == DocAction.post || a == DocAction.approve || a == DocAction.submit,
                  danger: a == DocAction.reject || a == DocAction.cancel,
                ),
                onPressed: _busy
                    ? null
                    : () {
                        if (a == DocAction.edit) {
                          widget.onEdit?.call();
                        } else if (a == DocAction.reject) {
                          _reject();
                        } else {
                          _run(a);
                        }
                      },
                child: Text(docActionLabel(a), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }
}

/// Chi tiết chứng từ (web `StockDocumentDetail`): phần đầu, dòng (lô, hạn dùng, serial, giá vốn sau ghi sổ),
/// lịch sử và nút theo trạng thái. [show] trả chứng từ cần sửa khi người dùng bấm "Sửa" (chỉ khi [allowEdit]).
class InventoryDocumentDetailSheet extends StatefulWidget {
  final StockDoc document;
  final bool allowEdit;

  /// Thao tác xong thì đóng (màn Chờ duyệt); không thì cập nhật tại chỗ (danh sách gộp).
  final bool closeOnChange;
  final void Function(StockDoc document, String message)? onChanged;

  const InventoryDocumentDetailSheet({
    super.key,
    required this.document,
    this.allowEdit = false,
    this.closeOnChange = false,
    this.onChanged,
  });

  static Future<StockDoc?> show(
    BuildContext context,
    StockDoc document, {
    bool allowEdit = false,
    bool closeOnChange = false,
    void Function(StockDoc document, String message)? onChanged,
  }) {
    return showModalBottomSheet<StockDoc>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryDocumentDetailSheet(
        document: document,
        allowEdit: allowEdit,
        closeOnChange: closeOnChange,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<InventoryDocumentDetailSheet> createState() => _InventoryDocumentDetailSheetState();
}

class _InventoryDocumentDetailSheetState extends State<InventoryDocumentDetailSheet> {
  late StockDoc _doc = widget.document;

  void _changed(StockDoc doc, String message) {
    showDocSnack(context, message);
    widget.onChanged?.call(doc, message);
    if (widget.closeOnChange) {
      Navigator.of(context).pop();
    } else {
      setState(() => _doc = doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final posted = doc.status == 'POSTED';
    final hasTarget = (doc.targetWarehouseCode ?? '').isNotEmpty;
    return DocSheetFrame(
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text('inventory.documents.detail.title'.tr(args: {'code': doc.code}),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          DocStatusBadge(doc.status),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DocInfoGrid([
            DocInfoCell('inventory.documents.field.type'.tr(), docTypeLabel(doc.docType)),
            DocInfoCell(
              hasTarget ? 'inventory.documents.field.warehouse_pair'.tr() : 'inventory.documents.field.warehouse'.tr(),
              warehousePairLabel(doc.warehouseCode, doc.targetWarehouseCode),
            ),
            DocInfoCell('inventory.documents.field.document_date'.tr(), Formatters.formatDate(doc.documentDate)),
            DocInfoCell('inventory.documents.field.source'.tr(), sourceTypeLabel(doc.sourceType), small: doc.sourceId),
            if ((doc.reversesDocumentId ?? '').isNotEmpty)
              DocInfoCell(
                'inventory.documents.field.reverses'.tr(),
                doc.reversesDocumentId!.length > 8 ? doc.reversesDocumentId!.substring(0, 8) : doc.reversesDocumentId!,
              ),
            if (posted) DocInfoCell('inventory.documents.field.total_cost'.tr(), formatQty(doc.totalCost)),
          ]),
          if ((doc.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('inventory.documents.field.note_value'.tr(args: {'note': doc.note!}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          ],
          if ((doc.rejectReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            DocBanner('inventory.documents.detail.reject_reason'.tr(args: {'reason': doc.rejectReason!})),
          ],
          const SizedBox(height: 14),
          for (final line in doc.lines) ...[_lineCard(line, posted), const SizedBox(height: 8)],
          const SizedBox(height: 8),
          Text('inventory.documents.detail.history'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          const SizedBox(height: 8),
          DocInfoGrid([
            ...[
              _audit('inventory.documents.history.created'.tr(), doc.createdBy, doc.createdAt),
              _audit('inventory.documents.history.submitted'.tr(), doc.submittedBy, doc.submittedAt),
              _audit('inventory.documents.history.approved'.tr(), doc.approvedBy, doc.approvedAt),
              _audit('inventory.documents.history.rejected'.tr(), doc.rejectedBy, doc.rejectedAt),
              _audit('inventory.documents.history.posted'.tr(), doc.postedBy, doc.postedAt),
              _audit('inventory.documents.history.cancelled'.tr(), doc.cancelledBy, doc.cancelledAt),
            ].whereType<Widget>(),
          ]),
          const SizedBox(height: 16),
        ],
      ),
      footer: DocumentActionBar(
        key: ValueKey('${doc.id}:${doc.status}'),
        document: doc,
        onEdit: widget.allowEdit ? () => Navigator.of(context).pop(doc) : null,
        onChanged: _changed,
      ),
    );
  }

  Widget? _audit(String label, String? who, String? when) {
    if ((who ?? '').isEmpty && (when ?? '').isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: kDocBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
        Text(formatDateTimeText(when), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        if ((who ?? '').isNotEmpty)
          UserNameText(who,
              prefix: 'inventory.documents.history.actor'.tr(),
              style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
      ]),
    );
  }

  Widget _lineCard(StockDocLine line, bool posted) {
    final inbound = line.direction == 'IN';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: kDocBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${line.lineNo}  ', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.materialCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              if (line.materialName.isNotEmpty)
                Text(line.materialName, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ]),
          ),
          Text(
            inbound ? 'inventory.documents.direction.in'.tr() : 'inventory.documents.direction.out'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: inbound ? const Color(0xFF15803D) : const Color(0xFFB45309),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        DocInfoGrid([
          DocInfoCell('inventory.documents.field.quantity'.tr(), '${formatQty(line.quantity)} ${line.unit ?? ''}'.trim()),
          DocInfoCell('inventory.documents.field.unit_cost'.tr(), line.unitCost != 0 ? formatQty(line.unitCost) : '—'),
          DocInfoCell(
            'inventory.documents.field.cost_amount'.tr(),
            posted && line.costAmount != null ? formatQty(line.costAmount) : 'inventory.documents.detail.after_post'.tr(),
          ),
          DocInfoCell(
            'inventory.documents.field.lot_expiry'.tr(),
            (line.lotNo ?? '').isNotEmpty ? line.lotNo! : '—',
            small: (line.lotNo ?? '').isNotEmpty && (line.lotExpiresOn ?? '').isNotEmpty
                ? 'inventory.documents.field.expiry_short'.tr(args: {'date': Formatters.formatDate(line.lotExpiresOn)})
                : null,
          ),
        ]),
        if (line.serials.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('inventory.documents.field.serial'.tr(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
          Text(line.serials.join(', '), style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
        ],
      ]),
    );
  }
}
