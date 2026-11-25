import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../theme/colors.dart';
import '../../data/documents/stock_document_api.dart';
import '../../domain/documents/stock_document_logic.dart';
import '../../domain/documents/stock_document_models.dart';
import '../utils/inventory_scope.dart';
import 'document_widgets.dart';
import 'lot_serial_pickers.dart';

/// Thủ kho xử lý một yêu cầu xuất từ đơn bán (web `IssueRequestWorkbench`): xem giữ hàng còn bao nhiêu chưa
/// xuất, chọn lô FEFO, quét serial, lưu lựa chọn hoặc ghi sổ thẳng từ Nháp; huỷ chứng từ.
Future<void> showIssueRequestWorkbench(
  BuildContext context, {
  required StockDoc document,
  required List<ReservationRow> reservations,
  required DocRefs refs,
  required bool canWrite,
  required void Function(StockDoc document, String message) onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _Workbench(
      document: document,
      reservations: reservations,
      refs: refs,
      canWrite: canWrite,
      onSaved: onSaved,
    ),
  );
}

class _Workbench extends StatefulWidget {
  final StockDoc document;
  final List<ReservationRow> reservations;
  final DocRefs refs;
  final bool canWrite;
  final void Function(StockDoc document, String message) onSaved;
  const _Workbench({
    required this.document,
    required this.reservations,
    required this.refs,
    required this.canWrite,
    required this.onSaved,
  });

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench> {
  late StockDoc _doc = widget.document;
  late DocumentDraft _draft = DocumentDraft.fromDocument(widget.document);
  late final Map<String, DocMaterial> _materialByCode = widget.refs.materialByCode;
  late final Set<String> _serialized =
      widget.refs.materials.where((m) => m.isSerialized).map((m) => m.code).toSet();
  bool _busy = false;
  String? _error;
  bool _showErrors = false;

  List<StockDocLine> get _workingLines => [
        for (var i = 0; i < _draft.lines.length; i++)
          StockDocLine(
            id: _draft.lines[i].key,
            lineNo: i + 1,
            materialId: _materialByCode[_draft.lines[i].materialCode]?.id ?? '',
            materialCode: _draft.lines[i].materialCode,
            materialName: _materialByCode[_draft.lines[i].materialCode]?.name ?? _draft.lines[i].materialCode,
            unit: _materialByCode[_draft.lines[i].materialCode]?.unit,
            quantity: _draft.lines[i].quantity,
            direction: 'OUT',
            reservationId: _draft.lines[i].reservationId,
            lotNo: _draft.lines[i].lotNo,
            lotExpiresOn: _draft.lines[i].lotExpiresOn,
            serials: _draft.lines[i].serials,
          ),
      ];

  Future<void> _save(bool post) async {
    final lines = _workingLines;
    final problems = issueReadiness(issueLineProgress(_doc.warehouseId, lines, widget.reservations, _serialized));
    setState(() => _showErrors = true);
    final check = validateDraft(_draft, _materialByCode, forPosting: post);
    if (!check.valid || (post && problems.isNotEmpty)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = StockDocumentApi.instance;
    try {
      final saved = await api.update(_doc.id, {
        'lines': _draft.lines.map((l) => draftLineToInput(_doc.docType, l)).toList(),
      });
      if (!post) {
        if (!mounted) return;
        widget.onSaved(saved, 'inventory.documents.issue.msg_saved'.tr(args: {'code': saved.code}));
        setState(() {
          _busy = false;
          _showErrors = false;
          _doc = saved;
          _draft = DocumentDraft.fromDocument(saved);
        });
        return;
      }
      final posted = await api.post(saved.id);
      if (!mounted) return;
      widget.onSaved(posted, 'inventory.documents.issue.msg_posted'.tr(args: {'code': posted.code}));
      Navigator.of(context).pop();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.documents.error.save_failed');
      });
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDocAction(
      context,
      title: 'inventory.documents.issue.cancel_title'.tr(),
      description: 'inventory.documents.issue.cancel_desc'.tr(),
      okLabel: 'inventory.documents.action.cancel'.tr(),
      cancelLabel: 'inventory.documents.common.no'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cancelled = await StockDocumentApi.instance.cancel(_doc.id);
      if (!mounted) return;
      widget.onSaved(cancelled, 'inventory.documents.msg.cancelled'.tr(args: {'code': cancelled.code}));
      Navigator.of(context).pop();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = inventoryErrorMessage(e, 'inventory.documents.error.cancel_failed');
      });
    }
  }

  Future<void> _post(bool ready) async {
    if (!ready) {
      setState(() => _showErrors = true);
      return;
    }
    final ok = await confirmDocAction(
      context,
      title: 'inventory.documents.issue.post_title'.tr(),
      description: 'inventory.documents.issue.post_desc'.tr(),
      okLabel: 'inventory.documents.action.post'.tr(),
    );
    if (!ok || !mounted) return;
    await _save(true);
  }

  Future<void> _pickLot(DraftLine line) async {
    final result = await showLotPicker(
      context,
      materialCode: line.materialCode,
      warehouseCode: _doc.warehouseCode,
      quantity: line.quantity,
      unit: _materialByCode[line.materialCode]?.unit,
      current: line.lotNo,
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(lines: [
        for (final l in _draft.lines)
          if (l.key == line.key) ...splitLineByLots(line, result) else l,
      ]);
    });
  }

  Future<void> _pickSerials(DraftLine line) async {
    final result = await showSerialPicker(
      context,
      materialCode: line.materialCode,
      materialName: _materialByCode[line.materialCode]?.name,
      warehouse: widget.refs.warehouse(_doc.warehouseCode),
      quantity: line.quantity,
      value: line.serials,
      inbound: false,
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(lines: [
        for (final l in _draft.lines) l.key == line.key ? l.copyWith(serials: result) : l,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = _workingLines;
    final progress = issueLineProgress(_doc.warehouseId, lines, widget.reservations, _serialized);
    final problems = issueReadiness(progress);
    final validation = validateDraft(_draft, _materialByCode, forPosting: true);
    final messages = _showErrors ? [...validation.messages, ...problems] : const <String>[];
    final reservationIds = _draft.lines.map((l) => l.reservationId).whereType<String>().toSet();
    final linked = [
      for (final id in reservationIds) ...widget.reservations.where((r) => r.id == id),
    ];
    const muted = TextStyle(fontSize: 12, color: AppColors.slate500);

    return PopScope(
      canPop: !_busy,
      child: DocSheetFrame(
        closable: !_busy,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(_doc.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
            DocStatusBadge(_doc.status),
          ]),
          const SizedBox(height: 2),
          Text(
            'inventory.documents.issue.subtitle'.tr(args: {
              'type': docTypeLabel(_doc.docType),
              'warehouse': _doc.warehouseCode,
              'date': Formatters.formatDate(_doc.documentDate),
            }),
            style: muted,
          ),
        ]),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DocInfoGrid([
              DocInfoCell('inventory.documents.field.source'.tr(), sourceTypeLabel(_doc.sourceType), small: _doc.sourceId),
              for (final r in linked)
                DocInfoCell(
                  'inventory.documents.issue.reservation'.tr(),
                  '${r.reservationCode} · ${reservationStatusLabel(r.status)}',
                  small: (r.expiresAt ?? '').isNotEmpty
                      ? 'inventory.documents.issue.reservation_expires'
                          .tr(args: {'date': Formatters.formatDate(r.expiresAt)})
                      : null,
                ),
            ]),
            if ((_doc.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('inventory.documents.field.note_value'.tr(args: {'note': _doc.note!}), style: muted),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < lines.length; i++) ...[_lineCard(_draft.lines[i], lines[i], progress[i]), const SizedBox(height: 8)],
            if (problems.isNotEmpty && !_showErrors) DocBanner(problems.join(' ')),
            if (messages.isNotEmpty || _error != null) ...[
              const SizedBox(height: 8),
              DocMessages([if (_error != null) _error!, ...messages]),
            ],
            if (!widget.canWrite) ...[
              const SizedBox(height: 8),
              Text('inventory.documents.issue.need_permission'.tr(), style: muted),
            ],
          ],
        ),
        footer: widget.canWrite
            ? Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
                ElevatedButton(
                  style: docButtonStyle(danger: true),
                  onPressed: _busy ? null : _cancel,
                  child: Text('inventory.documents.action.cancel'.tr()),
                ),
                ElevatedButton(
                  style: docButtonStyle(),
                  onPressed: _busy ? null : () => _save(false),
                  child: Text('inventory.documents.issue.save_selection'.tr()),
                ),
                ElevatedButton.icon(
                  style: docButtonStyle(primary: true),
                  onPressed: _busy ? null : () => _post(problems.isEmpty && validation.valid),
                  icon: const Icon(Icons.inventory_outlined, size: 16),
                  label: Text('inventory.documents.action.post'.tr()),
                ),
              ])
            : null,
      ),
    );
  }

  Widget _lineCard(DraftLine draft, StockDocLine line, IssueLineProgress progress) {
    const muted = TextStyle(fontSize: 12, color: AppColors.slate500);
    final serialized = _serialized.contains(line.materialCode);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: kDocBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${line.lineNo}  ', style: muted),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.materialCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(line.materialName, style: muted),
            ]),
          ),
          Text('${formatQty(line.quantity)} ${line.unit ?? ''}'.trim(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        DocFieldLabel('inventory.documents.issue.reservation_col'.tr()),
        if ((line.reservationId ?? '').isEmpty)
          Text('inventory.documents.issue.no_reservation'.tr(), style: muted)
        else ...[
          Text(
            progress.reservationCode ??
                (line.reservationId!.length > 8 ? line.reservationId!.substring(0, 8) : line.reservationId!),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          if (progress.outstanding != null)
            Text(
              'inventory.documents.issue.progress'.tr(args: {
                'reserved': formatQty(progress.reserved ?? 0),
                'issued': formatQty(progress.issued ?? 0),
                'left': formatQty(progress.outstanding),
              }),
              style: muted,
            ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DocFieldLabel('inventory.documents.field.lot'.tr()),
              const SizedBox(height: 4),
              if (serialized)
                Text('inventory.documents.form.by_serial'.tr(), style: muted)
              else
                DocPickButton(
                  (line.lotNo ?? '').isNotEmpty
                      ? '${line.lotNo}${(line.lotExpiresOn ?? '').isNotEmpty ? ' · ${'inventory.documents.field.expiry_short'.tr(args: {'date': Formatters.formatDate(line.lotExpiresOn)})}' : ''}'
                      : 'inventory.documents.form.pick_lot'.tr(),
                  onTap: widget.canWrite ? () => _pickLot(draft) : null,
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DocFieldLabel('inventory.documents.field.serial'.tr()),
              const SizedBox(height: 4),
              if (!serialized)
                const Text('—', style: muted)
              else
                DocPickButton(
                  'inventory.documents.form.serial_count'
                      .tr(args: {'n': line.serials.length, 'need': line.quantity.truncate()}),
                  warn: progress.missingSerials > 0,
                  onTap: widget.canWrite ? () => _pickSerials(draft) : null,
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}
