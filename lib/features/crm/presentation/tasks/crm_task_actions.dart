import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../screens/procedure/components/procedure_modals.dart';
import '../../../../services/module_business_service.dart';
import '../../domain/tasks/crm_task_models.dart';
import '../common/crm_ui.dart';
import '../crm_routes.dart';

/// Nhãn, màu và cách mở một việc (web `tasks.model.ts` + `openTask`).

/// Web `CRM_TASK_KIND_LABELS`.
String crmTaskKindLabel(String kind) => 'crm.tasks.kind.${kind.toLowerCase()}'.tr();

/// Web `TASK_KIND_TONE`.
CrmTone crmTaskKindTone(String kind) => switch (kind) {
  'QUOTE_APPROVAL' || 'BUSINESS_PLAN_APPROVAL' => CrmTone.warning,
  'QUOTE_REJECTED' || 'BUSINESS_PLAN_REJECTED' => CrmTone.danger,
  'QUOTE_READY_TO_SEND' => CrmTone.success,
  _ => CrmTone.info,
};

/// Web `taskActionLabel`.
String crmTaskActionLabel(CrmTask task) {
  if (task.isWaiting) {
    return (task.isBusinessPlan ? 'crm.tasks.action.open_plan' : 'crm.tasks.action.open_quote').tr();
  }
  if (task.approval?.procedureId != null) return 'crm.tasks.action.procedure'.tr();
  if (task.kind == 'QUOTE_APPROVAL' || task.kind == 'BUSINESS_PLAN_APPROVAL') {
    return 'crm.tasks.action.open_to_approve'.tr();
  }
  return (task.isBusinessPlan ? 'crm.tasks.action.open_plan' : 'crm.tasks.action.open_quote').tr();
}

/// Web `approvalModeText`.
String crmApprovalModeText(CrmTaskApprovalTarget? target) {
  if (target == null) return '';
  if (target.mode != 'PROCEDURE') return 'crm.tasks.mode.direct'.tr();
  final code = target.procedureInstanceCode;
  if (code != null && code.isNotEmpty) return 'crm.tasks.mode.procedure_code'.tr(args: {'code': code});
  return (target.procedureInstanceId != null && target.procedureInstanceId!.isNotEmpty)
      ? 'crm.tasks.mode.procedure'.tr()
      : 'crm.tasks.mode.procedure_creating'.tr();
}

/// Mở một việc (web `openTask` + `taskTarget`): duyệt qua Quy trình thì mở hồ sơ bên Quy trình; còn lại mở báo giá
/// (việc PAKD mở sẵn khối PAKD). [fromTasks] hiện nút quay về Việc cần xử lý trên màn báo giá. Future hoàn tất khi
/// màn / hồ sơ đã đóng (để người gọi tải lại, như Quy trình quay về `returnTo` trên web).
Future<void> openCrmTask(BuildContext context, CrmTask task, {bool fromTasks = true}) async {
  final procedureId = task.procedureTarget;
  if (procedureId != null) {
    final service = ModuleBusinessService();
    final instance = await service.getProcedureInstance(procedureId);
    if (!context.mounted) return;
    if (instance == null) {
      showCrmSnack(context, 'crm.tasks.procedure_failed'.tr(), error: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProcedureDetailSheetWidget(initialItem: instance, service: service, onDataChanged: () {}),
    );
    return;
  }
  await CrmRoutes.openQuote(
    context,
    task.quoteId,
    panel: task.isBusinessPlan ? 'business-plan' : null,
    fromTasks: fromTasks,
  );
}
