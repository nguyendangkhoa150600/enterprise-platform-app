import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/warranty/warranty_repository.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../../domain/warranty/crm_warranty_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../common/crm_warehouse_select.dart';
import '../utils/crm_scope.dart';
import 'crm_warranty_labels.dart';

/// Phiếu tiếp nhận (web `IntakeDialog`): nguyên nhân bắt buộc, mỗi dòng một serial cùng một khách. Trả id yêu cầu
/// vừa tạo.
class CrmWarrantyIntakeSheet extends StatefulWidget {
  final List<String> initialSerials;
  const CrmWarrantyIntakeSheet({super.key, this.initialSerials = const []});

  @override
  State<CrmWarrantyIntakeSheet> createState() => _CrmWarrantyIntakeSheetState();
}

class _CrmWarrantyIntakeSheetState extends State<CrmWarrantyIntakeSheet> {
  late final TextEditingController _serials = TextEditingController(text: widget.initialSerials.join('\n'));
  final TextEditingController _description = TextEditingController();
  String? _cause;
  String? _assignee;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _serials.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final serials = _serials.text.split(RegExp(r'[\n,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (_cause == null) {
      setState(() => _error = 'crm.warranty.error.cause_required'.tr());
      return;
    }
    if (serials.isEmpty) {
      setState(() => _error = 'crm.warranty.error.serial_required'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final description = _description.text.trim();
      final created = await CrmWarrantyRepository.instance.createCase(
        cause: _cause!,
        description: description.isEmpty ? null : description,
        assigneeUserId: _assignee,
        serials: serials,
      );
      if (!mounted) return;
      showCrmSnack(
        context,
        (created.summary.chargeable ? 'crm.warranty.toast.created_chargeable' : 'crm.warranty.toast.created').tr(
          args: {'code': created.code},
        ),
      );
      Navigator.of(context).pop(created.id);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.warranty.error.create');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.warranty.intake_title'.tr(),
      subtitle: 'crm.warranty.intake_subtitle'.tr(),
      submitLabel: 'crm.warranty.intake_submit'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.warranty.field.cause'.tr(),
          required: true,
          child: CrmSelectField(
            value: _cause,
            options: crmWarrantyOptions(kCrmWarrantyCauses, crmWarrantyCauseLabel),
            placeholder: 'crm.warranty.field.cause_placeholder'.tr(),
            onChanged: (s) => setState(() => _cause = s.value),
          ),
        ),
        CrmField(
          label: 'crm.warranty.field.assignee'.tr(),
          hint: 'crm.warranty.field.assignee_hint'.tr(),
          child: CrmPersonSelectField(
            value: _assignee,
            placeholder: 'crm.warranty.field.assignee_placeholder'.tr(),
            clearable: true,
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ),
        CrmField(
          label: 'crm.warranty.field.serials'.tr(),
          required: true,
          hint: 'crm.warranty.field.serials_hint'.tr(),
          child: TextField(
            controller: _serials,
            minLines: 4,
            maxLines: 8,
            maxLength: 5000,
            decoration: crmInputDecoration(),
          ),
        ),
        CrmField(
          label: 'crm.warranty.field.description'.tr(),
          child: TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            maxLength: 4000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

/// Kho bảo hành (web `WarrantySettingsDialog`, quản trị bán hàng): kho cách ly, kho hàng lỗi, kho nhập lại hàng Đạt.
class CrmWarrantySettingsSheet extends StatefulWidget {
  const CrmWarrantySettingsSheet({super.key});

  @override
  State<CrmWarrantySettingsSheet> createState() => _CrmWarrantySettingsSheetState();
}

class _CrmWarrantySettingsSheetState extends State<CrmWarrantySettingsSheet> {
  String? _quarantine;
  String? _defect;
  String? _restock;
  List<CrmWarehouseOption> _warehouses = const [];
  bool _loaded = false;
  String? _warehouseError;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = CrmWarrantyRepository.instance;
    CrmWarrantySettings settings;
    try {
      settings = await repo.loadSettings();
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _error = crmErrorMessage(e, 'crm.warranty.error.settings_load');
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _quarantine = settings.quarantineWarehouseCode;
      _defect = settings.defectWarehouseCode;
      _restock = settings.restockWarehouseCode;
      _loaded = true;
    });
    final current = [
      settings.quarantineWarehouseCode,
      settings.defectWarehouseCode,
      settings.restockWarehouseCode,
    ].whereType<String>().where((c) => c.isNotEmpty).toList();
    try {
      final rows = await repo.loadWarehouses(current);
      if (!mounted) return;
      setState(() => _warehouses = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _warehouseError = crmErrorMessage(e, 'crm.warranty.error.warehouses'));
    }
  }

  Future<void> _save() async {
    if ((_quarantine ?? '').isEmpty || (_defect ?? '').isEmpty) {
      setState(() => _error = 'crm.warranty.error.warehouses_required'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CrmWarrantyRepository.instance.saveSettings(quarantine: _quarantine!, defect: _defect!, restock: _restock);
      if (!mounted) return;
      showCrmSnack(context, 'crm.warranty.toast.settings_saved'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.warranty.error.settings_save');
      });
    }
  }

  Widget _select(String? value, ValueChanged<String?> onChanged, String placeholder, {bool clearable = false}) =>
      CrmSelectField(
        value: value,
        options: crmWarehouseOptions(_warehouses, value),
        placeholder: placeholder,
        searchHint: 'crm.warranty.warehouse_search'.tr(),
        emptyText: 'crm.warranty.warehouse_empty'.tr(),
        clearable: clearable,
        onChanged: (s) => onChanged(s.value),
      );

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.warranty.settings_title'.tr(),
      subtitle: 'crm.warranty.settings_subtitle'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _loaded ? _save : null,
      children: [
        if (!_loaded) const CrmStateView(loading: true),
        if (_warehouseError != null) CrmBanner(message: _warehouseError!),
        if (_loaded) ...[
          CrmField(
            label: 'crm.warranty.field.quarantine'.tr(),
            required: true,
            hint: 'crm.warranty.field.quarantine_hint'.tr(),
            child: _select(
              _quarantine,
              (v) => setState(() => _quarantine = v),
              'crm.warranty.field.quarantine_ph'.tr(),
            ),
          ),
          CrmField(
            label: 'crm.warranty.field.defect'.tr(),
            required: true,
            hint: 'crm.warranty.field.defect_hint'.tr(),
            child: _select(_defect, (v) => setState(() => _defect = v), 'crm.warranty.field.defect_ph'.tr()),
          ),
          CrmField(
            label: 'crm.warranty.field.restock'.tr(),
            hint: 'crm.warranty.field.restock_hint'.tr(),
            child: _select(
              _restock,
              (v) => setState(() => _restock = v),
              'crm.warranty.field.restock_ph'.tr(),
              clearable: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// Kết quả kiểm định (web `InspectDialog`). [onSave] trả true khi xong (đóng sheet).
class CrmWarrantyInspectSheet extends StatefulWidget {
  final CrmWarrantyCaseLine line;
  final Future<bool> Function(String result, String? note) onSave;
  const CrmWarrantyInspectSheet({super.key, required this.line, required this.onSave});

  @override
  State<CrmWarrantyInspectSheet> createState() => _CrmWarrantyInspectSheetState();
}

class _CrmWarrantyInspectSheetState extends State<CrmWarrantyInspectSheet> {
  late String? _result = widget.line.inspectionResult;
  late final TextEditingController _note = TextEditingController(text: widget.line.inspectionNote ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_result == null) {
      setState(() => _error = 'crm.warranty.error.inspection_required'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _note.text.trim();
    final ok = await widget.onSave(_result!, note.isEmpty ? null : note);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrmFormSheet(
      title: 'crm.warranty.inspect_title'.tr(),
      subtitle: widget.line.serial ?? widget.line.materialCode,
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.warranty.field.result'.tr(),
          required: true,
          child: CrmSelectField(
            value: _result,
            options: crmWarrantyOptions(kCrmWarrantyInspectionResults, crmWarrantyInspectionLabel),
            placeholder: 'crm.warranty.field.result_placeholder'.tr(),
            onChanged: (s) => setState(() => _result = s.value),
          ),
        ),
        CrmField(
          label: 'crm.warranty.field.note'.tr(),
          child: TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

/// Hướng xử lý (web `ResolveDialog`). [onSave] trả true khi xong.
class CrmWarrantyResolveSheet extends StatefulWidget {
  final CrmWarrantyCaseLine line;
  final Future<bool> Function(String disposition, String remedy, String? warehouse, String? note) onSave;
  const CrmWarrantyResolveSheet({super.key, required this.line, required this.onSave});

  @override
  State<CrmWarrantyResolveSheet> createState() => _CrmWarrantyResolveSheetState();
}

class _CrmWarrantyResolveSheetState extends State<CrmWarrantyResolveSheet> {
  late final List<String> _allowed = crmWarrantyDispositionsFor(widget.line.inspectionResult);
  late String? _disposition = _allowed.length == 1 ? _allowed.first : null;
  String _remedy = 'NONE';
  late final TextEditingController _warehouse = TextEditingController(text: widget.line.deliveryWarehouseCode ?? '');
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _warehouse.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_disposition == null) {
      setState(() => _error = 'crm.warranty.error.disposition_required'.tr());
      return;
    }
    final warehouse = _warehouse.text.trim();
    if (_remedy == 'REPLACE' && warehouse.isEmpty) {
      setState(() => _error = 'crm.warranty.error.replacement_warehouse'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _note.text.trim();
    final ok = await widget.onSave(
      _disposition!,
      _remedy,
      _remedy == 'REPLACE' ? warehouse : null,
      note.isEmpty ? null : note,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final remedies = kCrmWarrantyRemedies
        .where((v) => line.orderLineId != null || (v != 'REFUND' && v != 'CREDIT'))
        .toList();
    final inspection = line.inspectionResult == null ? '' : crmWarrantyInspectionLabel(line.inspectionResult!);
    return CrmFormSheet(
      title: 'crm.warranty.resolve_title'.tr(),
      subtitle: 'crm.warranty.resolve_subtitle'.tr(
        args: {'item': line.serial ?? line.materialCode, 'result': inspection},
      ),
      submitLabel: 'crm.warranty.resolve_submit'.tr(),
      submitting: _saving,
      error: _error,
      onSubmit: _save,
      children: [
        CrmField(
          label: 'crm.warranty.field.disposition'.tr(),
          required: true,
          child: CrmSelectField(
            value: _disposition,
            options: crmWarrantyOptions(_allowed, crmWarrantyDispositionLabel),
            placeholder: 'crm.warranty.field.disposition_placeholder'.tr(),
            onChanged: (s) => setState(() => _disposition = s.value),
          ),
        ),
        CrmField(
          label: 'crm.warranty.field.remedy'.tr(),
          hint: line.orderLineId != null ? 'crm.warranty.field.remedy_hint'.tr() : null,
          child: CrmSelectField(
            value: _remedy,
            options: crmWarrantyOptions(remedies, crmWarrantyRemedyLabel),
            onChanged: (s) => setState(() => _remedy = s.value ?? 'NONE'),
          ),
        ),
        if (_remedy == 'REPLACE')
          CrmField(
            label: 'crm.warranty.field.replacement_warehouse'.tr(),
            required: true,
            hint: 'crm.warranty.field.replacement_warehouse_hint'.tr(),
            child: TextField(
              controller: _warehouse,
              maxLength: 50,
              textCapitalization: TextCapitalization.characters,
              decoration: crmInputDecoration(),
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (upper != v) {
                  _warehouse.value = _warehouse.value.copyWith(text: upper);
                }
              },
            ),
          ),
        CrmField(
          label: 'crm.warranty.field.note'.tr(),
          child: TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: crmInputDecoration(),
          ),
        ),
      ],
    );
  }
}

/// Lịch sử serial (web `SerialHistoryDialog`): bước kho từ Kho và các yêu cầu bảo hành có serial.
class CrmSerialHistorySheet extends StatefulWidget {
  final String serial;
  const CrmSerialHistorySheet({super.key, required this.serial});

  @override
  State<CrmSerialHistorySheet> createState() => _CrmSerialHistorySheetState();
}

class _CrmSerialHistorySheetState extends State<CrmSerialHistorySheet> {
  CrmWarrantySerialHistory? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await CrmWarrantyRepository.instance.serialHistory(widget.serial);
      if (!mounted) return;
      setState(() => _history = next);
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.warranty.error.serial_history'));
    }
  }

  Widget _item(String title, String? sub, String at) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: CrmColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
              ),
              if (sub != null && sub.isNotEmpty)
                Text(sub, style: const TextStyle(fontSize: 12.5, color: CrmColors.muted)),
              Text(formatCrmDateTime(at), style: const TextStyle(fontSize: 12, color: CrmColors.faint)),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final history = _history;
    return CrmFormSheet(
      title: 'crm.warranty.serial_history_title'.tr(args: {'serial': widget.serial}),
      hideCancel: true,
      submitLabel: 'crm.common.close'.tr(),
      error: _error,
      onSubmit: () => Navigator.of(context).pop(),
      children: [
        if (history == null && _error == null) const CrmStateView(loading: true),
        if (history != null) ...[
          if (!history.inventoryAvailable) CrmBanner(message: 'crm.warranty.inventory_unavailable'.tr()),
          for (final m in history.movements)
            _item(
              [
                crmSerialMovementLabel(m.movementType),
                if (m.documentCode != null) m.documentCode!,
                if (m.toWarehouseCode != null)
                  'crm.warranty.to_warehouse'.tr(args: {'code': m.toWarehouseCode})
                else if (m.fromWarehouseCode != null)
                  'crm.warranty.from_warehouse'.tr(args: {'code': m.fromWarehouseCode}),
              ].join(' · '),
              m.reason,
              m.occurredAt,
            ),
          for (final c in history.cases)
            _item(
              'crm.warranty.serial_case'.tr(
                args: {
                  'code': c.caseCode,
                  'role': (c.role == 'ORIGINAL' ? 'crm.warranty.role_original' : 'crm.warranty.role_replacement').tr(),
                  'status': crmWarrantyStatusLabel(c.status),
                },
              ),
              null,
              c.at,
            ),
        ],
      ],
    );
  }
}
