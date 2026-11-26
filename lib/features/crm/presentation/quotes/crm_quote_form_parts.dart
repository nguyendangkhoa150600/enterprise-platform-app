import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_logic.dart';

/// Mẫu, loại, trường tuỳ biến (web `useQuoteFormLookups`): tải lỗi thì để rỗng, báo giá vẫn lập, sửa được.
class CrmQuoteLookups {
  final List<CrmQuoteTemplate> templates;
  final List<CrmQuoteType> types;
  final List<CrmCustomFieldDefinition> fields;
  final bool loaded;
  const CrmQuoteLookups({
    this.templates = const [],
    this.types = const [],
    this.fields = const [],
    this.loaded = false,
  });

  static Future<CrmQuoteLookups> load() async {
    final repo = CrmQuotesRepository.instance;
    final results = await Future.wait<Object>([
      repo.listTemplates().catchError((Object _) => <CrmQuoteTemplate>[]),
      repo.listTypes().catchError((Object _) => <CrmQuoteType>[]),
      repo.listCustomFields().catchError((Object _) => <CrmCustomFieldDefinition>[]),
    ]);
    return CrmQuoteLookups(
      templates: results[0] as List<CrmQuoteTemplate>,
      types: results[1] as List<CrmQuoteType>,
      fields: results[2] as List<CrmCustomFieldDefinition>,
      loaded: true,
    );
  }

  CrmQuoteTemplate? template(String? id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Ô nhập chữ giữ bộ điều khiển riêng, đồng bộ lại khi giá trị bên ngoài đổi (huỷ thay đổi, tải lại).
class CrmQuoteInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool number;
  final TextAlign textAlign;

  const CrmQuoteInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.number = false,
    this.textAlign = TextAlign.start,
  });

  @override
  State<CrmQuoteInput> createState() => _CrmQuoteInputState();
}

class _CrmQuoteInputState extends State<CrmQuoteInput> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant CrmQuoteInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    enabled: widget.enabled,
    maxLength: widget.maxLength,
    maxLines: widget.maxLines,
    minLines: widget.maxLines > 1 ? 2 : 1,
    textAlign: widget.textAlign,
    keyboardType: widget.number ? const TextInputType.numberWithOptions(decimal: true) : null,
    onChanged: widget.onChanged,
    style: const TextStyle(fontSize: 14),
    decoration: crmInputDecoration(
      hint: widget.hint,
    ).copyWith(counterText: '', fillColor: widget.enabled ? Colors.white : CrmColors.divider),
  );
}

/// Ô chọn ngày `yyyy-mm-dd` (web `DatePickerInput`); [value] rỗng là chưa chọn.
class CrmQuoteDateField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool enabled;
  const CrmQuoteDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final has = value.isNotEmpty;
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: parseCrmDay(value) ?? now,
                firstDate: DateTime(now.year - 10),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) onChanged(crmApiDate(picked));
            },
      child: InputDecorator(
        decoration: crmInputDecoration().copyWith(
          suffixIcon: has && enabled
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                  onPressed: () => onChanged(''),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18, color: CrmColors.muted),
        ),
        child: Text(
          has ? formatCrmDay(value) : (placeholder ?? 'crm.quotes.pick_date'.tr()),
          style: TextStyle(fontSize: 14, color: has ? CrmColors.text : CrmColors.faint),
        ),
      ),
    );
  }
}

String _modeText(CrmQuoteTemplate t) => 'crm.quotes.template_modes'.tr(
  args: {
    'discount': 'crm.quotes.mode.${t.discountMode.toLowerCase()}'.tr().toLowerCase(),
    'tax': 'crm.quotes.mode.${t.taxMode.toLowerCase()}'.tr().toLowerCase(),
  },
);

List<CrmSelectOption> crmTemplateOptions(List<CrmQuoteTemplate> templates) =>
    templates.map((t) => CrmSelectOption(value: t.id, label: t.name, description: _modeText(t))).toList();

/// Thông tin chung: mã (Sinh lại), tên, ngày báo giá, hiệu lực, loại (web `GeneralFields`, `showTemplate = false`).
class CrmQuoteGeneralFields extends StatefulWidget {
  final CrmQuoteGeneral value;
  final ValueChanged<CrmQuoteGeneral> onChanged;
  final List<CrmQuoteType> types;
  final bool generateCode;
  final String? nameError;
  const CrmQuoteGeneralFields({
    super.key,
    required this.value,
    required this.onChanged,
    required this.types,
    required this.generateCode,
    this.nameError,
  });

  @override
  State<CrmQuoteGeneralFields> createState() => _CrmQuoteGeneralFieldsState();
}

class _CrmQuoteGeneralFieldsState extends State<CrmQuoteGeneralFields> {
  bool _generating = false;

  Future<void> _regenerate() async {
    setState(() => _generating = true);
    try {
      final code = await CrmQuotesRepository.instance.generateCode();
      if (!mounted) return;
      // Ghép vào giá trị mới nhất (người dùng có thể đã gõ ô khác trong lúc chờ).
      widget.onChanged(widget.value.copyWith(code: code));
    } catch (e) {
      if (mounted) {
        showCrmSnack(context, crmQuoteFormError(e, 'crm.quotes.error.generate_code', crmErrorMessage), error: true);
      }
    }
    if (!mounted) return;
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmField(
          label: 'crm.quotes.field.code'.tr(),
          hint: (widget.generateCode ? 'crm.quotes.field.code_hint_new' : 'crm.quotes.field.code_hint_draft').tr(),
          child: Row(
            children: [
              Expanded(
                child: CrmQuoteInput(
                  value: v.code,
                  maxLength: 64,
                  onChanged: (t) => widget.onChanged(widget.value.copyWith(code: t)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _generating ? null : _regenerate,
                child: Text('crm.quotes.field.regenerate'.tr()),
              ),
            ],
          ),
        ),
        CrmField(
          label: 'crm.quotes.field.name'.tr(),
          required: true,
          error: widget.nameError,
          child: CrmQuoteInput(
            value: v.name,
            maxLength: 200,
            onChanged: (t) => widget.onChanged(widget.value.copyWith(name: t)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.field.quote_date'.tr(),
          child: CrmQuoteDateField(
            value: v.quoteDate,
            onChanged: (d) => widget.onChanged(widget.value.copyWith(quoteDate: d)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.field.valid_until'.tr(),
          hint: 'crm.quotes.field.valid_until_hint'.tr(),
          child: CrmQuoteDateField(
            value: v.validUntil,
            onChanged: (d) => widget.onChanged(widget.value.copyWith(validUntil: d)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.field.type'.tr(),
          child: CrmSelectField(
            value: v.typeId,
            options: widget.types.map((t) => CrmSelectOption(value: t.id, label: t.name)).toList(),
            placeholder: 'crm.quotes.field.type_default'.tr(),
            onChanged: (s) => widget.onChanged(widget.value.copyWith(typeId: s.value ?? '')),
          ),
        ),
      ],
    );
  }
}

/// Ô chọn mẫu ở đầu khung xem trước (web `TemplatePicker`): đổi mẫu là xem trước đổi ngay, chưa cần Lưu.
class CrmQuoteTemplatePicker extends StatelessWidget {
  final List<CrmQuoteTemplate> templates;
  final String value;
  final ValueChanged<String> onChanged;
  const CrmQuoteTemplatePicker({super.key, required this.templates, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => CrmSelectField(
    value: value,
    options: crmTemplateOptions(templates),
    placeholder: 'crm.quotes.field.template_default'.tr(),
    sheetTitle: 'crm.quotes.field.template'.tr(),
    onChanged: (s) {
      if (s.value != null) onChanged(s.value!);
    },
  );
}

/// Trường tuỳ biến vẽ theo định nghĩa (web `CustomFieldsEditor`).
class CrmQuoteCustomFieldsEditor extends StatelessWidget {
  final List<CrmCustomFieldDefinition> definitions;
  final Map<String, String> texts;
  final List<String> missing;
  final ValueChanged<Map<String, String>> onChanged;
  const CrmQuoteCustomFieldsEditor({
    super.key,
    required this.definitions,
    required this.texts,
    required this.missing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fields = crmActiveFields(definitions);
    if (fields.isEmpty) {
      return Text('crm.quotes.custom.empty'.tr(), style: const TextStyle(fontSize: 12.5, color: CrmColors.muted));
    }
    void set(String id, String text) => onChanged({...texts, id: text});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in fields)
          CrmField(
            label: f.name,
            required: f.required,
            error: missing.contains(f.name) ? 'crm.quotes.custom.required'.tr() : null,
            child: switch (f.fieldType) {
              'TEXT' => CrmQuoteInput(
                value: texts[f.id] ?? '',
                maxLength: 1000,
                maxLines: 3,
                onChanged: (t) => set(f.id, t),
              ),
              'SELECT' => CrmSelectField(
                value: texts[f.id] ?? '',
                options: f.options.map((o) => CrmSelectOption(value: o, label: o)).toList(),
                placeholder: 'crm.quotes.custom.pick'.tr(),
                clearable: !f.required,
                onChanged: (s) => set(f.id, s.value ?? ''),
              ),
              'DATE' => CrmQuoteDateField(value: texts[f.id] ?? '', onChanged: (d) => set(f.id, d)),
              _ => CrmQuoteInput(
                value: texts[f.id] ?? '',
                maxLength: 30,
                number: f.fieldType == 'NUMBER',
                onChanged: (t) => set(f.id, t),
              ),
            },
          ),
      ],
    );
  }
}

/// Chiết khấu hoặc thuế tổng đơn: % HOẶC số tiền (web `OrderAmountField`); mẫu theo dòng thì khoá và giải thích.
class CrmQuoteOrderAmountField extends StatelessWidget {
  final String labelKey;
  final CrmOrderAmountText value;
  final bool allowed;
  final String lineHint;
  final ValueChanged<CrmOrderAmountText> onChanged;
  const CrmQuoteOrderAmountField({
    super.key,
    required this.labelKey,
    required this.value,
    required this.allowed,
    required this.lineHint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = 'crm.quotes.order_title.$labelKey'.tr();
    if (!allowed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: lineHint),
            ],
          ),
          style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
        ),
      );
    }
    final locked = value.locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmField(
          label: '$label (%)',
          hint: 'crm.quotes.details.order_hint'.tr(),
          child: CrmQuoteInput(
            value: value.percent,
            number: true,
            enabled: locked != 'percent',
            onChanged: (t) => onChanged(CrmOrderAmountText(percent: t)),
          ),
        ),
        CrmField(
          label: '$label (VND)',
          child: CrmQuoteInput(
            value: value.amount,
            number: true,
            enabled: locked != 'amount',
            onChanged: (t) => onChanged(CrmOrderAmountText(amount: t)),
          ),
        ),
      ],
    );
  }
}

/// Phí trên cả hợp đồng (web `FeesEditor`).
class CrmQuoteFeesEditor extends StatelessWidget {
  final List<CrmFeeRow> rows;
  final ValueChanged<List<CrmFeeRow>> onChanged;
  const CrmQuoteFeesEditor({super.key, required this.rows, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    void patch(String key, CrmFeeRow Function(CrmFeeRow) change) =>
        onChanged(rows.map((r) => r.key == key ? change(r) : r).toList());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle('crm.quotes.details.fees'.tr()),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'crm.quotes.details.no_fees'.tr(),
              style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
            ),
          ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ValueKey(rows[i].key),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CrmQuoteInput(
                    value: rows[i].feeType,
                    maxLength: 200,
                    hint: 'crm.quotes.details.fee_type'.tr(args: {'n': i + 1}),
                    onChanged: (t) => patch(rows[i].key, (r) => r.copyWith(feeType: t)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: CrmQuoteInput(
                    value: rows[i].amount,
                    number: true,
                    hint: 'crm.quotes.details.fee_amount'.tr(),
                    onChanged: (t) => patch(rows[i].key, (r) => r.copyWith(amount: t)),
                  ),
                ),
                IconButton(
                  tooltip: 'crm.quotes.remove'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded, color: CrmColors.danger),
                  onPressed: () => onChanged(rows.where((r) => r.key != rows[i].key).toList()),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onChanged([...rows, CrmFeeRow()]),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('crm.quotes.details.add_fee'.tr()),
          ),
        ),
      ],
    );
  }
}

/// Khối "Cập nhật thông tin báo giá" (web `QuoteDetailsBlock`): thu gọn / mở; sửa trực tiếp, lưu chung bằng nút Lưu.
class CrmQuoteDetailsBlock extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final bool editable;
  final CrmQuoteDetailsState value;
  final ValueChanged<CrmQuoteDetailsState> onChanged;
  final List<CrmCustomFieldDefinition> fields;
  final List<String> missing;
  final ({String discount, String tax}) modes;
  final CrmQuoteVersion version;

  const CrmQuoteDetailsBlock({
    super.key,
    required this.open,
    required this.onToggle,
    required this.editable,
    required this.value,
    required this.onChanged,
    required this.fields,
    required this.missing,
    required this.modes,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: CrmColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'crm.quotes.details.title'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: CrmColors.primary),
                      ),
                      if (!open)
                        Text(
                          'crm.quotes.details.summary'.tr(),
                          style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) editable ? _editor() : _facts(),
      ],
    );
  }

  Widget _editor() {
    void set(CrmQuoteDetailsState next) => onChanged(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle('crm.quotes.details.content'.tr()),
        CrmField(
          label: 'crm.quotes.details.price_date'.tr(),
          hint: 'crm.quotes.details.price_date_hint'.tr(),
          child: CrmQuoteDateField(
            value: value.priceDate,
            placeholder: 'crm.quotes.today'.tr(),
            onChanged: (d) => set(value.copyWith(priceDate: d)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.details.shipping'.tr(),
          child: CrmQuoteInput(
            value: value.shipping,
            number: true,
            onChanged: (t) => set(value.copyWith(shipping: t)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.details.shipping_vat'.tr(),
          child: CrmQuoteInput(
            value: value.shippingVat,
            number: true,
            onChanged: (t) => set(value.copyWith(shippingVat: t)),
          ),
        ),
        CrmField(
          label: 'crm.quotes.details.shipping_cost'.tr(),
          hint: 'crm.quotes.details.shipping_cost_hint'.tr(),
          child: CrmQuoteInput(
            value: value.shippingCost,
            number: true,
            onChanged: (t) => set(value.copyWith(shippingCost: t)),
          ),
        ),
        CrmQuoteOrderAmountField(
          labelKey: 'discount',
          value: value.discount,
          allowed: modes.discount == 'ORDER',
          lineHint: 'crm.quotes.details.discount_line_hint'.tr(),
          onChanged: (d) => set(value.copyWith(discount: d)),
        ),
        CrmQuoteOrderAmountField(
          labelKey: 'tax',
          value: value.tax,
          allowed: modes.tax == 'ORDER',
          lineHint: 'crm.quotes.details.tax_line_hint'.tr(),
          onChanged: (t) => set(value.copyWith(tax: t)),
        ),
        CrmQuoteFeesEditor(
          rows: value.fees,
          onChanged: (f) => set(value.copyWith(fees: f)),
        ),
        CrmField(
          label: 'crm.quotes.field.note'.tr(),
          hint: 'crm.quotes.field.note_hint'.tr(),
          child: CrmQuoteInput(
            value: value.note,
            maxLength: 4000,
            maxLines: 4,
            onChanged: (t) => set(value.copyWith(note: t)),
          ),
        ),
        CrmSectionTitle('crm.quotes.custom.title'.tr()),
        CrmQuoteCustomFieldsEditor(
          definitions: fields,
          texts: value.custom,
          missing: missing,
          onChanged: (c) => set(value.copyWith(custom: c)),
        ),
        Text('crm.quotes.details.save_hint'.tr(), style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
      ],
    );
  }

  Widget _facts() {
    final v = version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmInfoRow(
          label: 'crm.quotes.details.price_date'.tr(),
          value: v.priceDate == null ? 'crm.quotes.details.by_created'.tr() : formatCrmDay(v.priceDate),
        ),
        CrmInfoRow(
          label: 'crm.quotes.details.shipping_short'.tr(),
          value: v.shipping.amount != 0
              ? '${formatCrmMoney(v.shipping.amount)} (VAT ${formatCrmPercent(v.shipping.vatRate)})'
              : 'crm.quotes.none'.tr(),
        ),
        for (var i = 0; i < v.form.fees.length; i++)
          CrmInfoRow(
            label: v.form.fees[i].feeType.isEmpty
                ? 'crm.quotes.details.fee_n'.tr(args: {'n': i + 1})
                : v.form.fees[i].feeType,
            value: formatCrmMoney(v.form.fees[i].amount),
          ),
        CrmInfoRow(
          label: 'crm.quotes.field.note'.tr(),
          value: (v.note ?? '').isEmpty ? 'crm.quotes.details.no_note'.tr() : v.note,
        ),
        for (final f in crmActiveFields(fields))
          CrmInfoRow(
            label: f.name,
            value: v.form.customFields[f.id] == null
                ? 'crm.quotes.custom.not_entered'.tr()
                : '${v.form.customFields[f.id]}',
          ),
      ],
    );
  }
}

// --- Bảng giá -------------------------------------------------------------------------------------------------------

/// Bảng giá đang gắn (đọc kèm để hiện cả khi bảng đã tắt, hết hạn).
class CrmChosenPriceList {
  final String id;
  final String? code;
  final String? name;
  final String? status;
  const CrmChosenPriceList({required this.id, this.code, this.name, this.status});
}

/// Web `priceListOptions`: chỉ bảng còn hiệu lực tại [date]; bảng đang gắn mà không còn chọn được vẫn có mặt.
List<CrmSelectOption> crmPriceListOptions(List<CrmPriceListSummary> lists, String date, [CrmChosenPriceList? current]) {
  final options = lists
      .where((l) => l.effectiveOn(date))
      .map((l) => CrmSelectOption(value: l.id, label: l.name, description: l.code))
      .toList();
  if (current != null && current.id.isNotEmpty && !options.any((o) => o.value == current.id)) {
    CrmPriceListSummary? known;
    for (final l in lists) {
      if (l.id == current.id) known = l;
    }
    final name = current.name ?? known?.name ?? current.id;
    final status = current.status ?? known?.status;
    final display = crmPriceListDisplayName(name, status);
    options.add(
      CrmSelectOption(
        value: current.id,
        label: display.isEmpty ? name : display,
        description: current.code ?? known?.code ?? '',
      ),
    );
  }
  return options;
}

/// Ô chọn "Bảng giá" (web `PriceListSelect`).
class CrmPriceListSelect extends StatelessWidget {
  final List<CrmPriceListSummary> lists;
  final String date;
  final String value;
  final CrmChosenPriceList? current;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const CrmPriceListSelect({
    super.key,
    required this.lists,
    required this.date,
    required this.value,
    this.current,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = crmPriceListOptions(lists, date, current);
    return CrmSelectField(
      value: value,
      options: options,
      enabled: enabled,
      placeholder: options.isEmpty ? 'crm.quotes.price_list.none'.tr() : 'crm.quotes.price_list.placeholder'.tr(),
      emptyText: options.isEmpty ? 'crm.quotes.price_list.none'.tr() : 'crm.quotes.price_list.no_match'.tr(),
      onChanged: (s) {
        if (s.value != null) onChanged(s.value!);
      },
    );
  }
}

/// Thông báo đồng bộ bảng giá mặc định với Kho cho quản trị CRM (web `PriceListSyncBanner`). Người khác không gọi API;
/// đang tải hoặc lỗi thì không hiện gì.
class CrmPriceListSyncBanner extends StatefulWidget {
  final bool canManage;
  const CrmPriceListSyncBanner({super.key, required this.canManage});

  @override
  State<CrmPriceListSyncBanner> createState() => _CrmPriceListSyncBannerState();
}

class _CrmPriceListSyncBannerState extends State<CrmPriceListSyncBanner> {
  CrmPriceListSyncStatus? _status;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.canManage) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final next = await CrmQuotesRepository.instance.loadCatalogSyncStatus();
      if (mounted) setState(() => _status = next);
    } catch (_) {
      if (mounted) setState(() => _status = null);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final r = await CrmQuotesRepository.instance.syncCatalog();
      if (!mounted) return;
      var message = 'crm.quotes.sync.done'.tr(args: {'added': r.added, 'updated': r.updated, 'removed': r.removed});
      if (r.skippedWithoutUnit > 0) message += ' ${'crm.quotes.sync.skipped'.tr(args: {'n': r.skippedWithoutUnit})}';
      if (r.derivedListsUpdated > 0) message += ' ${'crm.quotes.sync.derived'.tr(args: {'n': r.derivedListsUpdated})}';
      showCrmSnack(context, message);
      setState(() => _status = null);
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.sync.error'));
    }
    if (!mounted) return;
    setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (!widget.canManage || status == null || !status.needsSync) return const SizedBox.shrink();
    final reason = status.reason == 'NO_DEFAULT' ? 'crm.quotes.sync.no_default' : 'crm.quotes.sync.catalog_changed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(reason.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF92400E))),
              ),
              const SizedBox(width: 8),
              CrmButton(
                label: _syncing ? 'crm.quotes.sync.syncing'.tr() : 'crm.quotes.sync.action'.tr(),
                icon: Icons.sync_rounded,
                busy: _syncing,
                onPressed: _sync,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: CrmColors.danger)),
            ),
        ],
      ),
    );
  }
}
