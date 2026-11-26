import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../data/stocktake/stocktake_repository.dart';
import '../../domain/stocktake/stocktake_models.dart';
import '../utils/inventory_scope.dart';
import 'stocktake_auditor_picker.dart';
import 'stocktake_ui.dart';

/// Tạo đợt kiểm kê (web `create-stocktake-dialog.tsx`): tạo rồi chốt snapshot và bắt đầu đếm ngay.
/// Trả về đợt đã bắt đầu đếm, hoặc null khi đóng.
class CreateStocktakeSheet extends StatefulWidget {
  final List<InvStocktakeWarehouse> warehouses;
  final String? initialWarehouseCode;

  const CreateStocktakeSheet({super.key, required this.warehouses, this.initialWarehouseCode});

  static Future<InvStocktakeSession?> show(
    BuildContext context, {
    required List<InvStocktakeWarehouse> warehouses,
    String? initialWarehouseCode,
  }) {
    return showModalBottomSheet<InvStocktakeSession>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateStocktakeSheet(warehouses: warehouses, initialWarehouseCode: initialWarehouseCode),
    );
  }

  @override
  State<CreateStocktakeSheet> createState() => _CreateStocktakeSheetState();
}

class _CreateStocktakeSheetState extends State<CreateStocktakeSheet> {
  final _repo = StocktakeRepository.instance;
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _warehouseCode = '';
  DateTime _date = DateTime.now();
  String _scopeType = 'ALL';
  final List<String> _selectedCategories = [];
  final List<InvStocktakeMaterial> _selectedItems = [];
  String _leadAuditor = '';
  final List<String> _selectedAuditors = [];

  List<InvStocktakeMaterial> _materials = [];
  List<InvAuditorCandidate> _candidates = [];
  Map<String, double> _stockByMaterialId = {};
  int _stockRequest = 0;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialWarehouseCode;
    if (init != null && widget.warehouses.any((w) => w.code == init)) {
      _warehouseCode = init;
    } else if (widget.warehouses.isNotEmpty) {
      _warehouseCode = widget.warehouses.first.code;
    }
    _loadMaterials();
    _loadAuditors();
    _loadStock();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final list = await _repo.loadMaterials();
      if (!mounted) return;
      setState(() => _materials = list);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = inventoryErrorMessage(e));
    }
  }

  Future<void> _loadAuditors() async {
    final list = await _repo.loadAuditorCandidates();
    if (!mounted || list.isEmpty) return;
    setState(() => _candidates = list);
  }

  Future<void> _loadStock() async {
    final code = _warehouseCode;
    final req = ++_stockRequest;
    if (code.isEmpty) {
      setState(() => _stockByMaterialId = {});
      return;
    }
    try {
      final map = await _repo.loadWarehouseStockByMaterialId(code);
      if (!mounted || req != _stockRequest) return;
      setState(() => _stockByMaterialId = map);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted || req != _stockRequest) return;
      setState(() => _stockByMaterialId = {});
    }
  }

  double _bookQty(InvStocktakeMaterial m) => _stockByMaterialId[m.id] ?? 0;

  List<String> get _categoryOptions {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _materials) {
      final t = m.type;
      if (t != null && t.isNotEmpty && seen.add(t)) out.add(t);
    }
    return out;
  }

  Future<void> _pickWarehouse() async {
    final v = await showStocktakePicker(
      context,
      title: 'inventory.stocktake.create_warehouse'.tr(),
      selected: _warehouseCode,
      options: widget.warehouses
          .map((w) => StocktakePickOption(
                w.code,
                '${w.code} — ${w.name.isNotEmpty ? w.name : 'inventory.stocktake.warehouse_fallback'.tr()}',
                description: w.location,
              ))
          .toList(),
    );
    if (!mounted || v == null || v == _warehouseCode) return;
    setState(() => _warehouseCode = v);
    _loadStock();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || d == null) return;
    setState(() => _date = d);
  }

  Future<void> _pickMaterial() async {
    final current = _selectedItems.map((i) => i.code).toSet();
    final v = await showStocktakePicker(
      context,
      title: 'inventory.stocktake.create_add_material'.tr(),
      options: _materials
          .where((m) => !current.contains(m.code))
          .map((m) => StocktakePickOption(
                m.code,
                '${m.code} — ${m.name}',
                description: 'inventory.stocktake.create_material_desc'.tr(args: {
                  'unit': m.unit.isNotEmpty ? m.unit : 'inventory.stocktake.unit_fallback'.tr(),
                  'qty': StocktakeUi.qty(_bookQty(m)),
                  'type': m.type ?? 'inventory.stocktake.type_fallback'.tr(),
                }),
              ))
          .toList(),
    );
    if (!mounted || v == null) return;
    final mat = _materials.where((m) => m.code == v).firstOrNull;
    if (mat == null || _selectedItems.any((i) => i.code == v)) return;
    setState(() => _selectedItems.add(mat));
  }

  void _addAllInWarehouse() {
    final existing = _selectedItems.map((i) => i.code).toSet();
    final toAdd = <InvStocktakeMaterial>[];
    for (final m in _materials) {
      if (_bookQty(m) > 0 && existing.add(m.code)) toAdd.add(m);
    }
    if (toAdd.isNotEmpty) setState(() => _selectedItems.addAll(toAdd));
  }

  Future<void> _pickLead() async {
    final options = _candidates
        .where((c) => c.hasWarehouseAccess)
        .map((c) => StocktakePickOption(
              c.name,
              '${c.name} ${c.code != null ? '(${c.code})' : ''}'.trim(),
              description: [c.position, c.department].where((e) => e != null && e.isNotEmpty).join(' • '),
            ))
        .toList();
    final v = await showStocktakePicker(
      context,
      title: 'inventory.stocktake.create_lead'.tr(),
      options: options,
      selected: _leadAuditor,
      emptyText: options.isEmpty ? 'inventory.stocktake.no_warehouse_staff'.tr() : null,
    );
    if (!mounted || v == null) return;
    setState(() {
      _leadAuditor = v;
      _selectedAuditors.remove(v);
    });
  }

  void _toggleAuditor(String name) {
    setState(() {
      if (_selectedAuditors.contains(name)) {
        _selectedAuditors.remove(name);
      } else {
        _selectedAuditors.add(name);
      }
    });
  }

  void _addCustomAuditor(String name) {
    final val = name.trim();
    if (val.isNotEmpty && !_selectedAuditors.contains(val) && val != _leadAuditor) {
      setState(() => _selectedAuditors.add(val));
    }
  }

  Future<void> _submit() async {
    String? err;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      err = 'inventory.stocktake.err_title'.tr();
    } else if (_warehouseCode.isEmpty) {
      err = 'inventory.stocktake.err_warehouse'.tr();
    } else if (_leadAuditor.trim().isEmpty) {
      err = 'inventory.stocktake.err_lead'.tr();
    } else {
      final lead = _candidates.where((c) => c.name == _leadAuditor.trim()).firstOrNull;
      if (lead != null && !lead.hasWarehouseAccess) {
        err = 'inventory.stocktake.err_lead_access'.tr();
      } else if (_scopeType == 'SPECIFIC_ITEMS' && _selectedItems.isEmpty) {
        err = 'inventory.stocktake.err_items'.tr();
      } else if (_scopeType == 'CATEGORY' && _selectedCategories.isEmpty) {
        err = 'inventory.stocktake.err_categories'.tr();
      }
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final note = _noteCtrl.text.trim();
      final created = await _repo.createStocktakeSession({
        'title': title,
        'warehouseCode': _warehouseCode,
        'stocktakeDate': DateFormat('yyyy-MM-dd').format(_date),
        'scopeType': _scopeType,
        if (_scopeType == 'CATEGORY') 'scopeCategories': _selectedCategories,
        if (_scopeType == 'SPECIFIC_ITEMS') 'specificMaterialCodes': _selectedItems.map((i) => i.code).toList(),
        'leadAuditor': _leadAuditor.trim(),
        'auditors': _selectedAuditors,
        if (note.isNotEmpty) 'note': note,
      });
      final started = await _repo.startStocktakeCounting(created.id);
      if (!mounted) return;
      Navigator.pop(context, started.session);
    } catch (e) {
      InventoryScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = inventoryErrorMessage(e, 'inventory.stocktake.err_create');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StocktakeUi.sheetFrame(
      context: context,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('inventory.stocktake.create_title'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          const SizedBox(height: 2),
          Text('inventory.stocktake.create_subtitle'.tr(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text('inventory.stocktake.cancel'.tr()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: StocktakeUi.blue600),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(_submitting
                  ? 'inventory.stocktake.create_submitting'.tr()
                  : 'inventory.stocktake.create_submit'.tr()),
            ),
          ),
        ]),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)))),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          _label('inventory.stocktake.create_warehouse'.tr(), required: true),
          StocktakeSelectField(
            text: _warehouseCode.isEmpty
                ? 'inventory.stocktake.create_warehouse_hint'.tr()
                : _warehouseLabel(_warehouseCode),
            placeholder: _warehouseCode.isEmpty,
            onTap: _submitting ? null : _pickWarehouse,
          ),
          const SizedBox(height: 12),
          _label('inventory.stocktake.create_date'.tr(), required: true),
          StocktakeSelectField(
            text: DateFormat('dd/MM/yyyy').format(_date),
            onTap: _submitting ? null : _pickDate,
          ),
          const SizedBox(height: 12),
          _label('inventory.stocktake.create_name'.tr(), required: true),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: StocktakeUi.input(hint: 'inventory.stocktake.create_name_hint'.tr()),
          ),
          const SizedBox(height: 14),
          _label('inventory.stocktake.create_scope'.tr()),
          _scopeCard('ALL', Icons.layers_outlined, 'inventory.stocktake.scope_all'.tr(),
              'inventory.stocktake.scope_all_desc'.tr(), null),
          const SizedBox(height: 8),
          _scopeCard('CATEGORY', Icons.inventory_2_outlined, 'inventory.stocktake.scope_category'.tr(),
              'inventory.stocktake.scope_category_desc'.tr(), _selectedCategories.length),
          const SizedBox(height: 8),
          _scopeCard('SPECIFIC_ITEMS', Icons.fact_check_outlined, 'inventory.stocktake.scope_items'.tr(),
              'inventory.stocktake.scope_items_desc'.tr(), _selectedItems.length),
          const SizedBox(height: 10),
          if (_scopeType == 'ALL') _scopeAllInfo(),
          if (_scopeType == 'CATEGORY') _scopeCategoryBox(),
          if (_scopeType == 'SPECIFIC_ITEMS') _scopeItemsBox(),
          const SizedBox(height: 14),
          _label('inventory.stocktake.create_lead'.tr(), required: true),
          StocktakeSelectField(
            text: _leadAuditor.isEmpty ? 'inventory.stocktake.create_lead_hint'.tr() : _leadAuditor,
            placeholder: _leadAuditor.isEmpty,
            onTap: _submitting ? null : _pickLead,
            onClear: _leadAuditor.isEmpty ? null : () => setState(() => _leadAuditor = ''),
          ),
          const SizedBox(height: 12),
          _label('inventory.stocktake.create_note'.tr()),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: StocktakeUi.input(hint: 'inventory.stocktake.create_note_hint'.tr()),
          ),
          const SizedBox(height: 14),
          StocktakeAuditorPicker(
            candidates: _candidates,
            selectedNames: _selectedAuditors,
            leadAuditorName: _leadAuditor,
            onToggleName: _toggleAuditor,
            onAddCustomName: _addCustomAuditor,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: StocktakeUi.blue50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: StocktakeUi.blue200),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: StocktakeUi.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text('inventory.stocktake.create_snapshot_info'.tr(),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _warehouseLabel(String code) {
    final w = widget.warehouses.where((w) => w.code == code).firstOrNull;
    if (w == null) return code;
    return '${w.code} — ${w.name.isNotEmpty ? w.name : 'inventory.stocktake.warehouse_fallback'.tr()}';
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
          children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: StocktakeUi.red600)),
          ],
        )),
      );

  Widget _scopeCard(String key, IconData icon, String title, String desc, int? count) {
    final sel = _scopeType == key;
    return InkWell(
      onTap: _submitting ? null : () => setState(() => _scopeType = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? StocktakeUi.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? StocktakeUi.blue600 : AppColors.slate300, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: sel ? StocktakeUi.blue600 : AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: sel ? StocktakeUi.blue700 : AppColors.slate600)),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ]),
          ),
          if (count != null && count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? StocktakeUi.blue600 : AppColors.slate400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ]),
      ),
    );
  }

  BoxDecoration get _boxDeco => BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      );

  Widget _scopeAllInfo() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: _boxDeco,
        child: Row(children: [
          const Icon(Icons.info_outline, size: 18, color: StocktakeUi.blue600),
          const SizedBox(width: 8),
          Expanded(
            child: Text('inventory.stocktake.scope_all_info'.tr(args: {'warehouse': _warehouseCode}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
          ),
        ]),
      );

  Widget _scopeCategoryBox() {
    final cats = _categoryOptions;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _boxDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'inventory.stocktake.scope_category_pick'.tr(args: {'n': _selectedCategories.length, 'total': cats.length}),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
        ),
        Row(children: [
          TextButton(
            onPressed: () => setState(() {
              _selectedCategories
                ..clear()
                ..addAll(cats);
            }),
            child: Text('inventory.stocktake.select_all'.tr()),
          ),
          TextButton(
            onPressed: () => setState(_selectedCategories.clear),
            child: Text('inventory.stocktake.deselect'.tr(), style: const TextStyle(color: AppColors.slate500)),
          ),
        ]),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.map((c) {
            final sel = _selectedCategories.contains(c);
            return FilterChip(
              label: Text(c, style: TextStyle(fontSize: 12.5, color: sel ? StocktakeUi.blue700 : AppColors.slate700)),
              selected: sel,
              showCheckmark: true,
              checkmarkColor: StocktakeUi.blue600,
              selectedColor: StocktakeUi.blue50,
              backgroundColor: Colors.white,
              side: BorderSide(color: sel ? StocktakeUi.blue600 : AppColors.slate300),
              onSelected: (_) => setState(() {
                if (sel) {
                  _selectedCategories.remove(c);
                } else {
                  _selectedCategories.add(c);
                }
              }),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _scopeItemsBox() {
    final totalBook = _selectedItems.fold<double>(0, (s, i) => s + _bookQty(i));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _boxDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('inventory.stocktake.create_add_material'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
        Wrap(children: [
          TextButton(onPressed: _addAllInWarehouse, child: Text('inventory.stocktake.add_all_in_wh'.tr())),
          if (_selectedItems.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selectedItems.clear),
              child: Text('inventory.stocktake.clear_list'.tr(), style: const TextStyle(color: StocktakeUi.red600)),
            ),
        ]),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickMaterial,
            icon: const Icon(Icons.add, size: 18),
            label: Text('inventory.stocktake.material_search_hint'.tr(), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text('inventory.stocktake.items_count'.tr(args: {'n': _selectedItems.length}),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
          ),
          Text('inventory.stocktake.items_total_book'.tr(args: {'qty': StocktakeUi.qty(totalBook)}),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
        ]),
        const SizedBox(height: 8),
        if (_selectedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('inventory.stocktake.items_empty'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate400)),
          )
        else
          for (var i = 0; i < _selectedItems.length; i++) _itemRow(i),
      ]),
    );
  }

  Widget _itemRow(int i) {
    final item = _selectedItems[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.code,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, color: StocktakeUi.blue600)),
            Text(item.name,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(StocktakeUi.qty(_bookQty(item)),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate900)),
          Text(item.unit.isNotEmpty ? item.unit : 'inventory.stocktake.unit_fallback'.tr(),
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate600)),
        ]),
        IconButton(
          tooltip: 'inventory.stocktake.remove_item'.tr(),
          onPressed: () => setState(() => _selectedItems.removeAt(i)),
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slate400),
        ),
      ]),
    );
  }
}
