import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/opportunities/opportunities_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/opportunities/crm_opportunity_models.dart';
import '../../domain/opportunities/crm_opportunity_rules.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'sheets/crm_opportunity_form_sheet.dart';
import 'widgets/crm_my_stage_tasks.dart';
import 'widgets/crm_opportunity_board.dart';
import 'widgets/crm_opportunity_lists.dart';

enum _Mode { board, table, customers }

/// Dự án bán hàng (web `OpportunitiesPage`): Kanban (cột giai đoạn cuộn ngang, chuyển giai đoạn bằng nhấn giữ thẻ),
/// Dạng bảng, Theo khách hàng (mặc định); lọc tên, người phụ trách, luồng, giai đoạn; "Việc của tôi" ở đầu trang.
class CrmOpportunitiesScreen extends StatefulWidget {
  const CrmOpportunitiesScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmOpportunitiesScreen> createState() => _CrmOpportunitiesScreenState();
}

class _CrmOpportunitiesScreenState extends State<CrmOpportunitiesScreen> {
  _Mode _mode = _Mode.customers;
  String _q = '';
  String? _ownerUserId;
  String? _stage;
  String? _pipelineId;
  List<CrmPipeline> _pipelines = const [];
  bool _pipelinesLoaded = false;
  int _refresh = 0;

  Future<void> _loadPipelines() async {
    try {
      final rows = await OpportunitiesRepository.instance.listPipelines();
      if (!mounted) return;
      setState(() {
        _pipelines = rows;
        _pipelinesLoaded = true;
      });
    } catch (_) {
      // Như web `usePipelines`: lỗi tải thì danh sách rỗng.
      if (!mounted) return;
      setState(() {
        _pipelines = const [];
        _pipelinesLoaded = true;
      });
    }
  }

  CrmPipeline? get _boardPipeline =>
      CrmOpportunityRules.pipelineById(_pipelines, _pipelineId) ?? CrmOpportunityRules.defaultPipeline(_pipelines);

  Future<void> _open(String id) async {
    await CrmRoutes.openOpportunity(context, id);
    if (mounted) setState(() => _refresh++);
  }

  Future<void> _create() async {
    final saved = await showCrmOpportunityFormSheet(context);
    if (saved == null || !mounted) return;
    setState(() => _refresh++);
    await _open(saved.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.opportunities.label),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: CrmScope.instance.status,
        builder: (context, status, _) => (status?.capabilities.canWrite ?? false)
            ? FloatingActionButton.extended(
                backgroundColor: CrmColors.primary,
                foregroundColor: Colors.white,
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: Text('crm.opportunities.add'.tr()),
              )
            : const SizedBox.shrink(),
      ),
      body: CrmPageGuard(
        view: CrmView.opportunities,
        onAllowed: _loadPipelines,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(),
            CrmMyStageTasks(refresh: _refresh, onOpen: _open),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final board = _mode == _Mode.board;
    final pipelineOptions = _pipelines.map((p) => CrmSelectOption(value: p.id, label: p.name)).toList();
    final stageOptions = CrmOpportunityRules.stageFilterOptions(
      _pipelines,
      _pipelineId,
    ).map((e) => CrmSelectOption(value: e.key, label: e.value)).toList();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Mode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: CrmColors.primarySoft,
              selectedForegroundColor: CrmColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(value: _Mode.board, label: Text('crm.opportunities.mode.board'.tr())),
              ButtonSegment(value: _Mode.table, label: Text('crm.opportunities.mode.table'.tr())),
              ButtonSegment(value: _Mode.customers, label: Text('crm.opportunities.mode.customers'.tr())),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 10),
          CrmSearchField(
            initialValue: _q,
            hint: 'crm.opportunities.search'.tr(),
            debounce: const Duration(milliseconds: 350),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ValueListenableBuilder<List<CrmPerson>>(
                  valueListenable: CrmScope.instance.people,
                  builder: (context, people, _) => CrmFilterChip(
                    placeholder: 'crm.opportunities.filter.owner'.tr(),
                    value: _ownerUserId,
                    options: crmPeopleOptions(people),
                    onChanged: (v) => setState(() => _ownerUserId = v),
                  ),
                ),
                if (_pipelines.length > 1) ...[
                  const SizedBox(width: 8),
                  board
                      ? _boardPipelineChip(pipelineOptions)
                      : CrmFilterChip(
                          placeholder: 'crm.opportunities.filter.pipeline'.tr(),
                          value: _pipelineId,
                          options: pipelineOptions,
                          onChanged: (v) => setState(() {
                            _pipelineId = v;
                            _stage = null;
                          }),
                        ),
                ],
                if (!board) ...[
                  const SizedBox(width: 8),
                  CrmFilterChip(
                    placeholder: 'crm.opportunities.filter.stage'.tr(),
                    value: _stage,
                    options: stageOptions,
                    onChanged: (v) => setState(() => _stage = v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kanban luôn cần một luồng: không cho bỏ chọn (web `clearable={mode !== 'board'}`).
  Widget _boardPipelineChip(List<CrmSelectOption> options) {
    final current = _boardPipeline;
    return ActionChip(
      backgroundColor: CrmColors.primarySoft,
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      shape: const StadiumBorder(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              current?.name ?? 'crm.opportunities.filter.pipeline'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CrmColors.primary),
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 18, color: CrmColors.primary),
        ],
      ),
      onPressed: () async {
        final picked = await showCrmSelectSheet(
          context,
          title: 'crm.opportunities.filter.pipeline_title'.tr(),
          options: options,
          selected: current?.id,
        );
        if (picked?.value == null || !mounted) return;
        setState(() {
          _pipelineId = picked!.value;
          _stage = null;
        });
      },
    );
  }

  Widget _content() {
    final filter = CrmOpportunityFilter(q: _q, ownerUserId: _ownerUserId, stage: _stage, pipelineId: _pipelineId);
    switch (_mode) {
      case _Mode.board:
        return CrmOpportunityBoardView(
          q: _q,
          ownerUserId: _ownerUserId,
          pipeline: _boardPipeline,
          pipelinesLoaded: _pipelinesLoaded,
          refresh: _refresh,
          onOpen: _open,
        );
      case _Mode.table:
        return CrmOpportunityTableView(filter: filter, refresh: _refresh, onOpen: _open);
      case _Mode.customers:
        return CrmOpportunitiesByCustomerView(
          filter: filter,
          refresh: _refresh,
          onOpen: _open,
          onOpenCustomer: (id) => CrmRoutes.openCustomer(context, id),
        );
    }
  }
}
