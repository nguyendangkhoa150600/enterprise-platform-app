import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/opportunities/opportunities_repository.dart';
import '../../../domain/opportunities/crm_opportunity_models.dart';
import '../../../domain/opportunities/crm_opportunity_rules.dart';
import '../../common/crm_dialogs.dart';
import '../../common/crm_select.dart';
import '../../common/crm_state_views.dart';
import '../../common/crm_ui.dart';
import '../../utils/crm_scope.dart';
import 'crm_opportunity_labels.dart';

/// Khuyến mãi của dự án (web `OpportunityPromotionsPanel`): lựa chọn lấy từ danh mục Cài đặt; báo giá của dự án chọn
/// lại từ tập này. Thêm, bỏ chỉ khi [canEdit]; server vẫn kiểm quyền.
class CrmOpportunityPromotionsSection extends StatefulWidget {
  final String opportunityId;
  final bool canEdit;
  const CrmOpportunityPromotionsSection({super.key, required this.opportunityId, required this.canEdit});

  @override
  State<CrmOpportunityPromotionsSection> createState() => _CrmOpportunityPromotionsSectionState();
}

class _CrmOpportunityPromotionsSectionState extends State<CrmOpportunityPromotionsSection> {
  final OpportunitiesRepository _repo = OpportunitiesRepository.instance;
  final TextEditingController _note = TextEditingController();
  List<CrmOpportunityPromotion> _items = const [];
  List<CrmPromotionCatalogItem> _catalog = const [];
  String? _catalogId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant CrmOpportunityPromotionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opportunityId != widget.opportunityId) _reload();
    if (!oldWidget.canEdit && widget.canEdit) _loadCatalog();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final rows = await _repo.listPromotions(widget.opportunityId);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.opportunities.promotions.load_failed'));
    }
  }

  Future<void> _loadCatalog() async {
    if (!widget.canEdit) return;
    try {
      final rows = await _repo.listPromotionCatalog();
      if (mounted) setState(() => _catalog = rows);
    } catch (_) {
      // Lỗi tải danh mục chỉ làm trống ô chọn (như web).
      if (mounted) setState(() => _catalog = const []);
    }
  }

  Future<void> _add() async {
    final catalogId = _catalogId;
    if (catalogId == null || catalogId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final rows = await _repo.addPromotion(
        widget.opportunityId,
        catalogId: catalogId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _catalogId = null;
        _note.clear();
        _busy = false;
      });
      showCrmSnack(context, 'crm.opportunities.promotions.added'.tr());
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _busy = false);
      showCrmSnack(context, crmErrorMessage(e, 'crm.opportunities.promotions.add_failed'), error: true);
    }
  }

  Future<void> _remove(String linkId) async {
    final ok = await showCrmConfirm(
      context,
      title: 'crm.opportunities.promotions.remove_confirm'.tr(),
      confirmLabel: 'crm.opportunities.promotions.remove_ok'.tr(),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      final rows = await _repo.removePromotion(widget.opportunityId, linkId);
      if (!mounted) return;
      setState(() => _items = rows);
      showCrmSnack(context, 'crm.opportunities.promotions.removed'.tr());
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      showCrmSnack(context, crmErrorMessage(e, 'crm.opportunities.promotions.remove_failed'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final options = CrmOpportunityRules.selectableCatalog(_catalog, _items.map((i) => i.catalog.id).toSet())
        .map(
          (i) => CrmSelectOption(
            value: i.id,
            label: i.name,
            badge: i.code,
            description: '${crmPromotionKindLabel(i.kind)} · ${crmPromotionValueLabel(i)}',
          ),
        )
        .toList();
    return CrmCard(
      title: 'crm.opportunities.promotions.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('crm.opportunities.promotions.not_deducted'.tr(), style: crmOppMuted),
          const SizedBox(height: 8),
          if (_error != null) CrmBanner(message: _error!, margin: const EdgeInsets.only(bottom: 8)),
          if (_items.isEmpty) Text('crm.opportunities.promotions.empty'.tr(), style: crmOppMuted),
          for (final item in _items)
            CrmOppTimelineItem(
              title: Text('${item.catalog.name} (${item.catalog.code})', style: crmOppTitle),
              lines: [
                Text(
                  [
                    crmPromotionKindLabel(item.catalog.kind),
                    crmPromotionValueLabel(item.catalog),
                    crmPromotionStateLabel(item.catalog, today),
                    if (item.note != null && item.note!.isNotEmpty) item.note!,
                  ].join(' · '),
                  style: crmOppMuted,
                ),
              ],
              trailing: widget.canEdit
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: CrmColors.danger),
                        onPressed: () => _remove(item.id),
                        child: Text('crm.opportunities.promotions.remove'.tr()),
                      ),
                    )
                  : null,
            ),
          if (widget.canEdit) ...[
            const SizedBox(height: 8),
            CrmField(
              label: 'crm.opportunities.promotions.pick_label'.tr(),
              child: CrmSelectField(
                value: _catalogId,
                options: options,
                placeholder: 'crm.opportunities.promotions.pick_placeholder'.tr(),
                emptyText: 'crm.opportunities.promotions.pick_empty'.tr(),
                onChanged: (s) => setState(() => _catalogId = s.value),
              ),
            ),
            CrmField(
              label: 'crm.opportunities.promotions.note'.tr(),
              child: TextField(controller: _note, maxLength: 500, decoration: crmInputDecoration()),
            ),
            CrmButton(
              label: 'crm.opportunities.promotions.add'.tr(),
              outlined: true,
              busy: _busy,
              onPressed: (_catalogId == null || _catalogId!.isEmpty) ? null : _add,
            ),
          ],
        ],
      ),
    );
  }
}
