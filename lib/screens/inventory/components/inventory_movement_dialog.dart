import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/ledger/ledger_repository.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/domain/ledger/ledger_models.dart';
import '../../../features/inventory/domain/ledger/movement_models.dart';
import '../../../features/inventory/presentation/ledger/ledger_format.dart';
import '../../../features/inventory/presentation/ledger/movement_form_parts.dart';
import '../../../features/inventory/presentation/stock_import/stock_import_sheet.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../features/workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../../models/inventory_models.dart';
import '../../../theme/colors.dart';

/// Phiếu nhập / xuất / chuyển kho đa vật tư — web movement-form.tsx (MovementForm, isDialog)
/// + cách ghi sổ của inventory-screen.tsx (`runMovement`).
class InventoryMovementDialog extends StatefulWidget {
  /// Giữ để tương thích các màn đang gọi; danh mục vật tư nay đọc thẳng từ API như web.
  final List<InventoryItem> items;
  final String? initialKind; // 'receipt', 'issue', 'transfer'
  final Future<void> Function()? onSubmitted;
  final String? initialMaterialCode;
  final double? initialQuantity;
  final String? initialNote;
  final String? title;
  final String? description;

  /// Cảnh báo giữ chỗ (web chỉ truyền ở form chính, không truyền ở popup của Lịch sử xuất nhập).
  final bool withReservations;

  const InventoryMovementDialog({
    super.key,
    required this.items,
    this.initialKind,
    this.onSubmitted,
    this.initialMaterialCode,
    this.initialQuantity,
    this.initialNote,
    this.title,
    this.description,
    this.withReservations = true,
  });

  static Future<void> show(
    BuildContext context, {
    required List<InventoryItem> items,
    String? initialKind,
    Future<void> Function()? onSubmitted,
    String? initialMaterialCode,
    double? initialQuantity,
    String? initialNote,
    String? title,
    String? description,
    bool withReservations = true,
  }) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => InventoryMovementDialog(
        items: items,
        initialKind: initialKind,
        onSubmitted: onSubmitted,
        initialMaterialCode: initialMaterialCode,
        initialQuantity: initialQuantity,
        initialNote: initialNote,
        title: title,
        description: description,
        withReservations: withReservations,
      ),
    ));
  }

  @override
  State<InventoryMovementDialog> createState() => _InventoryMovementDialogState();
}

class _LiveStock {
  final String code;
  final String status; // loading | error | ready
  final Map<String, ({double quantity, double available})> levels;
  const _LiveStock(this.code, this.status, [this.levels = const {}]);
}

class _InventoryMovementDialogState extends State<InventoryMovementDialog> {
  final LedgerRepository _repo = LedgerRepository.instance;

  // Dữ liệu
  bool _loading = true;
  String? _loadError;
  LedgerWorkspace _ws = LedgerWorkspace.empty;
  List<ProcedureOption> _procedures = const [];
  List<ProcedureWorkOrder> _workOrders = const [];
  List<LedgerReservation> _reservations = const [];
  List<String> _units = const [];
  List<String> _types = const [];
  final Map<String, List<LedgerLot>> _lots = {};

  // Phiếu
  late MovementKind _kind = movementKindFrom(widget.initialKind);
  String _warehouseCode = '';
  String _toWarehouseCode = '';
  IssueTargetType _issueTargetType = IssueTargetType.department;
  final _issueTargetName = TextEditingController();
  final _supplierName = TextEditingController();
  final _supplierAddress = TextEditingController();
  final _invoiceNumber = TextEditingController();
  String _targetAssetCode = '';
  String _procedureId = '';
  late final _note = TextEditingController(text: widget.initialNote ?? '');
  PlatformFile? _file;
  int _fileSize = 0;
  final List<MovementLine> _lines = [];
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _costCtrls = {};
  final Map<String, TextEditingController> _lineNoteCtrls = {};
  String? _warehouseNotice;
  _LiveStock? _live;
  int _liveRequest = 0;
  bool _submitting = false;
  String? _submitError;
  String _initialSnapshot = '';

  bool get _outbound => _kind == MovementKind.issue || _kind == MovementKind.transfer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_issueTargetName, _supplierName, _supplierAddress, _invoiceNumber, _note]) {
      c.dispose();
    }
    for (final m in [_qtyCtrls, _costCtrls, _lineNoteCtrls]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _repo.loadWorkspace(),
        _repo.loadProcedureWorkspace(),
        widget.withReservations ? _repo.loadReservations() : Future.value(const <LedgerReservation>[]),
        _repo.loadCatalogs(),
        InventoryScope.instance.ensureCapabilities(),
      ]);
      if (!mounted) return;
      final ws = results[0] as LedgerWorkspace;
      final proc = results[1] as ({List<ProcedureOption> options, List<ProcedureWorkOrder> workOrders});
      final cat = results[3] as ({List<String> units, List<String> types});
      setState(() {
        _ws = ws;
        _procedures = proc.options;
        _workOrders = proc.workOrders;
        _reservations = results[2] as List<LedgerReservation>;
        _units = cat.units;
        _types = cat.types;
        _warehouseCode = ws.warehouses.isNotEmpty ? ws.warehouses.first.code : '';
        final initCode = widget.initialMaterialCode;
        if (initCode != null && initCode.isNotEmpty && _lines.isEmpty) {
          final m = ws.materialByCode(initCode);
          _addLine(MovementLine(
            id: 'item-${DateTime.now().microsecondsSinceEpoch}-0',
            materialCode: initCode,
            materialName: m?.name ?? initCode,
            materialType: m?.type,
            unit: (m?.unit ?? '').isNotEmpty ? m!.unit : 'Cái',
            quantity: (widget.initialQuantity ?? 0) > 0 ? widget.initialQuantity! : 1,
            lineNote: widget.initialNote ?? '',
          ));
        }
        _loading = false;
        _initialSnapshot = _snapshot();
      });
      _refreshLiveStock();
      _loadLotsForLines();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = inventoryErrorMessage(e);
      });
    }
  }

  String _snapshot() => [
        _kind.name,
        _warehouseCode,
        _toWarehouseCode,
        _issueTargetType.name,
        _issueTargetName.text,
        _supplierName.text,
        _supplierAddress.text,
        _invoiceNumber.text,
        _targetAssetCode,
        _procedureId,
        _note.text,
        _file?.name ?? '',
        ..._lines.map((l) =>
            '${l.materialCode}|${l.quantity}|${l.unitCost}|${l.lineNote}|${l.serialNumbers.join(",")}|${l.lotAllocations.length}|${l.receiptLot?.lotNumber}'),
      ].join('§');

  bool get _dirty => !_loading && _snapshot() != _initialSnapshot;

  // ---- Tồn thực của kho phiếu (web `liveStock`) ----
  Future<void> _refreshLiveStock() async {
    if (!_outbound || _warehouseCode.isEmpty) {
      setState(() => _live = null);
      return;
    }
    final code = _warehouseCode;
    final req = ++_liveRequest;
    setState(() => _live = _LiveStock(code, 'loading'));
    try {
      final levels = await _repo.loadStockLevels(code, {for (final m in _ws.materials) m.id: m.code});
      if (!mounted || req != _liveRequest) return;
      setState(() => _live = _LiveStock(code, 'ready', levels));
    } catch (_) {
      if (!mounted || req != _liveRequest) return;
      setState(() => _live = _LiveStock(code, 'error'));
    }
  }

  Future<void> _loadLotsForLines() async {
    final codes = _lines.map((l) => l.materialCode).where((c) => c.isNotEmpty && !_lots.containsKey(c)).toSet();
    for (final code in codes) {
      List<LedgerLot> lots;
      try {
        lots = await _repo.loadLots(code);
      } catch (_) {
        lots = const [];
      }
      if (!mounted) return;
      setState(() => _lots[code] = lots);
    }
  }

  void _addLine(MovementLine line) {
    _lines.add(line);
    _qtyCtrls[line.id] = TextEditingController(text: LedgerFormat.number(line.quantity));
    _costCtrls[line.id] = TextEditingController(text: line.unitCost != null ? LedgerFormat.number(line.unitCost!) : '');
    _lineNoteCtrls[line.id] = TextEditingController(text: line.lineNote);
  }

  void _removeLine(int index) {
    final line = _lines.removeAt(index);
    _qtyCtrls.remove(line.id)?.dispose();
    _costCtrls.remove(line.id)?.dispose();
    _lineNoteCtrls.remove(line.id)?.dispose();
    setState(() {});
  }

  void _setKind(MovementKind k) {
    if (k == _kind) return;
    setState(() => _kind = k);
    _refreshLiveStock();
  }

  /// Một phiếu một kho: đổi kho thì mọi dòng đổi theo; xuất/chuyển thì xoá lô và sê-ri của kho cũ.
  void _changeWarehouse(String code) {
    if (code == _warehouseCode) return;
    var cleared = 0;
    if (_outbound) {
      for (final l in _lines) {
        if (l.lotAllocations.isNotEmpty || l.serialNumbers.isNotEmpty) cleared++;
        l.lotAllocations = [];
        l.serialNumbers = [];
      }
    }
    setState(() {
      _warehouseCode = code;
      if (_toWarehouseCode == code) _toWarehouseCode = '';
      _warehouseNotice = _lines.isEmpty
          ? null
          : 'inventory.ledger.form_wh_moved'.tr(args: {'n': _lines.length, 'code': code}) +
              (cleared > 0 ? 'inventory.ledger.form_wh_cleared'.tr(args: {'n': cleared}) : '');
    });
    _refreshLiveStock();
  }

  void _selectMaterial(LedgerMaterial m) {
    final idx = _lines.indexWhere((l) => l.materialCode == m.code);
    setState(() {
      if (idx >= 0) {
        _lines[idx].quantity += 1;
        _qtyCtrls[_lines[idx].id]?.text = LedgerFormat.number(_lines[idx].quantity);
      } else {
        _addLine(MovementLine(
          id: 'item-${DateTime.now().microsecondsSinceEpoch}',
          materialCode: m.code,
          materialName: m.name,
          materialType: m.type,
          unit: m.unit.isNotEmpty ? m.unit : 'Cái',
        ));
      }
    });
    _loadLotsForLines();
  }

  Future<void> _openNewMaterial() async {
    final draft = await MovementNewMaterialSheet.show(context, units: _units, types: _types);
    if (draft == null || !mounted) return;
    setState(() => _addLine(MovementLine(
          id: 'item-${DateTime.now().microsecondsSinceEpoch}-new',
          materialCode: draft.code,
          materialName: draft.name,
          materialType: draft.type,
          unit: draft.unit,
          lineNote: 'inventory.ledger.form_new_material_note'.tr(),
          newMaterial: draft,
        )));
  }

  /// Web `handleImportItems`: thêm các dòng nạp từ Excel (1 kho - 1 phiếu, kho của phiếu).
  Future<void> _openExcelImport() async {
    final imported = await StockImportSheet.show(
      context,
      movementKind: _kind,
      defaultWarehouseCode: _warehouseCode,
      isSingleWarehouseOnly: true,
    );
    if (imported == null || !mounted) return;
    setState(() {
      for (final line in imported) {
        _addLine(line);
      }
    });
    _loadLotsForLines();
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (!mounted) return;
      setState(() {
        _file = file;
        _fileSize = size ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _openSerials(MovementLine line) async {
    Future<List<String>>? candidates;
    if (_outbound) {
      final sourceId = _ws.warehouseByCode(_warehouseCode)?.id;
      candidates = _repo.loadSerials(line.materialCode).then((rows) => rows
          .where((r) =>
              r.stockState == 'IN_STOCK' && r.currentWarehouseId == sourceId && (r.qualityStatus ?? 'PASSED') == 'PASSED')
          .map((r) => r.serialNumber)
          .toList());
    }
    final serials = await MovementSerialSheet.show(context, line: line, outbound: _outbound, candidates: candidates);
    if (serials == null || !mounted) return;
    setState(() {
      line.serialNumbers = serials;
      if (serials.length > line.quantity) {
        line.quantity = serials.length.toDouble();
        _qtyCtrls[line.id]?.text = LedgerFormat.number(line.quantity);
      }
    });
  }

  Future<void> _openLots(MovementLine line) async {
    final res = await MovementLotSheet.show(context,
        line: line, kind: _kind, lots: _lots[line.materialCode] ?? const [], warehouseCode: _warehouseCode);
    if (res == null || !mounted) return;
    setState(() {
      line.lotAllocations = res.allocations;
      line.receiptLot = res.receiptLot;
    });
  }

  // ---- Kiểm tra (web submitBlockReason / permissionError) ----
  Map<String, ({double quantity, double available})>? get _liveLevels =>
      _live != null && _live!.status == 'ready' && _live!.code == _warehouseCode ? _live!.levels : null;

  String? _stockProblem() {
    final levels = _liveLevels;
    if (levels == null) return null;
    for (final l in _lines) {
      if (!(l.quantity > 0)) return 'inventory.ledger.stock_invalid_qty'.tr(args: {'code': l.materialCode});
      final level = levels[l.materialCode];
      if (level == null || level.quantity <= 0) {
        return 'inventory.ledger.stock_missing'.tr(args: {'code': l.materialCode, 'wh': _warehouseCode});
      }
      if (l.quantity > level.available) {
        final reserved = level.quantity - level.available;
        return 'inventory.ledger.stock_insufficient'.tr(args: {
          'code': l.materialCode,
          'avail': LedgerFormat.number(level.available),
          'wh': _warehouseCode,
          'reserved': reserved > 0 ? 'inventory.ledger.stock_reserved_note'.tr(args: {'n': LedgerFormat.number(reserved)}) : '',
          'need': LedgerFormat.number(l.quantity),
        });
      }
    }
    return null;
  }

  String? get _stockBlockReason {
    if (!_outbound || _lines.isEmpty) return null;
    final live = _live;
    if (live == null || live.code != _warehouseCode || live.status == 'loading') {
      return 'inventory.ledger.stock_checking'.tr(args: {'wh': _warehouseCode});
    }
    if (live.status == 'error') return 'inventory.ledger.stock_load_error'.tr(args: {'wh': _warehouseCode});
    return _stockProblem();
  }

  String? _permissionError(InventoryCapabilities caps) {
    if (!caps.canWriteTransactions) return 'inventory.ledger.form_no_permission'.tr();
    if (!caps.canManage &&
        ((_kind == MovementKind.issue && _issueTargetType == IssueTargetType.asset) ||
            _lines.any((l) => l.newMaterial != null || (_kind == MovementKind.receipt && l.serialNumbers.isNotEmpty)))) {
      return 'inventory.ledger.form_manage_required'.tr();
    }
    return null;
  }

  bool get _invalidSerial => _lines.any((l) =>
      movementTrackingMode(_ws.materialByCode(l.materialCode)) == 'SERIAL' && l.serialNumbers.length != l.quantity);

  bool get _invalidLot => _lines.any((l) {
        if (movementTrackingMode(_ws.materialByCode(l.materialCode)) != 'LOT') return false;
        if (_kind == MovementKind.receipt) return l.receiptLot == null || l.receiptLot!.lotNumber.isEmpty;
        return l.lotAllocations.fold<double>(0, (s, a) => s + a.quantity) > l.quantity;
      });

  String? _submitBlockReason(String? permissionError) {
    if (permissionError != null) return null;
    if (_warehouseCode.isEmpty) return 'inventory.ledger.form_block_wh'.tr();
    if (_kind == MovementKind.transfer && (_toWarehouseCode.isEmpty || _toWarehouseCode == _warehouseCode)) {
      return 'inventory.ledger.form_block_to_wh'.tr();
    }
    if (_note.text.trim().isEmpty) return 'inventory.ledger.form_block_note'.tr();
    final stock = _stockBlockReason;
    if (stock != null) return stock;
    if (_invalidLot) return 'inventory.ledger.form_block_lot'.tr();
    if (_invalidSerial) return 'inventory.ledger.form_block_serial'.tr();
    return null;
  }

  MovementCounterparty? _counterparty() {
    if (_kind == MovementKind.receipt) {
      final name = _supplierName.text.trim();
      if (name.isEmpty) return null;
      return MovementCounterparty(
        type: 'SUPPLIER',
        name: name,
        address: _supplierAddress.text.trim().isEmpty ? null : _supplierAddress.text.trim(),
        documentNumber: _invoiceNumber.text.trim().isEmpty ? null : _invoiceNumber.text.trim(),
      );
    }
    if (_kind != MovementKind.issue) return null;
    if (_issueTargetType == IssueTargetType.asset) {
      final code = _targetAssetCode.trim();
      return code.isEmpty ? null : MovementCounterparty(type: 'ASSET', name: code);
    }
    final name = _issueTargetName.text.trim();
    if (name.isEmpty) return null;
    const types = {
      IssueTargetType.department: 'DEPARTMENT',
      IssueTargetType.customer: 'CUSTOMER',
      IssueTargetType.project: 'PROJECT',
    };
    return MovementCounterparty(type: types[_issueTargetType]!, name: name);
  }

  String _outcomeMessage(MovementInput input, MovementOutcome o) {
    String combine(String posted) {
      final parts = <String>[];
      if (o.transactionCodes.isNotEmpty) {
        parts.add('inventory.ledger.outcome_posted'.tr(args: {'text': posted, 'codes': o.transactionCodes.join(', ')}));
      }
      if (o.pendingCodes.isNotEmpty) {
        parts.add('inventory.ledger.outcome_pending'
            .tr(args: {'n': o.pendingCodes.length, 'codes': o.pendingCodes.join(', ')}));
      }
      return '${parts.join('. ')}.';
    }

    final ref = [...o.transactionCodes, ...o.pendingCodes].join(', ');
    switch (input.kind) {
      case MovementKind.receipt:
        return combine('inventory.ledger.outcome_receipt'.tr(args: {'n': o.transactionCodes.length}) +
            (o.serialsAdded > 0 ? 'inventory.ledger.outcome_receipt_serials'.tr(args: {'n': o.serialsAdded}) : ''));
      case MovementKind.issue:
        if (input.targetAssetCode != null) {
          return 'inventory.ledger.outcome_install'
              .tr(args: {'n': input.items.length, 'asset': input.targetAssetCode, 'codes': ref});
        }
        return combine('inventory.ledger.outcome_issue'.tr(args: {'n': o.transactionCodes.length}));
      case MovementKind.transfer:
        return 'inventory.ledger.outcome_transfer'.tr(args: {'n': input.items.length, 'codes': ref});
    }
  }

  Future<void> _submit() async {
    final caps = InventoryScope.instance.capabilities.value;
    final perm = _permissionError(caps);
    if (_lines.isEmpty || _submitting || perm != null || _submitBlockReason(perm) != null) return;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final input = MovementInput(
      kind: _kind,
      warehouseCode: _warehouseCode,
      toWarehouseCode: _kind == MovementKind.transfer ? _toWarehouseCode : null,
      note: _note.text.trim(),
      procedureDefinitionId: _procedureId.isEmpty ? null : _procedureId,
      targetAssetCode:
          _kind == MovementKind.issue && _issueTargetType == IssueTargetType.asset && _targetAssetCode.isNotEmpty
              ? _targetAssetCode
              : null,
      supplierName: _kind == MovementKind.receipt ? opt(_supplierName) : null,
      supplierAddress: _kind == MovementKind.receipt ? opt(_supplierAddress) : null,
      invoiceNumber: _kind == MovementKind.receipt ? opt(_invoiceNumber) : null,
      counterparty: _counterparty(),
      items: List.of(_lines),
    );
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final outcome = await _repo.runMovement(input, canManage: caps.canManage);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(_outcomeMessage(input, outcome)),
        backgroundColor: const Color(0xFF15803D),
      ));
      if (outcome.workOrderCode != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('inventory.ledger.outcome_work_order'.tr(args: {'code': outcome.workOrderCode})),
        ));
      } else if (outcome.workOrderError != null) {
        messenger.showSnackBar(SnackBar(
          content: Text(outcome.workOrderError!.isNotEmpty
              ? 'inventory.ledger.outcome_work_order_error_msg'.tr(args: {'msg': outcome.workOrderError})
              : 'inventory.ledger.outcome_work_order_error'.tr()),
          backgroundColor: Colors.red.shade700,
        ));
      }
      await widget.onSubmitted?.call();
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is MovementPermissionException
            ? 'inventory.ledger.form_manage_required_nowrite'.tr()
            : inventoryErrorMessage(e, 'inventory.ledger.form_submit_error');
      });
    }
  }

  Future<void> _close() async {
    if (_submitting) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('inventory.ledger.discard_title'.tr()),
        content: Text('inventory.ledger.discard_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('inventory.ledger.keep_editing'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('inventory.ledger.discard'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  // ---- Giao diện ----
  String get _title =>
      widget.title ??
      switch (_kind) {
        MovementKind.receipt => 'inventory.ledger.form_title_receipt'.tr(),
        MovementKind.transfer => 'inventory.ledger.form_title_transfer'.tr(),
        MovementKind.issue => 'inventory.ledger.form_title_issue'.tr(),
      };

  String get _description =>
      widget.description ??
      switch (_kind) {
        MovementKind.receipt => 'inventory.ledger.form_desc_receipt'.tr(),
        MovementKind.transfer => 'inventory.ledger.form_desc_transfer'.tr(),
        MovementKind.issue => 'inventory.ledger.form_desc_issue'.tr(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.slate900,
          elevation: 0.5,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text(_description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500, fontWeight: FontWeight.w400)),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _errorState()
                : ValueListenableBuilder<InventoryCapabilities>(
                    valueListenable: InventoryScope.instance.capabilities,
                    builder: (context, caps, _) => _form(caps),
                  ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text('inventory.ledger.retry'.tr())),
          ]),
        ),
      );

  Widget _form(InventoryCapabilities caps) {
    final perm = _permissionError(caps);
    final block = _submitBlockReason(perm);
    final totalQty = _lines.fold<double>(0, (s, l) => s + l.quantity);
    final canSubmit = perm == null && block == null && _lines.isNotEmpty && !_submitting;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _kindSwitch(),
            const SizedBox(height: 12),
            _headerBlock(),
            const SizedBox(height: 14),
            _linesBlock(totalQty),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200)), color: Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (perm != null || block != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(children: [
                Expanded(
                    child: Text(perm ?? block!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)))),
                if (perm == null && _live?.status == 'error')
                  TextButton(onPressed: _refreshLiveStock, child: Text('inventory.ledger.retry'.tr())),
              ]),
            ),
          if (_submitError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_submitError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
            ),
          Text(
            'inventory.ledger.form_footer_summary'.tr(args: {'n': _lines.length, 'qty': LedgerFormat.number(totalQty)}),
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _submitting ? null : _close, child: Text('inventory.ledger.cancel'.tr()))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: movementPrimaryStyle(),
                onPressed: canSubmit ? _submit : null,
                child: Text(
                  _submitting
                      ? 'inventory.ledger.form_submitting'.tr()
                      : 'inventory.ledger.form_submit'.tr(args: {'kind': _kindLabel(_kind), 'n': _lines.length}),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  String _kindLabel(MovementKind k) => switch (k) {
        MovementKind.receipt => 'inventory.ledger.kind_label_receipt'.tr(),
        MovementKind.issue => 'inventory.ledger.kind_label_issue'.tr(),
        MovementKind.transfer => 'inventory.ledger.kind_label_transfer'.tr(),
      };

  Widget _kindSwitch() {
    Widget tab(MovementKind k, String label, Color fg) {
      final sel = _kind == k;
      return Expanded(
        child: InkWell(
          onTap: () => _setKind(k),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)] : null,
            ),
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? fg : AppColors.slate500)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        tab(MovementKind.receipt, 'inventory.ledger.kind_label_receipt'.tr(), const Color(0xFF166534)),
        tab(MovementKind.issue, 'inventory.ledger.kind_label_issue'.tr(), const Color(0xFF1D4ED8)),
        tab(MovementKind.transfer, 'inventory.ledger.form_tab_transfer'.tr(), const Color(0xFF7C2D12)),
      ]),
    );
  }

  Widget _headerBlock() {
    final whLabel = switch (_kind) {
      MovementKind.transfer => 'inventory.ledger.form_wh_source'.tr(),
      MovementKind.receipt => 'inventory.ledger.form_wh_receipt'.tr(),
      MovementKind.issue => 'inventory.ledger.form_wh_issue'.tr(),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        movementLabel(whLabel, required: true),
        SearchableDropdownField<LedgerWarehouse>(
          value: _ws.warehouseByCode(_warehouseCode),
          items: _ws.warehouses,
          hintText: 'inventory.ledger.form_wh_placeholder'.tr(),
          itemLabel: (w) => w.name,
          itemSubtitle: (w) => w.code,
          showClear: false,
          onChanged: (w) => _changeWarehouse(w.code),
        ),
        const SizedBox(height: 12),
        if (_kind == MovementKind.transfer) ...[
          movementLabel('inventory.ledger.form_wh_target'.tr(), required: true),
          SearchableDropdownField<LedgerWarehouse>(
            value: _ws.warehouseByCode(_toWarehouseCode),
            items: _ws.warehouses.where((w) => w.code != _warehouseCode).toList(),
            hintText: 'inventory.ledger.form_wh_target_placeholder'.tr(),
            itemLabel: (w) => w.name,
            itemSubtitle: (w) => w.code,
            showClear: false,
            onChanged: (w) => setState(() => _toWarehouseCode = w.code),
          ),
        ] else if (_kind == MovementKind.issue) ...[
          movementLabel('inventory.ledger.form_issue_target'.tr()),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: IssueTargetType.values.map((t) {
              final sel = _issueTargetType == t;
              return ChoiceChip(
                label: Text(_issueTargetLabel(t), style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (_) => setState(() => _issueTargetType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (_issueTargetType == IssueTargetType.asset)
            SearchableDropdownField<LedgerAsset>(
              value: _ws.assets.where((a) => a.code == _targetAssetCode).firstOrNull,
              items: _ws.assets,
              hintText: 'inventory.ledger.form_asset_placeholder'.tr(),
              itemLabel: (a) => a.name,
              itemSubtitle: (a) => a.code,
              onChanged: (a) => setState(() => _targetAssetCode = a.code),
              onClear: () => setState(() => _targetAssetCode = ''),
            )
          else
            TextField(
              controller: _issueTargetName,
              maxLength: 255,
              onChanged: (_) => setState(() {}),
              decoration: movementInputDecoration(
                hint: switch (_issueTargetType) {
                  IssueTargetType.department => 'inventory.ledger.form_target_department'.tr(),
                  IssueTargetType.customer => 'inventory.ledger.form_target_customer'.tr(),
                  _ => 'inventory.ledger.form_target_project'.tr(),
                },
              ).copyWith(counterText: ''),
            ),
        ] else ...[
          movementLabel('inventory.ledger.form_procedure'.tr()),
          if (_procedures.isEmpty)
            InputDecorator(
              decoration: movementInputDecoration(),
              child: Text('inventory.ledger.form_procedure_none'.tr(),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate400)),
            )
          else
            SearchableDropdownField<ProcedureOption>(
              value: _procedures.where((p) => p.id == _procedureId).firstOrNull,
              items: _procedures,
              hintText: 'inventory.ledger.form_procedure_placeholder'.tr(),
              itemLabel: (p) => p.name,
              itemSubtitle: (p) => p.code,
              onChanged: (p) => setState(() => _procedureId = p.id),
              onClear: () => setState(() => _procedureId = ''),
            ),
        ],
        if (_kind == MovementKind.receipt) ...[
          const SizedBox(height: 12),
          movementLabel('inventory.ledger.form_supplier'.tr()),
          TextField(
              controller: _supplierName,
              maxLength: 255,
              onChanged: (_) => setState(() {}),
              decoration: movementInputDecoration(hint: 'inventory.ledger.form_supplier_placeholder'.tr())
                  .copyWith(counterText: '')),
          const SizedBox(height: 10),
          movementLabel('inventory.ledger.form_invoice'.tr()),
          TextField(
              controller: _invoiceNumber,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration:
                  movementInputDecoration(hint: 'inventory.ledger.form_invoice_placeholder'.tr()).copyWith(counterText: '')),
          const SizedBox(height: 10),
          movementLabel('inventory.ledger.form_supplier_address'.tr()),
          TextField(
              controller: _supplierAddress,
              onChanged: (_) => setState(() {}),
              decoration: movementInputDecoration(hint: 'inventory.ledger.form_supplier_address_placeholder'.tr())),
        ],
        const SizedBox(height: 12),
        movementLabel('inventory.ledger.form_note'.tr(), required: true),
        TextField(
          controller: _note,
          onChanged: (_) => setState(() {}),
          decoration: movementInputDecoration(hint: 'inventory.ledger.form_note_placeholder'.tr()),
        ),
        const SizedBox(height: 12),
        movementLabel('inventory.ledger.form_attachment'.tr()),
        InkWell(
          onTap: _file == null ? _pickFile : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.slate300),
            ),
            child: _file != null
                ? Row(children: [
                    const Icon(Icons.attach_file, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${_file!.name} (${(_fileSize / 1024).round()} KB)',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'inventory.ledger.form_attachment_remove'.tr(),
                      onPressed: () => setState(() => _file = null),
                    ),
                  ])
                : Column(children: [
                    const Icon(Icons.upload_outlined, size: 18, color: AppColors.slate500),
                    const SizedBox(height: 4),
                    Text('inventory.ledger.form_attachment_pick'.tr(),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    Text('inventory.ledger.form_attachment_hint'.tr(),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate400)),
                  ]),
          ),
        ),
      ]),
    );
  }

  String _issueTargetLabel(IssueTargetType t) => switch (t) {
        IssueTargetType.department => 'inventory.ledger.target_department'.tr(),
        IssueTargetType.asset => 'inventory.ledger.target_asset'.tr(),
        IssueTargetType.customer => 'inventory.ledger.target_customer'.tr(),
        IssueTargetType.project => 'inventory.ledger.target_project'.tr(),
      };

  List<({String name, double reserved, String order})> get _reservedAlerts {
    if (!_outbound || _reservations.isEmpty) return const [];
    final codes = _lines.map((l) => l.materialCode).toSet();
    final out = <({String name, double reserved, String order})>[];
    for (final r in _reservations) {
      if (!const ['PENDING', 'RESERVED', 'PARTIALLY_ISSUED'].contains(r.status)) continue;
      for (final it in r.items) {
        final m = _ws.materialById(it.materialId);
        if (m != null && codes.contains(m.code)) {
          final outstanding = it.reserved - it.issued;
          if (outstanding > 0) {
            final wo = _workOrders.where((w) => w.id == r.referenceId).firstOrNull;
            out.add((name: m.name, reserved: outstanding, order: wo?.code ?? r.reservationCode));
          }
        }
      }
    }
    return out;
  }

  Widget _linesBlock(double totalQty) {
    final alerts = _reservedAlerts;
    final excluded = _lines.map((l) => l.materialCode).toSet();
    final options = _ws.materials.where((m) => m.isActive && !excluded.contains(m.code)).toList();
    final totalCost = _lines.fold<double>(0, (s, l) => s + l.quantity * (l.unitCost ?? 0));
    final block = _stockBlockReason;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text('inventory.ledger.form_lines_title'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate900)),
        ),
        Text('inventory.ledger.form_lines_count'.tr(args: {'n': _lines.length}),
            style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      SearchableDropdownField<LedgerMaterial>(
        value: null,
        items: options,
        hintText: 'inventory.ledger.form_material_search'.tr(),
        itemLabel: (m) => m.name,
        itemSubtitle: (m) => m.code,
        showClear: false,
        onChanged: _selectMaterial,
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        OutlinedButton.icon(
          onPressed: _openExcelImport,
          icon: const Icon(Icons.table_view_outlined, size: 16),
          label: Text('inventory.stock_import.open_direct'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF15803D),
            backgroundColor: const Color(0xFFF0FDF4),
            side: const BorderSide(color: Color(0xFFBBF7D0)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openNewMaterial,
          icon: const Icon(Icons.add, size: 16),
          label: Text('inventory.ledger.form_new_material'.tr()),
        ),
      ]),
      if (alerts.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Text(
            'inventory.ledger.form_reserved_alert'.tr(args: {
              'n': alerts.length,
              'list': alerts
                  .map((a) => 'inventory.ledger.form_reserved_item'
                      .tr(args: {'name': a.name, 'n': LedgerFormat.number(a.reserved)}))
                  .join(', '),
            }),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
          ),
        ),
      if (_warehouseNotice != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_warehouseNotice!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1D4ED8))),
        ),
      const SizedBox(height: 10),
      if (_lines.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.slate200)),
          child: Column(children: [
            const Icon(Icons.layers_outlined, size: 28, color: AppColors.slate400),
            const SizedBox(height: 6),
            Text('inventory.ledger.form_lines_empty'.tr(), style: const TextStyle(fontSize: 13.5, color: AppColors.slate500)),
            const SizedBox(height: 2),
            Text('inventory.ledger.form_lines_empty_hint'.tr(),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.slate400)),
          ]),
        )
      else ...[
        ...List.generate(_lines.length, (i) => _lineCard(i, _lines[i])),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('inventory.ledger.form_sum_types'.tr(args: {'n': _lines.length}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
            Text('inventory.ledger.form_sum_qty'.tr(args: {'n': LedgerFormat.number(totalQty)}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
            if (_kind == MovementKind.receipt)
              Text('inventory.ledger.form_sum_value'.tr(args: {'n': LedgerFormat.number(totalCost)}),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (block != null)
              Text(block,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _live == null || _live!.status == 'loading' ? const Color(0xFFB45309) : Colors.red.shade600))
            else if (_invalidLot)
              Text('inventory.ledger.form_lot_warning'.tr(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309)))
            else if (_invalidSerial)
              Text('inventory.ledger.form_serial_warning'.tr(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309)))
            else
              Text('inventory.ledger.form_valid'.tr(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
          ]),
        ),
      ],
    ]);
  }

  ({bool overdraw, String badgeType, String badgeLabel}) _analysis(MovementLine l) {
    final levels = _liveLevels;
    double onHand;
    double avail;
    if (levels != null) {
      final lv = levels[l.materialCode];
      onHand = lv?.quantity ?? 0;
      avail = lv?.available ?? onHand;
    } else {
      final s = _ws.stock.where((s) => s.materialCode == l.materialCode && s.warehouseCode == _warehouseCode).firstOrNull;
      onHand = s?.quantity ?? 0;
      avail = s?.available ?? onHand;
    }
    final totalAll =
        _ws.stock.where((s) => s.materialCode == l.materialCode).fold<double>(0, (sum, s) => sum + s.quantity);
    final overdraw = _outbound && (l.quantity > avail || onHand == 0);
    if (!_outbound) {
      return (overdraw: false, badgeType: 'ok', badgeLabel: 'inventory.ledger.badge_current'.tr(args: {'n': LedgerFormat.number(totalAll)}));
    }
    if (onHand >= l.quantity && l.quantity > 0) {
      return (overdraw: overdraw, badgeType: 'ok', badgeLabel: 'inventory.ledger.badge_ok'.tr(args: {'n': LedgerFormat.number(onHand)}));
    }
    if (totalAll >= l.quantity && l.quantity > 0) {
      return (overdraw: overdraw, badgeType: 'shared', badgeLabel: 'inventory.ledger.badge_shared'.tr(args: {'n': LedgerFormat.number(totalAll)}));
    }
    return (overdraw: overdraw, badgeType: 'empty', badgeLabel: 'inventory.ledger.badge_empty'.tr(args: {'n': LedgerFormat.number(totalAll)}));
  }

  double _parseVn(String v) => double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Widget _lineCard(int index, MovementLine l) {
    final a = _analysis(l);
    final material = _ws.materialByCode(l.materialCode);
    final mode = movementTrackingMode(material);
    final decimals = LedgerFormat.unitAllowsDecimals(l.unit);
    final type = l.materialType ?? material?.type ?? '—';
    final (bg, fg) = switch (a.badgeType) {
      'ok' => (const Color(0xFFECFDF5), const Color(0xFF059669)),
      'shared' => (const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      _ => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
    };
    final lotCount = l.lotAllocations.isNotEmpty ? l.lotAllocations.length : (l.receiptLot != null ? 1 : 0);
    final allocated = l.lotAllocations.fold<double>(0, (s, x) => s + x.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.overdraw ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: a.overdraw ? const Color(0xFFFECACA) : AppColors.slate200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${index + 1}. ', style: const TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w600)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(l.materialCode, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                if (l.newMaterial != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                    child: Text('inventory.ledger.form_new_tag'.tr(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                  ),
              ]),
              Text(l.materialName, style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
            tooltip: 'inventory.ledger.form_remove_line'.tr(),
            onPressed: () => _removeLine(index),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(4)),
            child: Text(type, style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withValues(alpha: 0.3))),
            child: Text(a.badgeLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              movementLabel('inventory.ledger.form_qty'.tr(args: {'unit': l.unit})),
              TextField(
                controller: _qtyCtrls[l.id],
                textAlign: TextAlign.right,
                keyboardType: TextInputType.numberWithOptions(decimal: decimals),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9.,]' : r'[0-9.]'))],
                decoration: movementInputDecoration(error: a.overdraw),
                onChanged: (v) => setState(() => l.quantity = _parseVn(v) < 0 ? 0 : _parseVn(v)),
              ),
            ]),
          ),
          if (_kind == MovementKind.receipt) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                movementLabel('inventory.ledger.form_unit_cost'.tr()),
                TextField(
                  controller: _costCtrls[l.id],
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: movementInputDecoration(hint: '0'),
                  onChanged: (v) => setState(() => l.unitCost = v.trim().isEmpty ? null : _parseVn(v)),
                ),
              ]),
            ),
          ],
        ]),
        if (_kind == MovementKind.receipt)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'inventory.ledger.form_line_total'.tr(args: {'n': LedgerFormat.number(l.quantity * (l.unitCost ?? 0))}),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Text('inventory.ledger.form_tracking'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(width: 8),
          if (mode == 'LOT')
            OutlinedButton.icon(
              onPressed: () => _openLots(l),
              icon: const Icon(Icons.layers_outlined, size: 14),
              label: Text(lotCount > 0
                  ? 'inventory.ledger.form_lot_count'.tr(args: {'n': lotCount})
                  : 'inventory.ledger.form_lot'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: lotCount > 0 ? const Color(0xFF6D28D9) : AppColors.slate500,
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else if (mode == 'SERIAL')
            OutlinedButton.icon(
              onPressed: () => _openSerials(l),
              icon: const Icon(Icons.qr_code_2, size: 14),
              label: Text(l.serialNumbers.isNotEmpty
                  ? 'inventory.ledger.form_serial_count'.tr(args: {'n': l.serialNumbers.length})
                  : 'inventory.ledger.form_serial'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: l.serialNumbers.isNotEmpty ? const Color(0xFF1D4ED8) : AppColors.slate500,
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else
            Text('inventory.ledger.form_no_tracking'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
        ]),
        if (mode == 'LOT' && _outbound && lotCount > 0 && allocated != l.quantity)
          Text('inventory.ledger.form_lot_partial'
                  .tr(args: {'a': LedgerFormat.number(allocated), 'q': LedgerFormat.number(l.quantity)}),
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
        const SizedBox(height: 8),
        TextField(
          controller: _lineNoteCtrls[l.id],
          onChanged: (v) => setState(() => l.lineNote = v),
          style: const TextStyle(fontSize: 13),
          decoration: movementInputDecoration(hint: 'inventory.ledger.form_line_note'.tr()),
        ),
      ]),
    );
  }
}
