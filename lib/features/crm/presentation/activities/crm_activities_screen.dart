import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/activities/crm_activity_models.dart';
import '../../domain/common/crm_directory_models.dart';
import '../common/crm_page_guard.dart';
import '../common/crm_pickers.dart';
import '../common/crm_select.dart';
import '../common/crm_ui.dart';
import '../crm_nav.dart';
import '../utils/crm_scope.dart';
import 'crm_activity_panel.dart';

/// Trang "Hoạt động" (web `crm-screen.tsx ActivitiesPage`): hoạt động trong phạm vi dữ liệu, mặc định đang mở; lọc
/// theo người được giao. [focusId] mở sẵn một hoạt động (liên kết nhắc hạn `#activities/<id>`).
class CrmActivitiesScreen extends StatefulWidget {
  final String? focusId;
  const CrmActivitiesScreen({super.key, this.focusId});

  /// Màn đã dựng xong: `true` thì ô Trang chủ của trang này hiện (CrmRoutes.isReady).
  static const bool ready = true;

  @override
  State<CrmActivitiesScreen> createState() => _CrmActivitiesScreenState();
}

class _CrmActivitiesScreenState extends State<CrmActivitiesScreen> {
  final GlobalKey<CrmActivityPanelState> _panel = GlobalKey<CrmActivityPanelState>();
  String _assignee = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, CrmView.activities.label),
      body: CrmPageGuard(
        view: CrmView.activities,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () async => await _panel.currentState?.reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ValueListenableBuilder<List<CrmPerson>>(
                    valueListenable: CrmScope.instance.people,
                    builder: (context, people, _) => CrmFilterChip(
                      placeholder: 'crm.activities.all_assignees'.tr(),
                      value: _assignee,
                      options: crmPeopleOptions(people),
                      onChanged: (value) => setState(() => _assignee = value ?? ''),
                    ),
                  ),
                ),
              ),
              CrmActivityPanel(
                key: _panel,
                scope: CrmActivityScope(assigneeUserId: _assignee.isEmpty ? null : _assignee),
                focusId: widget.focusId,
                showTarget: true,
                defaultStatus: 'OPEN',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
