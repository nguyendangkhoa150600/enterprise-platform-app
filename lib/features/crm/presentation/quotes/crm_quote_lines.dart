import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import 'crm_quote_form_parts.dart';
import 'crm_quote_logic.dart';

/// Dòng hàng ở màn báo giá (web `QuoteLinesTable`): bảng → thẻ. Nút + mở chọn mặt hàng; chạm thẻ để sửa (Nháp) hoặc
/// xem; nhấn giữ mở menu Thêm / Hiệu chỉnh / Chèn / Xoá (không còn Nháp: chỉ Xem). Xoá có hỏi lại.
class CrmQuoteLinesSection extends StatelessWidget {
  final String title;
  final List<CrmQuoteLine> lines;
  final bool editable;
  final bool busy;
  final String? lockedText;
  final String? addBlockedText;
  final String? emptyText;
  final bool costHidden;

  /// Nút "Sửa % chiết khấu": null khi không có.
  final ({bool enabled, String hint, VoidCallback onOpen})? discount;
  final ValueChanged<String> onAdd;
  final ValueChanged<CrmQuoteLine> onInsert;
  final ValueChanged<CrmQuoteLine> onEdit;
  final ValueChanged<CrmQuoteLine> onView;
  final Future<void> Function(CrmQuoteLine line) onRemove;
  final String? note;
  final Widget? footer;

  const CrmQuoteLinesSection({
    super.key,
    required this.title,
    required this.lines,
    required this.editable,
    this.busy = false,
    this.lockedText,
    this.addBlockedText,
    this.emptyText,
    this.costHidden = false,
    this.discount,
    required this.onAdd,
    required this.onInsert,
    required this.onEdit,
    required this.onView,
    required this.onRemove,
    this.note,
    this.footer,
  });

  bool get _canAdd => editable || lockedText != null;

  Future<void> _confirmRemove(BuildContext context, CrmQuoteLine line) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.quotes.lines.remove_title'.tr(args: {'no': line.lineNo}),
      message: '${line.materialCode} ${line.materialName}\n${'crm.quotes.lines.remove_message'.tr()}',
      confirmLabel: 'crm.quotes.remove'.tr(),
      danger: true,
    );
    if (ok) await onRemove(line);
  }

  Future<void> _menu(BuildContext context, CrmQuoteLine line) async {
    final blocked = addBlockedText != null;
    final items = editable ? [if (!blocked) 'add', 'edit', if (!blocked) 'insert', 'remove'] : ['view'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'crm.quotes.lines.line_n'.tr(args: {'no': line.lineNo}),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${line.materialCode} ${line.materialName}'),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(switch (item) {
                  'add' => Icons.add_rounded,
                  'edit' => Icons.edit_outlined,
                  'insert' => Icons.playlist_add_rounded,
                  'remove' => Icons.delete_outline_rounded,
                  _ => Icons.visibility_outlined,
                }, color: item == 'remove' ? CrmColors.danger : CrmColors.body),
                title: Text(
                  'crm.quotes.lines.menu.$item'.tr(),
                  style: TextStyle(color: item == 'remove' ? CrmColors.danger : CrmColors.text),
                ),
                onTap: () => Navigator.pop(ctx, item),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case 'add':
        onAdd('');
      case 'insert':
        onInsert(line);
      case 'edit':
        onEdit(line);
      case 'view':
        onView(line);
      case 'remove':
        await _confirmRemove(context, line);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = addBlockedText != null;
    return CrmCard(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discount != null && editable)
            TextButton(
              onPressed: busy || !discount!.enabled ? null : discount!.onOpen,
              child: Text('crm.quotes.lines.edit_discount'.tr()),
            ),
          if (_canAdd)
            IconButton.filled(
              tooltip: addBlockedText ?? 'crm.quotes.lines.add'.tr(),
              style: IconButton.styleFrom(backgroundColor: CrmColors.primary),
              onPressed: busy || blocked ? null : () => onAdd(''),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(note!, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
            ),
          if (addBlockedText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(addBlockedText!, style: const TextStyle(fontSize: 12.5, color: CrmColors.warning)),
            ),
          if (discount != null && editable && !discount!.enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(discount!.hint, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
            ),
          if (lockedText != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: CrmColors.bg, borderRadius: BorderRadius.circular(10)),
              child: Text(
                lockedText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CrmColors.muted),
              ),
            )
          else if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                emptyText ?? 'crm.quotes.lines.empty'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: CrmColors.muted),
              ),
            )
          else
            for (final line in lines)
              _LineCard(
                line: line,
                costHidden: costHidden,
                onTap: () => editable ? onEdit(line) : onView(line),
                onMenu: () => _menu(context, line),
              ),
          ?footer,
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final CrmQuoteLine line;
  final bool costHidden;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  const _LineCard({required this.line, required this.costHidden, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final l = line;
    final lowStock = !l.isService && l.availableStock != null && l.availableStock! < l.quantity;
    final stock = l.isService
        ? 'crm.quotes.lines.stock_unmanaged'.tr()
        : l.availableStock == null
        ? 'crm.quotes.lines.stock_unknown'.tr()
        : formatCrmQuantity(l.availableStock);
    const small = TextStyle(fontSize: 12, color: CrmColors.muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: CrmColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onMenu,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${l.lineNo}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CrmColors.muted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CrmCodeBadge(l.materialCode),
                            if (l.isService) CrmStatusPill(label: 'crm.catalog.kind_service'.tr(), dense: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.materialName,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: CrmColors.text),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert_rounded, color: CrmColors.muted),
                    onPressed: onMenu,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${'crm.quotes.lines.qty'.tr()}: ${formatCrmQuantity(l.quantity)} ${l.unit} · ${'crm.quotes.lines.stock'.tr()}: $stock',
                style: small.copyWith(color: lowStock ? CrmColors.danger : CrmColors.muted),
              ),
              Text(
                '${'crm.quotes.lines.list_price'.tr()}: ${formatCrmMoney(l.listPrice)} · '
                '${crmPriceSourceLabel(l.priceSource)}${l.priceReferenceCode == null ? '' : ' ${l.priceReferenceCode}'}',
                style: small,
              ),
              Text(
                '${'crm.quotes.lines.policies'.tr()}: ${l.appliedPolicies.isEmpty ? 'crm.quotes.none'.tr() : l.appliedPolicies.map((p) => '${p.code}: ${formatCrmPercent(p.percent)}').join(', ')}',
                style: small,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${'crm.quotes.lines.discount'.tr()}: ${formatCrmPercent(l.discountPercent)}', style: small),
                  if (l.cappedAt != null)
                    CrmStatusPill(label: 'crm.quotes.lines.capped'.tr(), tone: CrmTone.warning, dense: true),
                  if (l.overridden)
                    CrmStatusPill(label: 'crm.quotes.lines.overridden'.tr(), tone: CrmTone.warning, dense: true),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('VAT: ${formatCrmMoney(l.vatAmount)} (${formatCrmPercent(l.vatRate)})', style: small),
                  if (l.overrideVatRate != null)
                    CrmStatusPill(label: 'crm.quotes.lines.vat_manual'.tr(), tone: CrmTone.info, dense: true),
                ],
              ),
              if (!costHidden)
                Text(
                  '${'crm.quotes.lines.est_cost'.tr()}: ${l.estUnitCost == null && !l.isService ? 'crm.quotes.lines.no_cost'.tr() : formatCrmMoney(l.estCost)}'
                  '${l.margin == null ? '' : ' · ${'crm.quotes.lines.margin'.tr()}: ${formatCrmPercent(l.margin)}'}',
                  style: small,
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${'crm.quotes.lines.unit_price'.tr()}: ${formatCrmMoney(l.unitPrice)}',
                      style: const TextStyle(fontSize: 12.5, color: CrmColors.body),
                    ),
                  ),
                  Text(
                    formatCrmMoney(l.lineAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: CrmColors.text),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sửa (hoặc xem) một dòng (web `LineDialog`): số lượng, ĐVT, ghi đè đơn giá hoặc chiết khấu (ghi đè cần duyệt), thuế
/// suất sửa tay. [onSave] trả true khi lưu xong (đóng sheet).
Future<void> showCrmQuoteLineSheet(
  BuildContext context, {
  required CrmQuoteLine line,
  bool readOnly = false,
  bool lockDiscountOverride = false,
  bool lockVatOverride = false,
  Future<bool> Function(Map<String, dynamic> patch)? onSave,
}) => showCrmSheet<void>(
  context,
  builder: (_) => _LineSheet(
    line: line,
    readOnly: readOnly,
    lockDiscount: lockDiscountOverride,
    lockVat: lockVatOverride,
    onSave: onSave,
  ),
);

class _LineSheet extends StatefulWidget {
  final CrmQuoteLine line;
  final bool readOnly;
  final bool lockDiscount;
  final bool lockVat;
  final Future<bool> Function(Map<String, dynamic> patch)? onSave;
  const _LineSheet({
    required this.line,
    required this.readOnly,
    required this.lockDiscount,
    required this.lockVat,
    this.onSave,
  });

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late String _quantity = crmNumText(widget.line.quantity);
  late String _unit = widget.line.unit;
  late String _price = widget.line.overrideUnitPrice == null ? '' : crmNumText(widget.line.overrideUnitPrice!);
  late String _discount = widget.line.overrideDiscountPercent == null
      ? ''
      : crmNumText(widget.line.overrideDiscountPercent!);
  late String _vat = widget.line.overrideVatRate == null
      ? ''
      : crmNumText(widget.line.overrideVatRate!).replaceAll('.', ',');
  String? _vatError;
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    if (widget.readOnly) return Navigator.pop(context);
    final amount = parseCrmNumber(_quantity);
    if (amount == null || amount <= 0) return setState(() => _error = 'crm.quotes.lines.error_quantity'.tr());
    if (!widget.lockDiscount && _price.trim().isNotEmpty && _discount.trim().isNotEmpty) {
      return setState(() => _error = 'crm.quotes.lines.error_both'.tr());
    }
    final parsedVat = !widget.lockVat && _vat.trim().isNotEmpty ? parseCrmVatRate(_vat) : null;
    if (parsedVat != null && !parsedVat.ok) return setState(() => _vatError = parsedVat.error);
    setState(() {
      _vatError = null;
      _error = null;
      _saving = true;
    });
    final done = await widget.onSave!({
      'quantity': amount,
      'unit': _unit.trim(),
      // Web gửi `NaN` khi số sai; JSON.stringify đổi thành null. Dart jsonEncode ném lỗi với NaN nên gửi thẳng null.
      'overrideUnitPrice': _price.trim().isEmpty ? null : parseCrmNumber(_price),
      'overrideDiscountPercent': !widget.lockDiscount && _discount.trim().isNotEmpty ? parseCrmNumber(_discount) : null,
      'overrideVatRate': widget.lockVat ? widget.line.overrideVatRate : parsedVat?.value,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final ro = widget.readOnly;
    final overriding = !ro && (_price.trim().isNotEmpty || (!widget.lockDiscount && _discount.trim().isNotEmpty));
    return CrmFormSheet(
      title: 'crm.quotes.lines.sheet_title'.tr(args: {'no': l.lineNo, 'code': l.materialCode}),
      subtitle: ro ? '${l.materialName} ${'crm.quotes.lines.view_only'.tr()}' : l.materialName,
      submitLabel: ro ? 'crm.common.close'.tr() : null,
      hideCancel: ro,
      submitting: _saving,
      error: _error,
      notice: overriding
          ? CrmBanner(message: 'crm.quotes.lines.override_notice'.tr(), kind: CrmBannerKind.warning)
          : null,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.quotes.lines.qty_label'.tr(),
          required: true,
          child: CrmQuoteInput(value: _quantity, number: true, enabled: !ro, onChanged: (t) => _quantity = t),
        ),
        CrmField(
          label: 'crm.quotes.lines.unit'.tr(),
          required: true,
          child: CrmQuoteInput(value: _unit, maxLength: 50, enabled: !ro, onChanged: (t) => _unit = t),
        ),
        CrmField(
          label: 'crm.quotes.lines.override_price'.tr(),
          hint: 'crm.quotes.lines.list_price_hint'.tr(args: {'price': formatCrmMoney(l.listPrice)}),
          child: CrmQuoteInput(value: _price, number: true, enabled: !ro, onChanged: (t) => setState(() => _price = t)),
        ),
        CrmField(
          label: 'crm.quotes.lines.override_discount'.tr(),
          hint: widget.lockDiscount
              ? 'crm.quotes.lines.discount_by_order'.tr()
              : 'crm.quotes.lines.policy_hint'.tr(args: {'percent': formatCrmPercent(l.policyPercent)}),
          child: CrmQuoteInput(
            value: widget.lockDiscount ? '' : _discount,
            number: true,
            enabled: !widget.lockDiscount && !ro,
            onChanged: (t) => setState(() => _discount = t),
          ),
        ),
        CrmField(
          label: 'crm.quotes.lines.vat_rate'.tr(),
          error: _vatError,
          hint: widget.lockVat
              ? 'crm.quotes.tax_by_order'.tr()
              : 'crm.quotes.lines.vat_hint'.tr(args: {'rate': formatCrmPercent(l.vatRate)}),
          child: CrmQuoteInput(
            value: widget.lockVat ? '' : _vat,
            number: true,
            hint: widget.lockVat ? null : 'crm.quotes.picker.vat_by_list'.tr(),
            enabled: !widget.lockVat && !ro,
            onChanged: (t) => _vat = t,
          ),
        ),
      ],
    );
  }
}
