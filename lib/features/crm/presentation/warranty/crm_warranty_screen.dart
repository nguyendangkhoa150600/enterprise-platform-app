import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/warranty/warranty_repository.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/warranty/crm_warranty_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_paging.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_warranty_labels.dart';
import 'crm_warranty_sheets.dart';

/// Bảo hành, đổi trả (web `warranty/warranty-page.tsx`): tra cứu hạn bảo hành theo serial, tiếp nhận yêu cầu, danh
/// sách yêu cầu trong phạm vi dữ liệu, kho bảo hành (quản trị bán hàng).
class CrmWarrantyScreen extends StatefulWidget {
  const CrmWarrantyScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmWarrantyScreen> createState() => _CrmWarrantyScreenState();
}

class _CrmWarrantyScreenState extends State<CrmWarrantyScreen> {
  String _q = '';
  String? _status;
  late final CrmPagedListController<CrmWarrantyCaseSummary> _list = CrmPagedListController(
    load: (page) => CrmWarrantyRepository.instance.listCases(q: _q, status: _status, page: page),
  );

  @override
  void initState() {
    super.initState();
    _list.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _list.removeListener(_changed);
    _list.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await CrmRoutes.openWarranty(context, id);
    if (mounted) _list.reload();
  }

  Future<void> _intake(List<String> serials) async {
    final id = await showCrmSheet<String>(context, builder: (_) => CrmWarrantyIntakeSheet(initialSerials: serials));
    if (id == null || !mounted) return;
    await _open(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.warranty.label),
      body: CrmPageGuard(
        view: CrmView.warranty,
        onAllowed: _list.reload,
        builder: (context, status) => _body(status.capabilities),
      ),
    );
  }

  Widget _body(CrmCapabilities caps) {
    final canWrite = crmCanWriteWarranty(caps);
    return RefreshIndicator(
      onRefresh: _list.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SerialLookup(canWrite: canWrite, onOpen: _open, onIntake: (serial) => _intake([serial])),
          Row(
            children: [
              if (canWrite)
                Expanded(
                  child: CrmButton(
                    label: 'crm.warranty.intake_button'.tr(),
                    icon: Icons.add_rounded,
                    onPressed: () => _intake(const []),
                  ),
                ),
              if (canWrite && caps.isManager) const SizedBox(width: 8),
              if (caps.isManager)
                Expanded(
                  child: CrmButton(
                    label: 'crm.warranty.settings_title'.tr(),
                    icon: Icons.settings_outlined,
                    outlined: true,
                    onPressed: () => showCrmSheet<void>(context, builder: (_) => const CrmWarrantySettingsSheet()),
                  ),
                ),
            ],
          ),
          if (canWrite || caps.isManager) const SizedBox(height: 12),
          CrmSearchField(
            hint: 'crm.warranty.search'.tr(),
            onChanged: (v) {
              _q = v.trim();
              _list.setKey('$_q|${_status ?? ''}');
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: CrmFilterChip(
              placeholder: 'crm.warranty.all_statuses'.tr(),
              value: _status,
              options: crmWarrantyOptions(kCrmWarrantyStatuses, crmWarrantyStatusLabel),
              onChanged: (v) {
                _status = v;
                _list.setKey('$_q|${_status ?? ''}');
              },
            ),
          ),
          const SizedBox(height: 10),
          if (_list.error != null) CrmBanner(message: _list.error!),
          if (_list.loading && _list.items.isEmpty)
            const CrmStateView(loading: true)
          else if (_list.items.isEmpty)
            CrmStateView(emptyText: 'crm.warranty.empty'.tr())
          else
            for (final c in _list.items) _CaseCard(item: c, onTap: () => _open(c.id)),
          CrmPagerBar.of(_list, noun: 'crm.warranty.noun'.tr()),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CrmWarrantyCaseSummary item;
  final VoidCallback onTap;
  const _CaseCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = item;
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CrmCodeBadge(c.code),
              CrmStatusPill(label: crmWarrantyStatusLabel(c.status), tone: crmWarrantyStatusTone(c.status)),
              if (c.chargeable) CrmStatusPill(label: 'crm.warranty.chargeable'.tr(), tone: CrmTone.warning),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${c.customerCode} - ${c.customerName}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CrmColors.text),
          ),
          const SizedBox(height: 4),
          CrmInfoRow(
            label: 'crm.warranty.col.serial'.tr(),
            value: c.serials.isNotEmpty ? c.serials.join(', ') : 'crm.warranty.lines'.tr(args: {'n': c.lineCount}),
          ),
          CrmInfoRow(label: 'crm.warranty.col.order'.tr(), value: c.orderCode ?? ''),
          CrmInfoRow(label: 'crm.warranty.col.cause'.tr(), value: crmWarrantyCauseLabel(c.cause)),
          CrmInfoRow(label: 'crm.warranty.col.assignee'.tr(), value: CrmScope.instance.personName(c.assigneeUserId)),
          CrmInfoRow(label: 'crm.warranty.col.created'.tr(), value: formatCrmDay(c.createdAt)),
        ],
      ),
    );
  }
}

/// Tra cứu hạn bảo hành theo serial (web `SerialLookup`).
class _SerialLookup extends StatefulWidget {
  final bool canWrite;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onIntake;
  const _SerialLookup({required this.canWrite, required this.onOpen, required this.onIntake});

  @override
  State<_SerialLookup> createState() => _SerialLookupState();
}

class _SerialLookupState extends State<_SerialLookup> {
  final TextEditingController _serial = TextEditingController();
  CrmWarrantyLookupItem? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final value = _serial.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'crm.warranty.error.serial_empty'.tr());
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await CrmWarrantyRepository.instance.lookup(serial: value);
      if (!mounted) return;
      setState(() {
        _result = items.isEmpty ? null : items.first;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _result = null;
        _loading = false;
        _error = crmErrorMessage(e, 'crm.warranty.error.lookup');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return CrmCard(
      title: 'crm.warranty.lookup_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serial,
                  maxLength: 100,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _lookup(),
                  decoration: crmInputDecoration(hint: 'crm.warranty.lookup_hint'.tr()).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              CrmButton(
                label: _loading ? 'crm.warranty.looking_up'.tr() : 'crm.warranty.lookup'.tr(),
                icon: Icons.search_rounded,
                outlined: true,
                busy: _loading,
                onPressed: _lookup,
              ),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 10), CrmBanner(message: _error!)],
          if (r != null) ...[
            const SizedBox(height: 8),
            CrmInfoRow(
              label: 'crm.warranty.col.serial'.tr(),
              value: '${r.serial ?? ''} · ${r.materialCode} ${r.materialName}',
            ),
            CrmInfoRow(label: 'crm.warranty.col.customer'.tr(), value: '${r.customerCode} - ${r.customerName}'),
            CrmInfoRow(
              label: 'crm.warranty.order_delivery'.tr(),
              value: [
                r.orderCode ?? '',
                if (r.deliveryCode != null) ' · ${r.deliveryCode}',
                if (r.contractCode != null) ' · ${'crm.warranty.contract'.tr(args: {'code': r.contractCode})}',
                if (r.replacementOfCaseCode != null)
                  ' · ${'crm.warranty.replacement_of'.tr(args: {'serial': r.replacementOfSerial ?? '', 'code': r.replacementOfCaseCode})}',
              ].join(),
            ),
            CrmInfoRow(
              label: 'crm.warranty.delivered_on'.tr(),
              value: formatCrmDay(r.coverage.deliveredOn).isEmpty
                  ? 'crm.warranty.unknown'.tr()
                  : formatCrmDay(r.coverage.deliveredOn),
            ),
            CrmInfoRow(
              label: 'crm.warranty.col.coverage'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrmStatusPill(
                    label: crmCoverageLabel(r.coverage),
                    tone: r.coverage.expired ? CrmTone.danger : CrmTone.success,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      crmWarrantySourceLabel(r.coverage.source),
                      if (r.coverage.months != null && r.coverage.months != 0)
                        'crm.warranty.months'.tr(args: {'n': r.coverage.months}),
                    ].join(', '),
                    style: const TextStyle(fontSize: 12, color: CrmColors.muted),
                  ),
                ],
              ),
            ),
            CrmInfoRow(
              label: 'crm.warranty.case'.tr(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: r.openCaseId != null
                    ? TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => widget.onOpen(r.openCaseId!),
                        child: Text('crm.warranty.open_case_exists'.tr()),
                      )
                    : widget.canWrite
                    ? CrmButton(
                        label: (r.coverage.expired ? 'crm.warranty.intake_chargeable' : 'crm.warranty.intake_button')
                            .tr(),
                        icon: Icons.add_rounded,
                        onPressed: () => widget.onIntake(r.serial ?? ''),
                      )
                    : Text(
                        'crm.warranty.no_open_case'.tr(),
                        style: const TextStyle(fontSize: 13, color: CrmColors.muted),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
