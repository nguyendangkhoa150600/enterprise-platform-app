import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/crm_capabilities.dart';
import '../crm_nav.dart';
import '../utils/crm_scope.dart';
import 'crm_state_views.dart';
import 'crm_ui.dart';

/// Tải trạng thái CRM rồi mới dựng [builder] (web `CrmScreen`):
/// - đang tải → vòng quay; chưa có quyền `crm.*` (403) → khung "Chưa được cấp quyền";
/// - lỗi tải → khung đỏ + "Thử lại"; dữ liệu tenant chưa khởi tạo (`tablesReady=false`) → khung chờ;
/// - [view] bị ẩn với quyền hiện tại (vd. Báo cáo khi thiếu `crm.report.read`) → khung chặn.
/// Đồng thời tải danh bạ/nhóm/phân loại khách một lần ([CrmScope.ensureDirectory]).
///
/// Dùng trong `body` của Scaffold màn CRM:
/// `body: CrmPageGuard(view: CrmView.leads, builder: (context, status) => _LeadsBody(caps: status.capabilities))`.
class CrmPageGuard extends StatefulWidget {
  /// Trang cần quyền; null: chỉ cần tải được trạng thái (màn chi tiết).
  final CrmView? view;
  final Widget Function(BuildContext context, CrmStatus status) builder;

  /// Gọi một lần khi trang lần đầu được phép hiển thị — để tải dữ liệu trang.
  final VoidCallback? onAllowed;

  const CrmPageGuard({super.key, required this.view, required this.builder, this.onAllowed});

  @override
  State<CrmPageGuard> createState() => _CrmPageGuardState();
}

class _CrmPageGuardState extends State<CrmPageGuard> {
  final CrmScope _scope = CrmScope.instance;
  bool _allowedNotified = false;

  @override
  void initState() {
    super.initState();
    _scope.ensureStatus();
    _scope.ensureDirectory();
  }

  void _retry() {
    _scope.error.value = null;
    _scope.ensureStatus(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _scope.denied,
      builder: (context, denied, _) => ValueListenableBuilder<String?>(
        valueListenable: _scope.error,
        builder: (context, error, _) => ValueListenableBuilder<CrmStatus?>(
          valueListenable: _scope.status,
          builder: (context, status, _) => _content(context, denied, error, status),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool denied, String? error, CrmStatus? status) {
    if (denied) {
      return CrmNoticeView(title: 'crm.common.access_denied_title'.tr(), message: 'crm.common.access_denied'.tr());
    }
    if (status == null) {
      if (error == null) return const CrmStateView(loading: true);
      return CrmNoticeView(danger: true, title: 'crm.common.status_error'.tr(), message: error, onRetry: _retry);
    }
    final view = widget.view;
    if (!status.tablesReady) {
      return CrmNoticeView(
        title: 'crm.common.provisioning'.tr(),
        message: [if (view != null) view.summary, 'crm.common.provisioning_page'.tr()].join('\n'),
        onRetry: _retry,
      );
    }
    if (view != null && !isCrmViewVisible(view, status.capabilities)) {
      return CrmNoticeView(title: 'crm.common.access_denied_title'.tr(), message: 'crm.common.page_no_access'.tr());
    }
    if (!_allowedNotified && widget.onAllowed != null) {
      _allowedNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAllowed!();
      });
    }
    return widget.builder(context, status);
  }
}

/// Màn tạm "đang phát triển" của một trang CRM chưa dựng (giai đoạn 2 thay bằng màn thật).
/// Ô Trang chủ của trang chưa sẵn sàng bị ẩn (`CrmRoutes.isReady`).
class CrmPlaceholderScreen extends StatelessWidget {
  final CrmView view;

  /// Tiêu đề phụ (vd. mã đối tượng đang mở).
  final String? subtitle;
  const CrmPlaceholderScreen({super.key, required this.view, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrmColors.bg,
      appBar: crmAppBar(context, view.label, subtitle: subtitle),
      body: CrmPageGuard(
        view: view,
        builder: (context, _) => CrmStateView(
          emptyIcon: Icons.construction_rounded,
          emptyText: '${view.summary}\n\n${'crm.common.in_development'.tr()}',
        ),
      ),
    );
  }
}
