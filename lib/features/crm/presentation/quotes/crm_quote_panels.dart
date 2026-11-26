import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../screens/procedure/components/procedure_modals.dart';
import '../../../../services/module_business_service.dart';
import '../../data/quotes/crm_quotes_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/quotes/crm_quote_models.dart';
import '../../domain/quotes/crm_quote_support_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../utils/crm_scope.dart';
import 'crm_quote_logic.dart';

/// Mở hồ sơ Quy trình (web: sang `/modules/procedure#workspace/<id>` kèm `returnTo`); mobile mở sheet chi tiết hồ sơ
/// của module Quy trình, đóng sheet là quay lại màn báo giá. [onClosed] để tải lại báo giá sau khi duyệt.
Future<void> crmOpenProcedureInstance(BuildContext context, String instanceId, {VoidCallback? onClosed}) async {
  final service = ModuleBusinessService();
  final instance = await service.getProcedureInstance(instanceId);
  if (!context.mounted) return;
  if (instance == null) {
    showCrmSnack(context, 'crm.quotes.procedure_open_error'.tr(), error: true);
    return;
  }
  showProcedureDetailSheet(context: context, initialItem: instance, service: service, onDataChanged: onClosed ?? () {});
}

/// Khối thu gọn được (web `WorkspaceSection`).
class CrmQuoteSection extends StatelessWidget {
  final String title;
  final bool initiallyOpen;
  final List<Widget> children;
  final GlobalKey? anchor;
  const CrmQuoteSection({
    super.key,
    required this.title,
    this.initiallyOpen = false,
    required this.children,
    this.anchor,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: anchor,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: CrmColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyOpen,
        maintainState: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: CrmColors.text),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// Thông báo đang chờ chính người xem duyệt (web `AwaitingApprovalNotice`).
class CrmQuoteAwaitingNotice extends StatelessWidget {
  final CrmQuoteApprovalTarget target;
  final VoidCallback onOpenPlan;
  final VoidCallback onChanged;
  const CrmQuoteAwaitingNotice({super.key, required this.target, required this.onOpenPlan, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final instance = target.procedureInstance;
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
              const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF92400E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (target.isPlan ? 'crm.quotes.awaiting.plan' : 'crm.quotes.awaiting.quote').tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (instance != null)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CrmButton(
                  label: 'crm.quotes.procedure_action'.tr(),
                  onPressed: () => crmOpenProcedureInstance(context, instance, onClosed: onChanged),
                ),
                if ((target.procedureInstanceCode ?? '').isNotEmpty)
                  Text(
                    'crm.quotes.procedure_record'.tr(args: {'code': target.procedureInstanceCode}),
                    style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
                  ),
              ],
            )
          else if (target.viaProcedure)
            Text('crm.quotes.awaiting.creating'.tr(), style: const TextStyle(fontSize: 13))
          else if (target.isPlan)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('crm.quotes.awaiting.plan_hint'.tr(), style: const TextStyle(fontSize: 13)),
                OutlinedButton(onPressed: onOpenPlan, child: Text('crm.quotes.awaiting.open_plan'.tr())),
              ],
            )
          else
            Text('crm.quotes.awaiting.quote_hint'.tr(), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Cảnh báo cần duyệt / tình trạng duyệt (web `ApprovalNotice`).
class CrmQuoteApprovalNotice extends StatelessWidget {
  final CrmQuoteDetail detail;
  const CrmQuoteApprovalNotice({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final version = detail.version;
    final link = detail.procedure;
    final check = detail.approvalCheck;
    if (version.status == CrmQuoteStatus.draft && check != null) {
      if (check.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'crm.quotes.approval.no_threshold'.tr(),
            style: const TextStyle(fontSize: 12.5, color: CrmColors.muted),
          ),
        );
      }
      return CrmBanner(
        kind: CrmBannerKind.warning,
        message: ['crm.quotes.approval.will_need'.tr(), ...check.map((r) => '• ${r.message}')].join('\n'),
      );
    }
    if (version.approvalReasons.isEmpty && link == null) return const SizedBox.shrink();
    final lines = <String>[];
    if (version.approvalReasons.isNotEmpty) {
      lines.add('crm.quotes.approval.reasons'.tr());
      lines.addAll(version.approvalReasons.map((r) => '• ${r.message}'));
    }
    if (link != null) {
      final state = switch (link.status) {
        'START_PENDING' => 'crm.quotes.approval.proc_creating'.tr(),
        'FAILED' => 'crm.quotes.approval.proc_failed'.tr(
          args: {'error': (link.lastError ?? '').isEmpty ? '' : ' (${link.lastError})'},
        ),
        'RUNNING' => 'crm.quotes.approval.proc_running'.tr(),
        _ => 'crm.quotes.approval.proc_done'.tr(),
      };
      final code = (link.instanceCode ?? '').isEmpty
          ? ''
          : 'crm.quotes.approval.proc_code'.tr(args: {'code': link.instanceCode});
      lines.add('${'crm.quotes.approval.via_procedure'.tr()}$code: $state');
    } else if (version.status == CrmQuoteStatus.pending) {
      lines.add('crm.quotes.approval.direct_pending'.tr());
    }
    return CrmBanner(
      kind: version.status == CrmQuoteStatus.pending ? CrmBannerKind.warning : CrmBannerKind.info,
      message: lines.join('\n'),
    );
  }
}

// --- So sánh phiên bản -----------------------------------------------------------------------------------------------

/// So sánh hai phiên bản (web `QuoteCompare`, `GET /quotes/:id/compare`).
class CrmQuoteCompare extends StatefulWidget {
  final CrmQuoteDetail detail;
  const CrmQuoteCompare({super.key, required this.detail});

  @override
  State<CrmQuoteCompare> createState() => _CrmQuoteCompareState();
}

class _CrmQuoteCompareState extends State<CrmQuoteCompare> {
  late final List<CrmQuoteVersionSummary> _versions = [...widget.detail.versions]
    ..sort((a, b) => a.versionNo.compareTo(b.versionNo));
  late int _from = _versions.length >= 2 ? _versions[_versions.length - 2].versionNo : 1;
  late int _to = widget.detail.currentVersion;
  CrmQuoteComparison? _result;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_from == _to) return setState(() => _result = null);
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final r = await CrmQuotesRepository.instance.compare(widget.detail.id, _from, _to);
      if (!mounted || id != _request) return;
      setState(() {
        _result = r;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() => _error = crmErrorMessage(e, 'crm.quotes.compare.error'));
    }
    if (!mounted || id != _request) return;
    setState(() => _loading = false);
  }

  List<CrmSelectOption> get _options => _versions
      .map(
        (v) => CrmSelectOption(
          value: '${v.versionNo}',
          label: 'crm.quotes.version_n'.tr(args: {'n': v.versionNo}),
          description: crmQuoteStatusLabel(v.status),
        ),
      )
      .toList();

  String _cell(CrmQuoteLineDifference row, String field, String Function(double) format) {
    final before = (row.from?[field] as num?)?.toDouble() ?? 0;
    final after = (row.to?[field] as num?)?.toDouble() ?? 0;
    if (row.change == 'ADDED') return format(after);
    if (row.change == 'REMOVED') return format(before);
    return row.fields.contains(field) ? '${format(before)} → ${format(after)}' : format(after);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CrmCard(
      title: 'crm.quotes.compare.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CrmSelectField(
                  value: '$_from',
                  options: _options,
                  searchHint: null,
                  onChanged: (s) {
                    if (s.value == null) return;
                    setState(() => _from = int.parse(s.value!));
                    _load();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('crm.quotes.compare.with'.tr(), style: const TextStyle(color: CrmColors.muted)),
              ),
              Expanded(
                child: CrmSelectField(
                  value: '$_to',
                  options: _options,
                  onChanged: (s) {
                    if (s.value == null) return;
                    setState(() => _to = int.parse(s.value!));
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null) CrmBanner(message: _error!),
          if (_from == _to)
            Text('crm.quotes.compare.pick_two'.tr(), style: const TextStyle(color: CrmColors.muted))
          else if (_loading && r == null)
            const CrmStateView(loading: true)
          else if (r != null) ...[
            if (r.lines.isEmpty)
              Text('crm.quotes.compare.same'.tr(), style: const TextStyle(color: CrmColors.muted))
            else
              for (final row in r.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: CrmColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CrmStatusPill(
                            label: 'crm.quotes.compare.change_${row.change.toLowerCase()}'.tr(),
                            tone: switch (row.change) {
                              'ADDED' => CrmTone.success,
                              'REMOVED' => CrmTone.danger,
                              _ => CrmTone.warning,
                            },
                            dense: true,
                          ),
                          const SizedBox(width: 6),
                          CrmCodeBadge(row.materialCode),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${row.materialName} (${row.unit})', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      CrmInfoRow(
                        label: 'crm.quotes.lines.qty'.tr(),
                        value: _cell(row, 'quantity', (v) => formatCrmQuantity(v)),
                      ),
                      CrmInfoRow(
                        label: 'crm.quotes.lines.unit_price'.tr(),
                        value: _cell(row, 'unitPrice', formatCrmMoney),
                      ),
                      CrmInfoRow(
                        label: 'crm.quotes.lines.discount'.tr(),
                        value: _cell(row, 'discountPercent', formatCrmPercent),
                      ),
                      CrmInfoRow(
                        label: 'crm.quotes.lines.amount'.tr(),
                        value: _cell(row, 'lineAmount', formatCrmMoney),
                      ),
                    ],
                  ),
                ),
            const Divider(color: CrmColors.border),
            CrmInfoRow(label: 'crm.quotes.compare.delta_net'.tr(), value: crmSigned(r.netDelta, formatCrmMoney)),
            CrmInfoRow(label: 'crm.quotes.compare.delta_vat'.tr(), value: crmSigned(r.vatDelta, formatCrmMoney)),
            CrmInfoRow(
              label: 'crm.quotes.compare.delta_total'.tr(),
              child: Text(crmSigned(r.totalDelta, formatCrmMoney), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            CrmInfoRow(label: 'crm.quotes.compare.delta_profit'.tr(), value: crmSigned(r.profitDelta, formatCrmMoney)),
          ],
        ],
      ),
    );
  }
}

// --- Khuyến mãi -----------------------------------------------------------------------------------------------------

/// Khuyến mãi của báo giá (web `QuotePromotionsPanel`): chọn nhiều từ tập của dự án, lưu một lần kèm `revision`.
class CrmQuotePromotionsPanel extends StatefulWidget {
  final String quoteId;
  final String? opportunityId;
  final int versionNo;
  final int revision;
  final List<CrmQuotePromotionSnapshot> applied;
  final bool editable;
  final VoidCallback onSaved;
  const CrmQuotePromotionsPanel({
    super.key,
    required this.quoteId,
    required this.opportunityId,
    required this.versionNo,
    required this.revision,
    required this.applied,
    required this.editable,
    required this.onSaved,
  });

  @override
  State<CrmQuotePromotionsPanel> createState() => _CrmQuotePromotionsPanelState();
}

class _CrmQuotePromotionsPanelState extends State<CrmQuotePromotionsPanel> {
  List<CrmOpportunityPromotion> _projectSet = const [];
  late List<String> _chosen = widget.applied.map((a) => a.catalogId).toList();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void didUpdateWidget(covariant CrmQuotePromotionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = widget.applied.map((a) => a.catalogId).join(',');
    if (key != oldWidget.applied.map((a) => a.catalogId).join(',') || widget.revision != oldWidget.revision) {
      _chosen = widget.applied.map((a) => a.catalogId).toList();
    }
    if (widget.editable != oldWidget.editable || widget.opportunityId != oldWidget.opportunityId) _loadProject();
  }

  Future<void> _loadProject() async {
    final opp = widget.opportunityId;
    if (!widget.editable || opp == null) return;
    try {
      final rows = await CrmQuotesRepository.instance.listOpportunityPromotions(opp);
      if (!mounted) return;
      setState(() {
        _projectSet = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.promotions.load_error'));
    }
  }

  String _label(String id) {
    for (final a in widget.applied) {
      if (a.catalogId == id) return crmPromotionLabel(a.code, a.name, a.discountType, a.value);
    }
    for (final p in _projectSet) {
      final c = p.catalog;
      if (c.id == id) return crmPromotionLabel(c.code, c.name, c.discountType, c.value);
    }
    return id;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CrmQuotesRepository.instance.saveQuotePromotions(
        widget.quoteId,
        widget.versionNo,
        _chosen,
        widget.revision,
      );
      if (!mounted) return;
      showCrmSnack(context, 'crm.quotes.promotions.saved'.tr());
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.promotions.save_error'));
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12.5, color: CrmColors.muted);
    final opp = widget.opportunityId;
    final options = _projectSet
        .where((p) => p.catalog.effective && !_chosen.contains(p.catalog.id))
        .map(
          (p) => CrmSelectOption(
            value: p.catalog.id,
            label: p.catalog.name,
            badge: p.catalog.code,
            description:
                '${crmPromotionKindLabel(p.catalog.kind)} · ${crmPromotionValueLabel(p.catalog.discountType, p.catalog.value)}',
          ),
        )
        .toList();
    final dirty = !crmSameIdSet(_chosen, widget.applied.map((a) => a.catalogId).toList());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('crm.quotes.promotions.not_deducted'.tr(), style: muted),
        if (opp == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('crm.quotes.promotions.no_project'.tr(), style: muted),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CrmBanner(message: _error!),
          ),
        const SizedBox(height: 8),
        if (widget.editable && opp != null) ...[
          if (_chosen.isEmpty)
            Text('crm.quotes.promotions.none_chosen'.tr(), style: muted)
          else
            for (final id in _chosen)
              Row(
                children: [
                  Expanded(child: Text(_label(id))),
                  TextButton(
                    onPressed: () => setState(() => _chosen = _chosen.where((c) => c != id).toList()),
                    child: Text('crm.quotes.promotions.unpick'.tr(), style: const TextStyle(color: CrmColors.danger)),
                  ),
                ],
              ),
          const SizedBox(height: 8),
          CrmSelectField(
            value: null,
            options: options,
            placeholder: 'crm.quotes.promotions.add'.tr(),
            emptyText: 'crm.quotes.promotions.empty_project'.tr(),
            onChanged: (s) {
              final next = s.value;
              if (next == null || _chosen.contains(next)) return;
              setState(() => _chosen = [..._chosen, next]);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: CrmButton(
              label: 'crm.quotes.promotions.save'.tr(),
              outlined: true,
              busy: _saving,
              onPressed: dirty ? _save : null,
            ),
          ),
        ] else if (widget.applied.isNotEmpty)
          for (final a in widget.applied) Text('• ${crmPromotionLabel(a.code, a.name, a.discountType, a.value)}')
        else if (opp != null)
          Text('crm.quotes.promotions.version_none'.tr(), style: muted),
      ],
    );
  }
}

// --- Người theo dõi, đối tượng liên quan --------------------------------------------------------------------------------

/// Người theo dõi (web `FollowersPanel`): thêm, bỏ ngay.
class CrmQuoteFollowersPanel extends StatefulWidget {
  final String quoteId;
  final bool editable;
  const CrmQuoteFollowersPanel({super.key, required this.quoteId, required this.editable});

  @override
  State<CrmQuoteFollowersPanel> createState() => _CrmQuoteFollowersPanelState();
}

class _CrmQuoteFollowersPanelState extends State<CrmQuoteFollowersPanel> {
  final _repo = CrmQuotesRepository.instance;
  List<CrmQuoteFollower> _followers = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await _repo.listFollowers(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _followers = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.followers.load_error'));
    }
  }

  Future<void> _run(Future<void> Function() work, String errorKey) async {
    try {
      await work();
      await _reload();
    } catch (e) {
      if (mounted) showCrmSnack(context, crmQuoteFormError(e, errorKey, crmErrorMessage), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CrmScope.instance;
    final taken = _followers.map((f) => f.userId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle('crm.quotes.followers.title'.tr()),
        if (_error != null) CrmBanner(message: _error!),
        if (_followers.isEmpty)
          Text('crm.quotes.followers.empty'.tr(), style: const TextStyle(fontSize: 12.5, color: CrmColors.muted))
        else
          for (final f in _followers)
            Row(
              children: [
                Expanded(child: Text(scope.personName(f.userId))),
                if (widget.editable)
                  TextButton(
                    onPressed: () =>
                        _run(() => _repo.removeFollower(widget.quoteId, f.userId), 'crm.quotes.followers.remove_error'),
                    child: Text('crm.quotes.followers.unfollow'.tr(), style: const TextStyle(color: CrmColors.danger)),
                  ),
              ],
            ),
        if (widget.editable) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: scope.people,
            builder: (context, people, _) => CrmSelectField(
              value: null,
              options: crmPeopleOptions(people).where((o) => !taken.contains(o.value)).toList(),
              placeholder: 'crm.quotes.followers.add'.tr(),
              onChanged: (s) {
                final id = s.value;
                if (id != null) _run(() => _repo.addFollower(widget.quoteId, id), 'crm.quotes.followers.add_error');
              },
            ),
          ),
        ],
      ],
    );
  }
}

String crmQuoteLinkTypeLabel(String type) => 'crm.quotes.links.type.${type.toLowerCase()}'.tr();

/// Đối tượng liên quan (web `LinksPanel`): chọn loại rồi chọn đối tượng; thêm, xoá ngay.
class CrmQuoteLinksPanel extends StatefulWidget {
  final String quoteId;
  final bool editable;
  const CrmQuoteLinksPanel({super.key, required this.quoteId, required this.editable});

  @override
  State<CrmQuoteLinksPanel> createState() => _CrmQuoteLinksPanelState();
}

class _CrmQuoteLinksPanelState extends State<CrmQuoteLinksPanel> {
  final _repo = CrmQuotesRepository.instance;
  List<CrmQuoteLink> _links = const [];
  String? _type;
  List<CrmQuoteLinkTarget> _options = const [];
  String? _target;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await _repo.listLinks(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _links = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.links.load_error'));
    }
  }

  Future<void> _setType(String? type) async {
    final id = ++_request;
    setState(() {
      _type = type;
      _target = null;
      _options = const [];
      _loading = type != null;
    });
    if (type == null) return;
    try {
      final rows = await _repo.loadLinkTargets(type);
      if (!mounted || id != _request) return;
      setState(() => _options = rows);
    } catch (_) {
      if (!mounted || id != _request) return;
      setState(() => _options = const []);
    }
    if (!mounted || id != _request) return;
    setState(() => _loading = false);
  }

  Future<void> _add() async {
    final type = _type;
    final target = _target;
    if (type == null || target == null) return;
    if (_links.any((l) => l.targetType == type && l.targetId == target)) {
      showCrmSnack(context, 'crm.quotes.links.duplicate'.tr(), error: true);
      return;
    }
    try {
      await _repo.addLink(widget.quoteId, type, target);
      if (!mounted) return;
      setState(() => _target = null);
      await _reload();
    } catch (e) {
      if (mounted) {
        showCrmSnack(context, crmQuoteFormError(e, 'crm.quotes.links.add_error', crmErrorMessage), error: true);
      }
    }
  }

  Future<void> _remove(CrmQuoteLink link) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.quotes.links.remove_confirm'.tr(),
      confirmLabel: 'crm.quotes.links.remove'.tr(),
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.removeLink(widget.quoteId, link.id);
      await _reload();
    } catch (e) {
      if (mounted) {
        showCrmSnack(context, crmQuoteFormError(e, 'crm.quotes.links.remove_error', crmErrorMessage), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle('crm.quotes.links.title'.tr()),
        if (_error != null) CrmBanner(message: _error!),
        if (_links.isEmpty)
          Text('crm.quotes.links.empty'.tr(), style: const TextStyle(fontSize: 12.5, color: CrmColors.muted))
        else
          for (final l in _links)
            Row(
              children: [
                Expanded(child: Text('${crmQuoteLinkTypeLabel(l.targetType)}: ${l.targetLabel}')),
                if (widget.editable)
                  TextButton(
                    onPressed: () => _remove(l),
                    child: Text('crm.quotes.links.remove'.tr(), style: const TextStyle(color: CrmColors.danger)),
                  ),
              ],
            ),
        if (widget.editable) ...[
          const SizedBox(height: 8),
          CrmField(
            label: 'crm.quotes.links.type_label'.tr(),
            child: CrmSelectField(
              value: _type,
              options: kCrmQuoteLinkTargetTypes
                  .map((t) => CrmSelectOption(value: t, label: crmQuoteLinkTypeLabel(t)))
                  .toList(),
              placeholder: 'crm.quotes.links.pick_type'.tr(),
              searchHint: null,
              onChanged: (s) => _setType(s.value),
            ),
          ),
          CrmField(
            label: 'crm.quotes.links.target'.tr(),
            child: Row(
              children: [
                Expanded(
                  child: CrmSelectField(
                    value: _target,
                    enabled: _type != null,
                    options: _options
                        .map(
                          (o) =>
                              CrmSelectOption(value: o.id, label: o.label, badge: o.badge, description: o.description),
                        )
                        .toList(),
                    placeholder: _loading ? 'crm.quotes.loading'.tr() : 'crm.quotes.links.pick_target'.tr(),
                    onChanged: (s) => setState(() => _target = s.value),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _type == null || _target == null ? null : _add,
                  child: Text('crm.quotes.links.add'.tr()),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// --- Tài liệu có sẵn đính kèm -----------------------------------------------------------------------------------------

String crmQuoteDocSourceLabel(String type) => 'crm.quotes.docs.source.$type'.tr();

/// Tài liệu tham chiếu của báo giá (web `QuoteDocumentReferences`): danh sách (tải, gỡ) và "Chọn từ tài liệu có sẵn".
class CrmQuoteDocumentReferences extends StatefulWidget {
  final String quoteId;
  final bool canWrite;
  const CrmQuoteDocumentReferences({super.key, required this.quoteId, required this.canWrite});

  @override
  State<CrmQuoteDocumentReferences> createState() => _CrmQuoteDocumentReferencesState();
}

class _CrmQuoteDocumentReferencesState extends State<CrmQuoteDocumentReferences> {
  final _repo = CrmQuotesRepository.instance;
  List<CrmQuoteDocumentItem> _refs = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await _repo.listDocumentReferences(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _refs = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.docs.load_error'));
    }
  }

  Future<void> _download(CrmQuoteDocumentItem ref) async {
    try {
      final url = await _repo.documentReferenceDownloadUrl(widget.quoteId, ref.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showCrmSnack(context, crmErrorMessage(e, 'crm.quotes.docs.download_error'), error: true);
    }
  }

  Future<void> _remove(CrmQuoteDocumentItem ref) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.quotes.docs.remove_confirm'.tr(),
      confirmLabel: 'crm.quotes.docs.remove'.tr(),
      danger: true,
    );
    if (!ok) return;
    try {
      final rows = await _repo.removeDocumentReference(widget.quoteId, ref.id);
      if (!mounted) return;
      setState(() => _refs = rows);
      showCrmSnack(context, 'crm.quotes.docs.removed'.tr());
    } catch (e) {
      if (mounted) showCrmSnack(context, crmErrorMessage(e, 'crm.quotes.docs.remove_error'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSectionTitle(
          'crm.quotes.docs.title'.tr(),
          trailing: widget.canWrite
              ? TextButton(
                  onPressed: () => showCrmSheet<void>(
                    context,
                    builder: (_) =>
                        _DocumentPicker(quoteId: widget.quoteId, onChanged: (rows) => setState(() => _refs = rows)),
                  ),
                  child: Text('crm.quotes.docs.pick'.tr()),
                )
              : null,
        ),
        if (_error != null) CrmBanner(message: _error!),
        if (_refs.isEmpty)
          Text('crm.quotes.docs.empty'.tr(), style: const TextStyle(fontSize: 12.5, color: CrmColors.muted))
        else
          for (final r in _refs)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.document.name}${r.document.sizeBytes == null || r.document.sizeBytes == 0 ? '' : ' (${formatCrmBytes(r.document.sizeBytes)})'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'crm.quotes.docs.source_line'.tr(
                            args: {'type': crmQuoteDocSourceLabel(r.source.entityType), 'label': r.source.label},
                          ),
                          style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'crm.quotes.docs.download'.tr(),
                    icon: const Icon(Icons.download_rounded, color: CrmColors.primary),
                    onPressed: () => _download(r),
                  ),
                  if (widget.canWrite)
                    IconButton(
                      tooltip: 'crm.quotes.docs.remove'.tr(),
                      icon: const Icon(Icons.link_off_rounded, color: CrmColors.danger),
                      onPressed: () => _remove(r),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _DocumentPicker extends StatefulWidget {
  final String quoteId;
  final ValueChanged<List<CrmQuoteDocumentItem>> onChanged;
  const _DocumentPicker({required this.quoteId, required this.onChanged});

  @override
  State<_DocumentPicker> createState() => _DocumentPickerState();
}

class _DocumentPickerState extends State<_DocumentPicker> {
  String _source = '';
  String _search = '';
  List<CrmQuoteDocumentItem>? _candidates;
  String? _error;
  String? _attaching;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_request;
    try {
      final rows = await CrmQuotesRepository.instance.listDocumentCandidates(
        widget.quoteId,
        sourceType: _source.isEmpty ? null : _source,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );
      if (!mounted || id != _request) return;
      setState(() {
        _candidates = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _candidates = const [];
        _error = crmErrorMessage(e, 'crm.quotes.docs.candidates_error');
      });
    }
  }

  Future<void> _attach(CrmQuoteDocumentItem c) async {
    setState(() => _attaching = c.document.id);
    try {
      final rows = await CrmQuotesRepository.instance.addDocumentReference(widget.quoteId, c.document.id);
      if (!mounted) return;
      widget.onChanged(rows);
      showCrmSnack(context, 'crm.quotes.docs.attached'.tr());
      setState(
        () => _candidates = _candidates?.map((x) => x.document.id == c.document.id ? x.markAttached() : x).toList(),
      );
    } catch (e) {
      if (mounted) setState(() => _error = crmErrorMessage(e, 'crm.quotes.docs.attach_error'));
    }
    if (!mounted) return;
    setState(() => _attaching = null);
  }

  @override
  Widget build(BuildContext context) {
    final list = _candidates;
    return CrmFormSheet(
      title: 'crm.quotes.docs.pick'.tr(),
      submitLabel: 'crm.quotes.docs.done'.tr(),
      cancelLabel: 'crm.common.close'.tr(),
      error: _error,
      onSubmit: () => Navigator.pop(context),
      children: [
        CrmField(
          label: 'crm.quotes.docs.source_label'.tr(),
          child: CrmSelectField(
            value: _source.isEmpty ? '_all' : _source,
            options: [
              CrmSelectOption(value: '_all', label: 'crm.quotes.docs.all_sources'.tr()),
              for (final t in kCrmQuoteDocumentSourceTypes) CrmSelectOption(value: t, label: crmQuoteDocSourceLabel(t)),
            ],
            onChanged: (s) {
              setState(() => _source = s.value == null || s.value == '_all' ? '' : s.value!);
              _load();
            },
          ),
        ),
        CrmField(
          label: 'crm.quotes.docs.search_label'.tr(),
          child: CrmSearchField(
            hint: 'crm.quotes.docs.search_hint'.tr(),
            onChanged: (q) {
              _search = q;
              _load();
            },
          ),
        ),
        if (list == null)
          const CrmStateView(loading: true)
        else if (list.isEmpty)
          Text('crm.quotes.docs.no_candidates'.tr(), style: const TextStyle(color: CrmColors.muted))
        else
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.document.name}${c.document.sizeBytes == null || c.document.sizeBytes == 0 ? '' : ' (${formatCrmBytes(c.document.sizeBytes)})'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${crmQuoteDocSourceLabel(c.source.entityType)}: ${c.source.label}',
                          style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                        ),
                      ],
                    ),
                  ),
                  c.attached
                      ? CrmStatusPill(label: 'crm.quotes.docs.already'.tr(), tone: CrmTone.success, dense: true)
                      : TextButton(
                          onPressed: _attaching == c.document.id ? null : () => _attach(c),
                          child: Text('crm.quotes.docs.attach'.tr()),
                        ),
                ],
              ),
            ),
      ],
    );
  }
}
