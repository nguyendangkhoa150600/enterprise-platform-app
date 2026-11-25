import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../features/inventory/data/stocktake/stocktake_repository.dart';
import '../../../features/inventory/domain/inventory_capabilities.dart';
import '../../../features/inventory/domain/stocktake/stocktake_models.dart';
import '../../../features/inventory/presentation/stocktake/stocktake_dialogs.dart';
import '../../../features/inventory/presentation/stocktake/stocktake_excel.dart';
import '../../../features/inventory/presentation/stocktake/stocktake_lot_serial_sheet.dart';
import '../../../features/inventory/presentation/stocktake/stocktake_ui.dart';
import '../../../features/inventory/presentation/utils/inventory_sheet_io.dart';
import '../../../features/inventory/presentation/utils/inventory_scope.dart';
import '../../../theme/colors.dart';

/// Chi tiết một đợt kiểm kê (phần "Detail workspace" của web `stocktake-hub.tsx`):
/// thao tác theo trạng thái/quyền, chỉ số tổng hợp, lọc và nhập số đếm từng dòng, Lô/Sê-ri.
class StocktakeDetailSheet extends StatefulWidget {
  final InvStocktakeSession session;
  final ValueChanged<InvStocktakeSession>? onSessionUpdated;

  const StocktakeDetailSheet({super.key, required this.session, this.onSessionUpdated});

  static Future<void> show(
    BuildContext context, {
    required InvStocktakeSession session,
    ValueChanged<InvStocktakeSession>? onSessionUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => StocktakeDetailSheet(session: session, onSessionUpdated: onSessionUpdated),
    );
  }

  @override
  State<StocktakeDetailSheet> createState() => _StocktakeDetailSheetState();
}

class _StocktakeDetailSheetState extends State<StocktakeDetailSheet> {
  final _repo = StocktakeRepository.instance;
  final _scope = InventoryScope.instance;

  late InvStocktakeSession _session;
  List<InvStocktakeLine> _lines = [];
  bool _loadingLines = true;
  bool _dirty = false;
  bool _busy = false;
  bool _posting = false;

  String _gridSearch = '';
  String _gridFilter = 'all'; // all | uncounted | diff | lot_serial

  String? _viewerId;
  bool _allowSelfApproval = false;

  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _reasonCtrls = {};

  static final _qtyFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) => RegExp(r'^\d*([.,]\d{0,3})?$').hasMatch(newValue.text) ? newValue : oldValue,
  );

  InventoryCapabilities get _caps => _scope.capabilities.value;

  bool get _isReadOnly =>
      !_caps.canCreateStocktake ||
      _session.status == StocktakeStatuses.posted ||
      _session.status == StocktakeStatuses.cancelled ||
      _session.status == StocktakeStatuses.pendingApproval;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _scope.capabilities.addListener(_onCaps);
    _scope.ensureCapabilities();
    _loadLines();
    _loadViewer();
  }

  @override
  void dispose() {
    _scope.capabilities.removeListener(_onCaps);
    _disposeCtrls();
    super.dispose();
  }

  void _onCaps() {
    if (mounted) setState(() {});
  }

  void _disposeCtrls() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    for (final c in _reasonCtrls.values) {
      c.dispose();
    }
    _qtyCtrls.clear();
    _reasonCtrls.clear();
  }

  /// Thay toàn bộ dòng bằng dữ liệu server: bỏ các ô nhập cũ để hiển thị lại số đã lưu.
  void _replaceLines(List<InvStocktakeLine> lines) {
    _disposeCtrls();
    _lines = lines;
  }

  void _updateSession(InvStocktakeSession s) {
    _session = s;
    widget.onSessionUpdated?.call(s);
  }

  Future<void> _loadViewer() async {
    final results = await Future.wait<Object?>([_repo.loadCurrentUserId(), _repo.loadAllowSelfApproval()]);
    if (!mounted) return;
    setState(() {
      _viewerId = results[0] as String?;
      _allowSelfApproval = results[1] as bool;
    });
  }

  Future<void> _loadLines() async {
    setState(() {
      _loadingLines = true;
      _dirty = false;
    });
    try {
      final lines = await _repo.loadStocktakeLines(_session.id);
      if (!mounted) return;
      setState(() => _replaceLines(lines));
    } catch (e) {
      _scope.onError(e);
      if (!mounted) return;
      StocktakeUi.notice(context, inventoryErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  void _fail(String prefixKey, Object e) {
    _scope.onError(e);
    if (!mounted) return;
    StocktakeUi.notice(context, '${prefixKey.tr()}${inventoryErrorMessage(e)}', error: true);
  }

  // ---------------------------------------------------------------- Thao tác

  void _onCountChanged(InvStocktakeLine line, String text) {
    final v = StocktakeUi.parseQty(text);
    setState(() {
      final i = _lines.indexWhere((l) => l.id == line.id);
      if (i >= 0) _lines[i] = _lines[i].withCount(v);
      _dirty = true;
    });
  }

  void _onReasonChanged(InvStocktakeLine line, String text) {
    setState(() {
      final i = _lines.indexWhere((l) => l.id == line.id);
      if (i >= 0) _lines[i] = _lines[i].withReason(text);
      _dirty = true;
    });
  }

  /// Lưu nháp số đếm; trả false khi lỗi.
  Future<bool> _saveDraft({bool notify = true}) async {
    setState(() => _busy = true);
    try {
      final res = await _repo.saveStocktakeLines(_session.id, _lines);
      if (!mounted) return true;
      setState(() {
        _updateSession(res.session);
        _replaceLines(res.lines);
        _dirty = false;
      });
      if (notify) StocktakeUi.notice(context, 'inventory.stocktake.notice_saved'.tr());
      return true;
    } catch (e) {
      _fail('inventory.stocktake.err_save_prefix', e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startCounting() async {
    setState(() => _busy = true);
    try {
      final res = await _repo.startStocktakeCounting(_session.id);
      if (!mounted) return;
      setState(() {
        _updateSession(res.session);
        _replaceLines(res.lines);
      });
      StocktakeUi.notice(context, 'inventory.stocktake.notice_started'.tr(args: {'code': res.session.code}));
    } catch (e) {
      _fail('inventory.stocktake.err_start_prefix', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitApproval() async {
    if (_dirty) {
      final ok = await _saveDraft(notify: true);
      if (!ok || !mounted) return;
    }
    final uncounted = _lines.where((l) => l.actualQuantity == null).length;
    if (uncounted > 0) {
      final confirmed = await StocktakeDialogs.confirmSubmit(context, uncounted);
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final updated = await _repo.submitStocktakeForApproval(_session.id);
      if (!mounted) return;
      setState(() => _updateSession(updated));
      StocktakeUi.notice(context, 'inventory.stocktake.notice_submitted'.tr(args: {'code': updated.code}));
    } catch (e) {
      _fail('inventory.stocktake.err_submit_prefix', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await StocktakeDialogs.rejectReason(context);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _repo.rejectStocktakeSession(_session.id, reason);
      if (!mounted) return;
      setState(() => _updateSession(updated));
      StocktakeUi.notice(context, 'inventory.stocktake.notice_rejected'.tr(args: {'code': updated.code}));
    } catch (e) {
      _fail('inventory.stocktake.err_reject_prefix', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveAndPost({bool retryOnly = false}) async {
    if (_posting) return;
    if (!retryOnly) {
      final ok = await StocktakeDialogs.confirmApprove(context, _session);
      if (!ok || !mounted) return;
    }
    setState(() => _posting = true);
    try {
      final updated = retryOnly
          ? await _repo.postStocktake(_session.id)
          : await _repo.approveAndPostStocktake(_session.id);
      final lines = await _repo.loadStocktakeLines(_session.id);
      if (!mounted) return;
      setState(() {
        _updateSession(updated);
        _replaceLines(lines);
        _dirty = false;
      });
      StocktakeUi.notice(
        context,
        updated.documentCode != null
            ? 'inventory.stocktake.notice_posted_doc'.tr(args: {'code': updated.code, 'doc': updated.documentCode})
            : 'inventory.stocktake.notice_posted_nodiff'.tr(args: {'code': updated.code}),
      );
    } catch (e) {
      _fail(retryOnly ? 'inventory.stocktake.err_post_prefix' : 'inventory.stocktake.err_approve_prefix', e);
      // Duyệt có thể đã xong dù ghi sổ lỗi: nạp lại đợt để hiện đúng trạng thái và nút Ghi sổ.
      try {
        final fresh = await _repo.loadStocktake(_session.id);
        if (mounted) setState(() => _updateSession(fresh));
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _cancelSession() async {
    final reason = await StocktakeDialogs.cancelReason(context, _session.code);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _repo.cancelStocktakeSession(_session.id, reason);
      if (!mounted) return;
      setState(() => _updateSession(updated));
      StocktakeUi.notice(context, 'inventory.stocktake.notice_cancelled'.tr(args: {'code': updated.code}));
    } catch (e) {
      _fail('inventory.stocktake.err_cancel_prefix', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Web "Xuất Excel": `Bien_Ban_Kiem_Ke_<mã>.xlsx`, trang 'KiemKe' — điền số đếm rồi "Nhập Excel" lại được.
  Future<void> _export() async {
    try {
      await InventorySheetIO.shareXlsx(
        StocktakeExcel.fileName(_session.code),
        {StocktakeExcel.sheetName: StocktakeExcel.exportRows(_lines)},
      );
      if (!mounted) return;
      StocktakeUi.notice(context, 'inventory.stocktake.notice_exported'.tr(args: {'code': _session.code}));
    } catch (e) {
      if (!mounted) return;
      StocktakeUi.notice(context, 'inventory.stocktake.err_export'.tr(), error: true);
    }
  }

  /// Web "Nhập Excel" (`handleImportExcel`): khớp dòng theo mã vật tư, nạp số thực đếm, lý do và vị trí kệ.
  Future<void> _importExcel() async {
    final InventorySheetFile? file;
    try {
      file = await InventorySheetIO.pick();
    } catch (e) {
      if (!mounted) return;
      StocktakeUi.notice(
          context, '${'inventory.stocktake.err_import_prefix'.tr()}${inventorySheetErrorKey(e).tr()}', error: true);
      return;
    }
    if (file == null || !mounted) return;
    final hits = StocktakeExcel.parse(file);
    var matchCount = 0;
    setState(() {
      for (var i = 0; i < _lines.length; i++) {
        final l = _lines[i];
        final hit = hits[l.materialCode.toUpperCase()];
        final actual = hit?.actual;
        if (hit == null || actual == null) continue;
        matchCount++;
        var next = l.withCount(actual);
        final bin = hit.binLocation;
        if (bin != null && bin.isNotEmpty) next = next.withBinLocation(bin);
        if (hit.reason.isNotEmpty) next = next.withReason(hit.reason);
        _lines[i] = next;
        _qtyCtrls[l.id]?.text = StocktakeUi.editable(actual);
        if (hit.reason.isNotEmpty) _reasonCtrls[l.id]?.text = hit.reason;
      }
      _dirty = true;
    });
    StocktakeUi.notice(context, 'inventory.stocktake.notice_imported'.tr(args: {'n': matchCount}));
  }

  Future<void> _openLotSerial(InvStocktakeLine line) async {
    final res = await StocktakeLotSerialSheet.show(context, line: line, readOnly: _isReadOnly);
    if (res == null || !mounted) return;
    setState(() {
      final i = _lines.indexWhere((l) => l.id == line.id);
      if (i >= 0) {
        _lines[i] = _lines[i].withCount(
          res.actualQuantity,
          lots: res.lotAllocations,
          serials: res.serialAllocations,
          replaceAllocations: true,
        );
      }
      _dirty = true;
    });
    StocktakeUi.notice(
      context,
      'inventory.stocktake.notice_lot_applied'.tr(
          args: {'code': line.materialCode, 'qty': StocktakeUi.qty(res.actualQuantity), 'unit': line.unit}),
    );
  }

  // ---------------------------------------------------------------- Giao diện

  List<InvStocktakeLine> get _filteredLines {
    final q = _gridSearch.trim().toLowerCase();
    return _lines.where((l) {
      if (_gridFilter == 'uncounted' && l.actualQuantity != null) return false;
      if (_gridFilter == 'diff' && l.difference == 0) return false;
      if (_gridFilter == 'lot_serial' && !l.isLotOrSerial) return false;
      if (q.isNotEmpty &&
          !l.materialCode.toLowerCase().contains(q) &&
          !l.materialName.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final filtered = _filteredLines;
    final tail = _loadingLines || filtered.isEmpty ? 1 : 0;

    return StocktakeUi.sheetFrame(
      context: context,
      heightFactor: 0.95,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.code,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.slate900)),
              StocktakeUi.statusBadge(s.status, fontSize: 12),
              Text(s.warehouseName ?? s.warehouseCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate500),
              children: [
                TextSpan(text: s.title),
                TextSpan(text: ' · ${'inventory.stocktake.lead_label'.tr()}: '),
                TextSpan(text: s.leadAuditor ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (s.stocktakeDate != null) ...[
                  TextSpan(text: ' · ${'inventory.stocktake.date_label'.tr()}: '),
                  TextSpan(text: s.stocktakeDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: 1 + filtered.length + tail,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader();
          final i = index - 1;
          if (i < filtered.length) return _buildLineCard(filtered[i]);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                _loadingLines ? 'inventory.stocktake.lines_loading'.tr() : 'inventory.stocktake.lines_empty'.tr(),
                style: const TextStyle(fontSize: 13, color: AppColors.slate400),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActions(),
        const SizedBox(height: 12),
        _buildKpis(),
        const SizedBox(height: 12),
        _buildGridFilters(),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _gridSearch = v),
          style: const TextStyle(fontSize: 13),
          decoration: StocktakeUi.input(
            hint: 'inventory.stocktake.grid_search'.tr(),
            prefix: const Icon(Icons.search, size: 18, color: AppColors.slate400),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData? icon,
    required VoidCallback? onPressed,
    Color? fill,
    Color? outline,
    Color? fg,
  }) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 5)],
      Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
    ]);
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 9);
    if (fill != null) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: fill, foregroundColor: Colors.white, padding: pad),
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg ?? AppColors.slate700,
        side: BorderSide(color: outline ?? AppColors.slate300),
        padding: pad,
      ),
      onPressed: onPressed,
      child: child,
    );
  }

  Widget _buildActions() {
    final s = _session;
    final caps = _caps;
    final disabled = _busy || _posting;
    final actions = <Widget>[
      if (caps.canCreateStocktake && s.status == StocktakeStatuses.draft)
        _actionButton(
          label: 'inventory.stocktake.action_start'.tr(),
          icon: Icons.auto_awesome,
          fill: StocktakeUi.blue600,
          onPressed: disabled ? null : _startCounting,
        ),
      if (!_isReadOnly)
        _actionButton(
          label: _dirty ? 'inventory.stocktake.action_save_dirty'.tr() : 'inventory.stocktake.action_save'.tr(),
          icon: Icons.save_outlined,
          fill: _dirty ? AppColors.amber : null,
          onPressed: disabled ? null : () => _saveDraft(),
        ),
      _actionButton(
        label: 'inventory.stocktake.action_export'.tr(),
        icon: Icons.download_outlined,
        onPressed: disabled ? null : _export,
      ),
      if (!_isReadOnly)
        _actionButton(
          label: 'inventory.stocktake.action_import'.tr(),
          icon: Icons.upload_outlined,
          onPressed: disabled ? null : _importExcel,
        ),
      if (caps.canCreateStocktake && s.status == StocktakeStatuses.counting)
        _actionButton(
          label: 'inventory.stocktake.action_submit'.tr(),
          icon: Icons.send_outlined,
          fill: AppColors.emerald700,
          onPressed: disabled ? null : _submitApproval,
        ),
      if (caps.canApproveStocktake && s.status == StocktakeStatuses.pendingApproval) ...[
        _actionButton(
          label: 'inventory.stocktake.action_reject'.tr(),
          icon: Icons.replay_rounded,
          outline: StocktakeUi.amber300,
          fg: StocktakeUi.amber700,
          onPressed: disabled ? null : _reject,
        ),
        if (s.isSelfApprovalBlocked(_viewerId, _allowSelfApproval))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('inventory.stocktake.self_approval_blocked'.tr(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate500)),
          )
        else
          _actionButton(
            label: 'inventory.stocktake.approve_post'.tr(),
            icon: Icons.check_circle_outline,
            fill: StocktakeUi.green700,
            onPressed: disabled ? null : () => _approveAndPost(),
          ),
      ],
      if (caps.canApproveStocktake && s.status == StocktakeStatuses.approved)
        _actionButton(
          label: _posting ? 'inventory.stocktake.action_posting'.tr() : 'inventory.stocktake.action_post'.tr(),
          icon: Icons.check_circle_outline,
          fill: StocktakeUi.green700,
          onPressed: disabled ? null : () => _approveAndPost(retryOnly: true),
        ),
      if (caps.canCreateStocktake &&
          s.status != StocktakeStatuses.posted &&
          s.status != StocktakeStatuses.cancelled)
        _actionButton(
          label: 'inventory.stocktake.action_cancel'.tr(),
          icon: null,
          outline: const Color(0xFFFCA5A5),
          fg: StocktakeUi.red600,
          onPressed: disabled ? null : _cancelSession,
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Widget _buildKpis() {
    final s = _session;
    final variance = s.totalVarianceValue;
    Widget kpi(String label, String value, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(children: [
        Row(children: [
          kpi('inventory.stocktake.kpi_total'.tr(), 'inventory.stocktake.kpi_total_value'.tr(args: {'n': s.totalItems}),
              AppColors.slate900),
          kpi('inventory.stocktake.kpi_counted'.tr(), '${s.countedItems} / ${s.totalItems}', StocktakeUi.blue600),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          kpi(
            'inventory.stocktake.kpi_diff'.tr(),
            'inventory.stocktake.kpi_diff_value'.tr(args: {'n': s.differenceItems}),
            s.differenceItems > 0 ? StocktakeUi.red600 : StocktakeUi.green700,
          ),
          kpi('inventory.stocktake.kpi_variance'.tr(), StocktakeUi.currency(variance),
              variance == 0 ? StocktakeUi.green700 : (variance > 0 ? StocktakeUi.blue600 : StocktakeUi.red600)),
        ]),
      ]),
    );
  }

  Widget _buildGridFilters() {
    final uncounted = _lines.where((l) => l.actualQuantity == null).length;
    final diff = _lines.where((l) => l.hasDiff).length;
    Widget chip(String key, String label, {bool red = false}) {
      final sel = _gridFilter == key;
      final color = red ? StocktakeUi.red600 : StocktakeUi.blue600;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? color : AppColors.slate600)),
          selected: sel,
          showCheckmark: false,
          selectedColor: red ? StocktakeUi.red50 : StocktakeUi.blue50,
          backgroundColor: Colors.white,
          side: BorderSide(color: sel ? color : AppColors.slate200),
          onSelected: (_) => setState(() => _gridFilter = key),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('all', 'inventory.stocktake.grid_all'.tr(args: {'n': _lines.length})),
        chip('uncounted', 'inventory.stocktake.grid_uncounted'.tr(args: {'n': uncounted})),
        chip('diff', 'inventory.stocktake.grid_diff'.tr(args: {'n': diff}), red: true),
        chip('lot_serial', 'inventory.stocktake.grid_lot_serial'.tr()),
      ]),
    );
  }

  TextEditingController _ctrl(Map<String, TextEditingController> map, String id, String initial) =>
      map.putIfAbsent(id, () => TextEditingController(text: initial));

  Widget _buildLineCard(InvStocktakeLine line) {
    final readOnly = _isReadOnly;
    final isDiff = line.hasDiff;
    final lotSerial = line.isLotOrSerial;
    final counted = line.actualQuantity != null;

    Widget metric(String label, Widget value, {CrossAxisAlignment align = CrossAxisAlignment.start}) => Column(
          crossAxisAlignment: align,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            const SizedBox(height: 3),
            value,
          ],
        );

    final Widget actualCell = (readOnly || lotSerial)
        ? GestureDetector(
            onTap: lotSerial ? () => _openLotSerial(line) : null,
            child: Text(
              counted ? StocktakeUi.qty(line.actualQuantity) : 'inventory.stocktake.not_counted'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: counted ? AppColors.slate900 : AppColors.slate400,
                decoration: lotSerial ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          )
        : SizedBox(
            width: 104,
            child: TextField(
              controller: _ctrl(_qtyCtrls, line.id, StocktakeUi.editable(line.actualQuantity)),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_qtyFormatter],
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              decoration: StocktakeUi.input(hint: 'inventory.stocktake.qty_hint'.tr()),
              onChanged: (v) => _onCountChanged(line, v),
            ),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDiff ? StocktakeUi.amber50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDiff ? const Color(0xFFFDE68A) : AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(line.materialCode,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StocktakeUi.blue700)),
                if (line.isLotTracked)
                  StocktakeUi.tag('inventory.stocktake.tag_lot'.tr(), StocktakeUi.indigo100, StocktakeUi.indigo800),
                if (line.isSerialized)
                  StocktakeUi.tag('inventory.stocktake.tag_serial'.tr(), const Color(0xFFDCFCE7), const Color(0xFF166534)),
              ]),
            ),
            if (lotSerial)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: StocktakeUi.blue700,
                  backgroundColor: StocktakeUi.blue50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openLotSerial(line),
                child: Text('inventory.stocktake.line_detail'.tr(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            if (line.audits.isNotEmpty)
              IconButton(
                tooltip: 'inventory.stocktake.line_history'.tr(),
                visualDensity: VisualDensity.compact,
                onPressed: () => StocktakeDialogs.audits(context, line),
                icon: const Icon(Icons.history, size: 18, color: AppColors.slate500),
              ),
          ]),
          const SizedBox(height: 3),
          Text(line.materialName,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate800)),
          if (line.unitCost != null && line.unitCost != 0)
            Text('inventory.stocktake.unit_cost'.tr(args: {'value': StocktakeUi.currency(line.unitCost)}),
                style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
          const SizedBox(height: 3),
          Text(
            '${'inventory.stocktake.col_unit'.tr()}: ${line.unit}  ·  '
            '${'inventory.stocktake.col_bin'.tr()}: ${(line.binLocation?.isNotEmpty ?? false) ? line.binLocation : '-----'}',
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: metric(
                  'inventory.stocktake.col_book'.tr(),
                  Text(StocktakeUi.qty(line.systemQuantity),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate700)),
                ),
              ),
              metric('inventory.stocktake.col_actual'.tr(), actualCell),
              const SizedBox(width: 14),
              SizedBox(
                width: 64,
                child: metric(
                  'inventory.stocktake.col_diff'.tr(),
                  Text(
                    counted ? StocktakeUi.signedQty(line.difference) : '—',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: StocktakeUi.diffColor(line.difference)),
                  ),
                  align: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (readOnly)
            Text(
              '${'inventory.stocktake.col_reason'.tr()}: ${(line.reason?.isNotEmpty ?? false) ? line.reason : '—'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate600),
            )
          else
            TextField(
              controller: _ctrl(_reasonCtrls, line.id, line.reason ?? ''),
              style: const TextStyle(fontSize: 13),
              decoration: StocktakeUi.input(
                hint: line.difference != 0
                    ? 'inventory.stocktake.reason_hint_diff'.tr()
                    : 'inventory.stocktake.reason_hint_note'.tr(),
                error: line.difference != 0 && (line.reason?.isEmpty ?? true),
              ),
              onChanged: (v) => _onReasonChanged(line, v),
            ),
        ],
      ),
    );
  }
}
