import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../screens/procedure/components/procedure_modals.dart';
import '../../../../screens/workspace/components/workspace_sheets.dart';
import '../../../../services/module_business_service.dart';
import '../../../../services/workspace_service.dart';
import '../../../../utils/app_toast.dart';

/// Liên kết từ phiếu sang module khác, như các link của web `voucher-detail-screen.tsx`:
/// dự án / công việc → trang dự án Workspace (`projectHref`), hồ sơ → hồ sơ quy trình (`/modules/procedure#workspace/<id>`).
class FinanceExternalLinks {
  FinanceExternalLinks._();

  /// Mở sheet chi tiết dự án Workspace. Không tải được (không có quyền, đã xoá...) thì báo lỗi.
  static Future<void> openWorkspaceProject(BuildContext context, String projectId) async {
    final service = WorkspaceService();
    final project = await service.getProjectDetail(projectId);
    if (!context.mounted) return;
    if (project == null) {
      AppToast.error(context, 'finance.links.project_failed'.tr());
      return;
    }
    showWorkspaceProjectDetailSheet(context, project: project, service: service);
  }

  /// Mở sheet chi tiết hồ sơ quy trình.
  static Future<void> openProcedureInstance(BuildContext context, String instanceId) async {
    final service = ModuleBusinessService();
    final instance = await service.getProcedureInstance(instanceId);
    if (!context.mounted) return;
    if (instance == null) {
      AppToast.error(context, 'finance.links.procedure_failed'.tr());
      return;
    }
    showProcedureDetailSheet(context: context, initialItem: instance, service: service, onDataChanged: () {});
  }
}

/// Chữ dạng liên kết (màu link, gạch chân) như `text-link hover:underline` của web.
class FinanceLinkText extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double fontSize;
  final FontWeight fontWeight;

  const FinanceLinkText(this.text, {super.key, this.onTap, this.fontSize = 13.5, this.fontWeight = FontWeight.w600});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: onTap == null ? const Color(0xFF0F172A) : const Color(0xFF1D4ED8),
      decoration: onTap == null ? null : TextDecoration.underline,
      decorationColor: const Color(0xFF1D4ED8),
    );
    final label = Text(text, style: style);
    return onTap == null ? label : InkWell(onTap: onTap, child: label);
  }
}
