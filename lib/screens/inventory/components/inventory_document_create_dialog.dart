import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/inventory/data/documents/stock_document_api.dart';
import '../../../features/inventory/domain/documents/stock_document_logic.dart';
import '../../../features/inventory/domain/documents/stock_document_models.dart';
import '../../../features/inventory/presentation/documents/document_widgets.dart';
import '../../../features/inventory/presentation/documents/lot_serial_pickers.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';
import '../../../features/inventory/presentation/utils/inventory_number.dart';

class _LineCtrls {
  final TextEditingController quantity = TextEditingController();
  final TextEditingController unitCost = TextEditingController();
  final TextEditingController lotNo = TextEditingController();
  final TextEditingController note = TextEditingController();

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    lotNo.dispose();
    note.dispose();
  }
}

String _plain(double? v) {
  if (v == null || !v.isFinite) return '';
  return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

double? _parse(String text) {
  return parseVnNumber(text);
}

/// Form chứng từ kho nhiều dòng (web `StockDocumentForm`): phần đầu (loại, kho, kho đến khi điều chuyển,
/// ngày, nguồn, ghi chú) và các dòng. Dòng xuất chọn lô FEFO và serial; dòng nhập ghi số lô, hạn dùng, đơn giá.
/// Lưu ra Nháp; "Lưu và gửi duyệt" hoặc "Lưu và ghi sổ" tuỳ loại. [show] trả chứng từ đã lưu và câu thông báo.
class InventoryDocumentCreateDialog extends StatefulWidget {
  final DocumentDraft initial;
  final String? documentId;
  final DocRefs refs;

  const InventoryDocumentCreateDialog({super.key, required this.initial, required this.refs, this.documentId});

  static Future<({StockDoc document, String message})?> show(
    BuildContext context, {
    required DocumentDraft initial,
    required DocRefs refs,
    String? documentId,
  }) {
    return showModalBottomSheet<({StockDoc document, String message})>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryDocumentCreateDialog(initial: initial, refs: refs, documentId: documentId),
    );
  }

  @override
  State<InventoryDocumentCreateDialog> createState() => _InventoryDocumentCreateDialogState();
}

class _InventoryDocumentCreateDialogState extends State<InventoryDocumentCreateDialog> {
  late DocumentDraft _draft = widget.initial;
  final Map<String, _LineCtrls> _ctrls = {};
  late final TextEditingController _sourceCtrl = TextEditingController(text: widget.initial.sourceType ?? '');
  late final TextEditingController _noteCtrl = TextEditingController(text: widget.initial.note ?? '');
  late final Map<String, DocMaterial> _materialByCode = widget.refs.materialByCode;
  bool _busy = false;
  String? _serverError;
  String? _showErrors; // 'save' | 'post'

  bool get _editing => widget.documentId != null;
  bool get _lockedSource => (widget.initial.sourceId ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final l in _draft.lines) {
      _sync(l);
    }
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Đặt lại ô nhập của dòng theo giá trị bản nháp (khi tạo dòng, đổi loại/kho, tách lô).
  void _sync(DraftLine l) {
    final c = _ctrls.putIfAbsent(l.key, _LineCtrls.new);
    c.quantity.text = _plain(l.quantity);
    c.unitCost.text = _plain(l.unitCost);
    c.lotNo.text = l.lotNo ?? '';
    c.note.text = l.note ?? '';
  }

  void _patchLine(String key, DraftLine Function(DraftLine) update, {bool sync = false}) {
    setState(() {
      _draft = _draft.copyWith(lines: [
        for (final l in _draft.lines) l.key == key ? update(l) : l,
      ]);
    });
    if (sync) {
      final line = _draft.lines.firstWhere((l) => l.key == key);
      _sync(line);
    }
  }

  void _resetLines(DraftLine Function(DraftLine) update) {
    setState(() => _draft = _draft.copyWith(lines: _draft.lines.map(update).toList()));
    for (final l in _draft.lines) {
      _ctrls[l.key]?.lotNo.text = l.lotNo ?? '';
    }
  }

  List<DocOption> get _typeOptions {
    final types = {...kManualDocumentTypes, widget.initial.docType};
    return [
      for (final t in types)
        DocOption(
          t,
          docTypeLabel(t),
          requiresApproval(t, widget.initial.sourceId)
              ? 'inventory.documents.form.needs_approval'.tr()
              : 'inventory.documents.form.no_approval'.tr(),
        ),
    ];
  }

  List<DocOption> get _warehouseOptions =>
      [for (final w in widget.refs.warehouses.where((w) => w.isActive)) DocOption(w.code, w.label)];

  List<DocOption> get _materialOptions => [
        for (final m in widget.refs.materials.where((m) => m.kind != 'SERVICE' && m.isActive))
          DocOption(
            m.code,
            '${m.code} - ${m.name}',
            m.isSerialized ? 'inventory.documents.form.unit_serial'.tr(args: {'unit': m.unit}) : m.unit,
          ),
      ];

  Future<void> _save([String? then]) async {
    setState(() => _showErrors = then == 'post' ? 'post' : 'save');
    final check = validateDraft(_draft, _materialByCode, forPosting: then == 'post');
    if (!check.valid) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final api = StockDocumentApi.instance;
    try {
      var saved = widget.documentId != null
          ? await api.update(widget.documentId!, {
              'warehouseCode': _draft.warehouseCode,
              if (_draft.docType == 'TRANSFER') 'targetWarehouseCode': _draft.targetWarehouseCode ?? '',
              'documentDate': _draft.documentDate,
              'note': _draft.note ?? '',
              'lines': _draft.lines.map((l) => draftLineToInput(_draft.docType, l)).toList(),
            })
          : await api.create(draftToCreateRequest(_draft));
      var message = 'inventory.documents.msg.draft_saved'.tr(args: {'code': saved.code});
      if (then == 'submit') {
        saved = await api.submit(saved.id);
        message = 'inventory.documents.msg.saved_submitted'.tr(args: {'code': saved.code});
      } else if (then == 'post') {
        try {
          saved = await api.post(saved.id);
          message = 'inventory.documents.msg.saved_posted'.tr(args: {'code': saved.code});
        } catch (e) {
          InventoryScope.instance.onError(e);
          // Nháp đã lưu; báo lỗi ghi sổ để người dùng sửa tiếp trên chứng từ đã có.
          if (!mounted) return;
          Navigator.of(context).pop((
            document: saved,
            message: 'inventory.documents.msg.saved_not_posted'
                .tr(args: {'code': saved.code, 'error': inventoryErrorMessage(e)}),
          ));
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop((document: saved, message: message));
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = inventoryErrorMessage(e, 'inventory.documents.error.save_failed');
      });
    }
  }

  Future<void> _pickSerials(DraftLine line) async {
    final material = _materialByCode[line.materialCode];
    final result = await showSerialPicker(
      context,
      materialCode: line.materialCode,
      materialName: material?.name,
      warehouse: widget.refs.warehouse(_draft.warehouseCode),
      quantity: line.quantity,
      value: line.serials,
      inbound: lineDirection(_draft.docType, line.direction) == 'IN',
    );
    if (result == null || !mounted) return;
    _patchLine(line.key, (l) => l.copyWith(serials: result));
  }

  Future<void> _pickLot(DraftLine line) async {
    final result = await showLotPicker(
      context,
      materialCode: line.materialCode,
      warehouseCode: _draft.warehouseCode,
      quantity: line.quantity.isFinite ? line.quantity : 0,
      unit: _materialByCode[line.materialCode]?.unit,
      current: line.lotNo,
    );
    if (result == null || !mounted) return;
    final replacement = splitLineByLots(line, result);
    setState(() {
      _draft = _draft.copyWith(lines: [
        for (final l in _draft.lines)
          if (l.key == line.key) ...replacement else l,
      ]);
    });
    for (final l in replacement) {
      _sync(l);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = validateDraft(_draft, _materialByCode, forPosting: _showErrors == 'post');
    final messages = _showErrors != null ? validation.messages : const <String>[];
    final approval = requiresApproval(_draft.docType, _draft.sourceId);
    final total = _draft.lines.fold<double>(0, (s, l) => s + (l.quantity.isFinite ? l.quantity : 0));
    final isTransfer = _draft.docType == 'TRANSFER';

    return PopScope(
      canPop: !_busy,
      child: DocSheetFrame(
        closable: !_busy,
        title: Text(
          _editing ? 'inventory.documents.form.edit_title'.tr() : 'inventory.documents.form.create_title'.tr(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DocSelect(
              label: 'inventory.documents.form.doc_type'.tr(),
              options: _typeOptions,
              value: _draft.docType,
              enabled: !_editing,
              onChanged: (v) {
                setState(() => _draft = _draft.copyWith(docType: v));
                _resetLines((l) => l.copyWith(direction: null, serials: const [], lotNo: null));
              },
            ),
            const SizedBox(height: 10),
            DocSelect(
              label: isTransfer ? 'inventory.documents.form.warehouse_from'.tr() : 'inventory.documents.field.warehouse'.tr(),
              options: _warehouseOptions,
              value: _draft.warehouseCode,
              hint: 'inventory.documents.form.choose_warehouse'.tr(),
              enabled: !_lockedSource,
              onChanged: (v) {
                setState(() => _draft = _draft.copyWith(warehouseCode: v));
                _resetLines((l) => l.copyWith(serials: const [], lotNo: null));
              },
            ),
            if (isTransfer) ...[
              const SizedBox(height: 10),
              DocSelect(
                label: 'inventory.documents.form.warehouse_to'.tr(),
                options: _warehouseOptions.where((o) => o.value != _draft.warehouseCode).toList(),
                value: _draft.targetWarehouseCode,
                hint: 'inventory.documents.form.choose_target'.tr(),
                onChanged: (v) => setState(() => _draft = _draft.copyWith(targetWarehouseCode: v)),
              ),
            ],
            const SizedBox(height: 10),
            DocDateField(
              label: 'inventory.documents.field.document_date'.tr(),
              value: _draft.documentDate,
              clearable: false,
              onChanged: (v) => setState(() => _draft = _draft.copyWith(documentDate: v ?? _draft.documentDate)),
            ),
            const SizedBox(height: 10),
            DocFieldLabel('inventory.documents.form.source_label'.tr()),
            const SizedBox(height: 4),
            TextField(
              controller: _sourceCtrl,
              enabled: !(_lockedSource || _editing),
              decoration: docInputDecoration(hint: 'inventory.documents.form.source_hint'.tr()),
              onChanged: (v) => _draft = _draft.copyWith(sourceType: v),
            ),
            const SizedBox(height: 10),
            DocFieldLabel('inventory.documents.field.note'.tr()),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              decoration: docInputDecoration(),
              onChanged: (v) => _draft = _draft.copyWith(note: v),
            ),
            if (approval) ...[
              const SizedBox(height: 8),
              Text('inventory.documents.form.approval_hint'.tr(),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text('inventory.documents.form.lines'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
              ),
              ElevatedButton.icon(
                style: docButtonStyle(),
                onPressed: () {
                  final line = DraftLine.empty();
                  setState(() => _draft = _draft.copyWith(lines: [..._draft.lines, line]));
                  _sync(line);
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text('inventory.documents.form.add_line'.tr()),
              ),
            ]),
            const SizedBox(height: 8),
            for (var i = 0; i < _draft.lines.length; i++) ...[
              _lineCard(i, _draft.lines[i], _showErrors != null && validation.lines.containsKey(_draft.lines[i].key)),
              const SizedBox(height: 10),
            ],
            if (messages.isNotEmpty || _serverError != null)
              DocMessages([?_serverError, ...messages]),
          ],
        ),
        footer: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'inventory.documents.form.summary'.tr(args: {'n': _draft.lines.length, 'total': formatQty(total)}),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
            ElevatedButton(
              style: docButtonStyle(),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text('inventory.documents.common.close'.tr()),
            ),
            ElevatedButton(
              style: docButtonStyle(),
              onPressed: _busy ? null : () => _save(),
              child: Text('inventory.documents.form.save_draft'.tr()),
            ),
            ElevatedButton(
              style: docButtonStyle(primary: true),
              onPressed: _busy ? null : () => _save(approval ? 'submit' : 'post'),
              child: _busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(approval
                      ? 'inventory.documents.form.save_submit'.tr()
                      : 'inventory.documents.form.save_post'.tr()),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _lineCard(int index, DraftLine line, bool hasError) {
    final c = _ctrls.putIfAbsent(line.key, _LineCtrls.new);
    final material = _materialByCode[line.materialCode];
    final direction = lineDirection(_draft.docType, line.direction);
    final inbound = direction == 'IN';
    final reservedLocked = _lockedSource && (line.reservationId ?? '').isNotEmpty;
    final need = line.quantity.isFinite && line.quantity > 0 ? line.quantity.truncate() : 0;
    const muted = TextStyle(fontSize: 12.5, color: AppColors.slate500);

    Widget lotWidget;
    if (material == null) {
      lotWidget = const Text('—', style: muted);
    } else if (material.isSerialized) {
      lotWidget = Text('inventory.documents.form.by_serial'.tr(), style: muted);
    } else if (inbound) {
      lotWidget = Row(children: [
        Expanded(
          child: TextField(
            controller: c.lotNo,
            textCapitalization: TextCapitalization.characters,
            decoration: docInputDecoration(hint: 'inventory.documents.form.lot_no'.tr()),
            onChanged: (v) {
              final upper = v.toUpperCase();
              if (upper != v) {
                c.lotNo.value = c.lotNo.value.copyWith(text: upper);
              }
              _patchLine(line.key, (l) => l.copyWith(lotNo: upper));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DocDateField(
            value: line.lotExpiresOn,
            placeholder: 'inventory.documents.form.expiry'.tr(),
            onChanged: (v) => _patchLine(line.key, (l) => l.copyWith(lotExpiresOn: v)),
          ),
        ),
      ]);
    } else {
      lotWidget = Align(
        alignment: Alignment.centerLeft,
        child: DocPickButton(
          (line.lotNo ?? '').isNotEmpty
              ? '${line.lotNo}${(line.lotExpiresOn ?? '').isNotEmpty ? ' · ${'inventory.documents.field.expiry_short'.tr(args: {'date': Formatters.formatDate(line.lotExpiresOn)})}' : ''}'
              : 'inventory.documents.form.pick_lot'.tr(),
          onTap: _draft.warehouseCode.isEmpty ? null : () => _pickLot(line),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFEF2F2) : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasError ? const Color(0xFFFECACA) : kDocBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate700)),
          const Spacer(),
          IconButton(
            tooltip: 'inventory.documents.form.remove_line'.tr(),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: const Color(0xFFB91C1C),
            visualDensity: VisualDensity.compact,
            onPressed: _draft.lines.length <= 1 || reservedLocked
                ? null
                : () => setState(() => _draft = _draft.copyWith(
                    lines: _draft.lines.where((l) => l.key != line.key).toList())),
          ),
        ]),
        DocSelect(
          label: 'inventory.documents.field.material'.tr(),
          options: _materialOptions,
          value: line.materialCode,
          hint: 'inventory.documents.form.choose_material'.tr(),
          enabled: !reservedLocked,
          onChanged: (code) {
            _patchLine(line.key, (l) => l.copyWith(materialCode: code, serials: const [], lotNo: null));
            c.lotNo.text = '';
          },
        ),
        if (_draft.docType == 'ADJUSTMENT') ...[
          const SizedBox(height: 8),
          DocSelect(
            label: 'inventory.documents.form.direction'.tr(),
            options: [
              DocOption('IN', 'inventory.documents.form.dir_in'.tr()),
              DocOption('OUT', 'inventory.documents.form.dir_out'.tr()),
            ],
            value: line.direction,
            hint: 'inventory.documents.form.dir_hint'.tr(),
            onChanged: (v) {
              _patchLine(line.key, (l) => l.copyWith(direction: v, serials: const [], lotNo: null));
              c.lotNo.text = '';
            },
          ),
        ],
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DocFieldLabel('inventory.documents.field.quantity'.tr()),
              const SizedBox(height: 4),
              TextField(
                controller: c.quantity,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: docInputDecoration().copyWith(suffixText: material?.unit),
                onChanged: (v) => _patchLine(line.key, (l) => l.copyWith(quantity: _parse(v) ?? double.nan)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DocFieldLabel('inventory.documents.field.unit_cost'.tr()),
              const SizedBox(height: 4),
              if (inbound)
                TextField(
                  controller: c.unitCost,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: docInputDecoration(hint: 'inventory.documents.form.avg_cost'.tr()),
                  onChanged: (v) => _patchLine(line.key, (l) => l.copyWith(unitCost: _parse(v))),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('inventory.documents.form.cost_on_post'.tr(), style: muted),
                ),
            ]),
          ),
        ]),
        if (inbound)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('inventory.documents.form.avg_cost_hint'.tr(),
                style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          ),
        const SizedBox(height: 8),
        DocFieldLabel('inventory.documents.field.lot'.tr()),
        const SizedBox(height: 4),
        lotWidget,
        if (material?.isSerialized ?? false) ...[
          const SizedBox(height: 8),
          DocFieldLabel('inventory.documents.field.serial'.tr()),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: DocPickButton(
              'inventory.documents.form.serial_count'.tr(args: {'n': line.serials.length, 'need': need}),
              onTap: _draft.warehouseCode.isEmpty || need == 0 ? null : () => _pickSerials(line),
            ),
          ),
        ],
        const SizedBox(height: 8),
        DocFieldLabel('inventory.documents.form.line_note'.tr()),
        const SizedBox(height: 4),
        TextField(
          controller: c.note,
          decoration: docInputDecoration(),
          onChanged: (v) => _patchLine(line.key, (l) => l.copyWith(note: v)),
        ),
      ]),
    );
  }
}
