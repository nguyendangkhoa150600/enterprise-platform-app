import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../domain/models/finance_models.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_labels.dart';
import '../common/finance_ui.dart';
import 'voucher_form_data.dart';
import 'voucher_form_fields.dart';

const _smallLabel = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FinanceColors.muted);

Widget _miniLabel(String text, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text),
        if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
      ])),
    );

/// Khối chi tiết (kind.detail_title): thuế + dòng chi tiết + tổng (web `voucher-form-screen.tsx`).
class VoucherLinesSection extends StatelessWidget {
  final FinanceVoucherKind kind;
  final VoucherFormData form;

  /// Dòng chi tiết và số tiền lấy từ hồ sơ (khoá).
  final bool locked;
  final VoidCallback onChanged;

  const VoucherLinesSection({
    super.key,
    required this.kind,
    required this.form,
    required this.locked,
    required this.onChanged,
  });

  void _set(void Function() apply) {
    apply();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final total = form.linesTotal();
    final includedTax = form.taxIncluded ? financeIncludedTax(total, form.taxRate) : 0.0;
    return VoucherFormSection(
      title: kind.label('detail_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: () => _set(() => form.taxIncluded = !form.taxIncluded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: form.taxIncluded,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => _set(() => form.taxIncluded = v ?? false),
                    ),
                    Text('finance.voucher_form.tax_included'.tr(),
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                  ],
                ),
              ),
              if (form.taxIncluded)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('finance.voucher_form.tax_rate'.tr(), style: const TextStyle(fontSize: 12.5, color: FinanceColors.muted)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 72,
                      child: Semantics(
                        label: 'finance.voucher_form.tax_rate_aria'.tr(),
                        child: VoucherDecimalInput(
                          value: form.taxRate,
                          max: 100,
                          onChanged: (v) => _set(() => form.taxRate = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('%', style: TextStyle(fontSize: 13, color: FinanceColors.muted)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < form.lines.length; i++)
            _LineCard(
              key: ValueKey(form.lines[i].key),
              index: i,
              line: form.lines[i],
              kind: kind,
              locked: locked,
              canRemove: form.lines.length > 1 && !locked,
              onChanged: onChanged,
              onRemove: () => _set(() => form.lines.removeAt(i)),
            ),
          const SizedBox(height: 4),
          if (locked)
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: FinanceColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('finance.voucher_form.lines_locked'.tr(),
                      style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _set(() => form.lines.add(VoucherLineState())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('finance.voucher_form.add_line'.tr()),
              ),
            ),
          const Divider(height: 20, color: FinanceColors.border),
          Row(
            children: [
              Text('finance.voucher_form.total'.tr(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: FinanceColors.text)),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(formatFinanceMoney(total),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
              ),
            ],
          ),
          if (form.taxIncluded)
            Align(
              alignment: Alignment.centerRight,
              child: Text('finance.voucher_form.included_tax'.tr(args: {'amount': formatFinanceMoney(includedTax)}),
                  style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
            ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final int index;
  final VoucherLineState line;
  final FinanceVoucherKind kind;
  final bool locked;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _LineCard({
    super.key,
    required this.index,
    required this.line,
    required this.kind,
    required this.locked,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceColors.border),
      ),
      child: DefaultTextStyle.merge(
        style: _smallLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('finance.voucher_form.line_no'.tr(args: {'n': index + 1}),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
                IconButton(
                  tooltip: 'finance.voucher_form.remove_line'.tr(args: {'n': index + 1}),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: const Color(0xFFDC2626),
                  onPressed: canRemove ? onRemove : null,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _miniLabel('finance.voucher_form.line_description'.tr(), required: true),
                  VoucherTextInput(
                    initialValue: line.description,
                    enabled: !locked,
                    placeholder: kind.label('line_placeholder'),
                    maxLength: 500,
                    maxLines: 3,
                    keyboardType: TextInputType.text,
                    onChanged: (v) => line.description = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _miniLabel('finance.voucher_form.line_quantity'.tr(), required: true),
                            VoucherDecimalInput(
                              value: line.quantity,
                              enabled: !locked,
                              onChanged: (v) {
                                line.quantity = v;
                                onChanged();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _miniLabel('finance.voucher_form.amount'.tr(), required: true),
                            VoucherMoneyInput(
                              value: line.unitAmount,
                              enabled: !locked,
                              onChanged: (v) {
                                line.unitAmount = v;
                                onChanged();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('finance.voucher_form.line_total'.tr()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: Text(formatFinanceMoney(line.total),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khối "Hóa đơn" (chỉ phiếu thu/chi); mở sẵn khi phiếu đã có hoá đơn.
class VoucherInvoicesSection extends StatelessWidget {
  final VoucherFormData form;
  final VoidCallback onChanged;
  const VoucherInvoicesSection({super.key, required this.form, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return VoucherFormSection(
      title: 'finance.voucher_form.section_invoices'.tr(),
      initiallyOpen: form.invoices.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < form.invoices.length; i++)
            _InvoiceCard(
              key: ValueKey(form.invoices[i].key),
              index: i,
              invoice: form.invoices[i],
              onChanged: onChanged,
              onRemove: () {
                form.invoices.removeAt(i);
                onChanged();
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                form.invoices.add(VoucherInvoiceState());
                onChanged();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('finance.voucher_form.add_invoice'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final int index;
  final VoucherInvoiceState invoice;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _InvoiceCard({
    super.key,
    required this.index,
    required this.invoice,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VoucherTextInput(
                  initialValue: invoice.invoiceNo,
                  placeholder: 'finance.voucher_form.invoice_no'.tr(),
                  onChanged: (v) => invoice.invoiceNo = v,
                ),
                const SizedBox(height: 8),
                VoucherDateInput(
                  value: invoice.invoiceDate,
                  clearable: true,
                  placeholder: 'finance.voucher_form.invoice_date'.tr(),
                  onChanged: (v) {
                    invoice.invoiceDate = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 8),
                VoucherTextInput(
                  initialValue: invoice.taxCode,
                  placeholder: 'finance.voucher_form.tax_code'.tr(),
                  onChanged: (v) => invoice.taxCode = v,
                ),
                const SizedBox(height: 8),
                VoucherMoneyInput(value: invoice.amount, onChanged: (v) => invoice.amount = v),
              ],
            ),
          ),
          IconButton(
            tooltip: 'finance.voucher_form.remove_invoice'.tr(args: {'n': index + 1}),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: const Color(0xFFDC2626),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
