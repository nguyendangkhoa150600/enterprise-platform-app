import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/receivables/receivables_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/common/crm_page.dart';
import '../../domain/receivables/crm_receivable_models.dart';
import '../common/crm_dialogs.dart';
import '../common/crm_format.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pager.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_state_views.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../crm_routes.dart';
import '../utils/crm_scope.dart';
import 'crm_receivable_lists.dart';
import 'crm_receivables_labels.dart';

/// Công nợ (web `receivables/receivables-page.tsx`): tuổi nợ theo khách, lần thu tiền, điều chỉnh công nợ, cấu hình
/// (quản trị bán hàng). Chạm một khách để mở sổ công nợ.
class CrmReceivablesScreen extends StatelessWidget {
  const CrmReceivablesScreen({super.key});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.receivables.label),
      body: CrmPageGuard(
        view: CrmView.receivables,
        builder: (context, status) => _ReceivablesTabs(showSettings: status.capabilities.isManager),
      ),
    );
  }
}

class _ReceivablesTabs extends StatelessWidget {
  final bool showSettings;
  const _ReceivablesTabs({required this.showSettings});

  @override
  Widget build(BuildContext context) {
    void openLedger(String customerId) => CrmRoutes.openReceivables(context, customerId);
    final tabs = [
      'crm.receivables.tab.aging'.tr(),
      'crm.receivables.tab.receipts'.tr(),
      'crm.receivables.tab.adjustments'.tr(),
      if (showSettings) 'crm.receivables.tab.settings'.tr(),
    ];
    return DefaultTabController(
      key: ValueKey(showSettings),
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: CrmColors.primary,
              unselectedLabelColor: CrmColors.muted,
              indicatorColor: CrmColors.primary,
              tabs: [for (final t in tabs) Tab(text: t)],
            ),
          ),
          const Divider(height: 1, color: CrmColors.border),
          Expanded(
            child: TabBarView(
              children: [
                _AgingTab(onOpenCustomer: openLedger),
                _ScrollTab(
                  builder: (key) => CrmReceiptsSection(key: key, onTap: (r) => openLedger(r.customerId)),
                ),
                _ScrollTab(
                  builder: (key) => CrmAdjustmentsSection(key: key, onOpenCustomer: openLedger),
                ),
                if (showSettings) const _SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung cuộn + kéo làm mới cho danh sách tự phân trang (lần thu, điều chỉnh).
class _ScrollTab extends StatefulWidget {
  final Widget Function(GlobalKey key) builder;
  const _ScrollTab({required this.builder});

  @override
  State<_ScrollTab> createState() => _ScrollTabState();
}

class _ScrollTabState extends State<_ScrollTab> with AutomaticKeepAliveClientMixin {
  final GlobalKey _key = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final state = _key.currentState;
    if (state is CrmReceiptsSectionState) await state.reload();
    if (state is CrmAdjustmentsSectionState) await state.reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [widget.builder(_key)],
      ),
    );
  }
}

/// Tuổi nợ theo khách (web `AgingTable`): tìm, người phụ trách, chỉ khách có nợ đến hạn/quá hạn; tải tối đa 500 dòng
/// rồi phân trang tại chỗ như web.
class _AgingTab extends StatefulWidget {
  final ValueChanged<String> onOpenCustomer;
  const _AgingTab({required this.onOpenCustomer});

  @override
  State<_AgingTab> createState() => _AgingTabState();
}

class _AgingTabState extends State<_AgingTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  String? _owner;
  bool _overdue = false;
  List<CrmCustomerAgingRow> _rows = const [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final page = await CrmReceivablesRepository.instance.loadAging(q: _q, ownerUserId: _owner, overdue: _overdue);
      if (!mounted || id != _request) return;
      setState(() {
        _rows = page.items;
        _error = null;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted || id != _request) return;
      setState(() {
        _error = crmErrorMessage(e, 'crm.receivables.error.aging');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final total = _rows.fold<double>(0, (sum, r) => sum + r.balance);
    final start = (_page - 1) * kCrmListPageSize;
    final visible = _rows.skip(start).take(kCrmListPageSize).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CrmSearchField(
            hint: 'crm.receivables.aging_search'.tr(),
            onChanged: (v) {
              _q = v.trim();
              _load();
            },
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<List<CrmPerson>>(
            valueListenable: CrmScope.instance.people,
            builder: (context, people, _) => Align(
              alignment: Alignment.centerLeft,
              child: CrmFilterChip(
                placeholder: 'crm.receivables.all_owners'.tr(),
                value: _owner,
                options: crmPeopleOptions(people),
                onChanged: (v) {
                  _owner = v;
                  _load();
                },
              ),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _overdue,
            activeThumbColor: CrmColors.primary,
            title: Text('crm.receivables.overdue_only'.tr(), style: const TextStyle(fontSize: 13)),
            onChanged: (v) {
              setState(() => _overdue = v);
              _load();
            },
          ),
          Text(
            'crm.receivables.total_balance'.tr(args: {'amount': formatCrmMoney(total)}),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CrmColors.body),
          ),
          const SizedBox(height: 10),
          if (_error != null) CrmBanner(message: _error!),
          if (_loading && _rows.isEmpty)
            const CrmStateView(loading: true)
          else if (_rows.isEmpty)
            CrmStateView(emptyText: 'crm.receivables.aging_empty'.tr())
          else ...[
            for (final row in visible) _AgingCard(row: row, onTap: () => widget.onOpenCustomer(row.customerId)),
            CrmPagerBar(
              page: _page,
              total: _rows.length,
              pageSize: kCrmListPageSize,
              noun: 'crm.receivables.noun_customer'.tr(),
              alwaysShowSummary: false,
              onChanged: (p) => setState(() => _page = p),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgingCard extends StatelessWidget {
  final CrmCustomerAgingRow row;
  final VoidCallback onTap;
  const _AgingCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String money(double v) => v == 0 ? '' : formatCrmMoney(v);
    return CrmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CrmCodeBadge(row.customerCode),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.customerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CrmColors.text),
                ),
              ),
            ],
          ),
          if (row.creditExceeded) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: CrmStatusPill(label: 'crm.receivables.credit_exceeded'.tr(), tone: CrmTone.danger),
            ),
          ],
          const SizedBox(height: 4),
          CrmInfoRow(
            label: 'crm.receivables.col.balance'.tr(),
            child: Text(
              formatCrmMoney(row.balance),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: CrmColors.text),
            ),
          ),
          CrmInfoRow(label: 'crm.receivables.col.credit_limit'.tr(), value: crmCreditLimitText(row.creditLimit)),
          for (final bucket in kCrmAgingBuckets)
            if (row.buckets[bucket] != 0)
              CrmInfoRow(
                label: crmAgingBucketLabel(bucket),
                child: Text(
                  money(row.buckets[bucket]),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: bucket == 'D90_PLUS' ? CrmColors.danger : CrmColors.text,
                  ),
                ),
              ),
          CrmInfoRow(label: 'crm.receivables.col.owner'.tr(), value: CrmScope.instance.personName(row.ownerUserId)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('crm.receivables.open_ledger'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cấu hình công nợ (web `ReceivableSettingsPanel`, chỉ quản trị bán hàng).
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> with AutomaticKeepAliveClientMixin {
  CrmReceivableSettings? _settings;
  String _mode = 'APPROVAL';
  List<String> _userIds = [];
  bool _saving = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await CrmReceivablesRepository.instance.loadSettings();
      if (!mounted) return;
      setState(() {
        _settings = next;
        _mode = next.creditLimitMode;
        _userIds = [...next.alertUserIds];
        _error = null;
      });
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() => _error = crmErrorMessage(e, 'crm.receivables.error.settings_load'));
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final next = await CrmReceivablesRepository.instance.saveSettings(creditLimitMode: _mode, alertUserIds: _userIds);
      if (!mounted) return;
      setState(() {
        _settings = next;
        _saving = false;
      });
      showCrmSnack(context, 'crm.receivables.toast.settings_saved'.tr());
    } catch (e) {
      CrmScope.instance.onError(e);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = crmErrorMessage(e, 'crm.receivables.error.settings_save');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_settings == null) {
      return _error != null ? CrmStateView(error: _error, onRetry: _load) : const CrmStateView(loading: true);
    }
    final scope = CrmScope.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CrmCard(
          title: 'crm.receivables.settings_title'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CrmField(
                label: 'crm.receivables.field.recognition'.tr(),
                hint: 'crm.receivables.field.recognition_hint'.tr(),
                child: TextFormField(
                  enabled: false,
                  initialValue: 'crm.receivables.recognition_on_delivery'.tr(),
                  decoration: crmInputDecoration(),
                ),
              ),
              CrmField(
                label: 'crm.receivables.field.credit_mode'.tr(),
                hint: 'crm.receivables.field.credit_mode_hint'.tr(),
                child: CrmSelectField(
                  value: _mode,
                  options: crmOptionsOf(kCrmCreditLimitModes, crmCreditLimitModeLabel),
                  onChanged: (s) => setState(() => _mode = s.value ?? 'APPROVAL'),
                ),
              ),
              ValueListenableBuilder<List<CrmPerson>>(
                valueListenable: scope.people,
                builder: (context, people, _) => CrmField(
                  label: 'crm.receivables.field.alert_users'.tr(),
                  hint: 'crm.receivables.field.alert_users_hint'.tr(),
                  child: CrmSelectField(
                    value: null,
                    options: crmPeopleOptions(people).where((o) => !_userIds.contains(o.value)).toList(),
                    placeholder: 'crm.receivables.add_recipient'.tr(),
                    onChanged: (s) {
                      final v = s.value;
                      if (v != null && !_userIds.contains(v)) setState(() => _userIds = [..._userIds, v]);
                    },
                  ),
                ),
              ),
              if (_userIds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in _userIds)
                      InputChip(
                        label: Text(scope.personName(id), style: const TextStyle(fontSize: 12.5)),
                        backgroundColor: CrmColors.primarySoft,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        deleteButtonTooltipMessage: 'crm.receivables.remove_recipient'.tr(
                          args: {'name': scope.personName(id)},
                        ),
                        onDeleted: () => setState(() => _userIds = _userIds.where((u) => u != id).toList()),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              if (_error != null) CrmBanner(message: _error!),
              CrmButton(
                label: _saving ? 'crm.common.saving'.tr() : 'crm.receivables.save_settings'.tr(),
                busy: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
