import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/procedure_models.dart';
import '../../../services/maintenance_incident_api.dart';
import '../../../services/module_business_service.dart';
import '../../maintenance/components/maintenance_incident_dialog.dart';
import '../../procedure/components/procedure_create_instance_dialog.dart';
import 'assistant_form_registry.dart';

// Form tạo của Bảo trì và Quy trình mà Trợ lý Savina mở với bản nháp (web `maintenance-assistant-form.tsx`,
// `procedure-assistant-form.tsx`). Form và API là của chính phân hệ; giá trị bản nháp chưa được tin: ô sai kiểu hay
// không có trong danh mục đang hiện thì bỏ qua để người dùng tự chọn.

const _maintenanceIncidentKey = 'maintenance.incident.create';
const _incidentPriorities = ['High', 'Normal', 'Low'];

String? _text(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

// ---------------------------------------------------------------------------------------------------------------
// Sự cố bảo trì (`maintenance.incident.create`, `CreateMaintenanceIncidentRequest`)

/// Web `incidentDraftToFormValues` (phần không cần danh mục; mã thiết bị, quy trình, người phụ trách được form kiểm
/// với danh mục sau khi nạp).
MaintenanceIncidentPrefill _incidentPrefill(Map<String, dynamic> draft) {
  final priority = _text(draft['priority'])?.toLowerCase();
  return MaintenanceIncidentPrefill(
    assetCode: _text(draft['assetCode']),
    title: _text(draft['title']),
    description: _text(draft['description']),
    priority: priority == null ? null : _incidentPriorities.where((p) => p.toLowerCase() == priority).firstOrNull,
    procedureDefinitionId: _text(draft['procedureDefinitionId']),
    assigneeId: _text(draft['assigneeId']),
  );
}

Future<AssistantFormResult> openAssistantIncidentForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async {
  // Không mở được form thì báo về card, không để người dùng nhập rồi mới bị chặn lúc lưu.
  final keys = await MaintenanceIncidentApi().assistantActionKeys();
  if (keys == null) return AssistantFormResult('unavailable', message: 'maintenance.assistant.load_failed'.tr());
  if (!keys.contains(_maintenanceIncidentKey)) {
    return AssistantFormResult('unavailable', message: 'maintenance.assistant.no_permission'.tr());
  }
  if (!context.mounted) return AssistantFormResult.cancelled;

  Map<String, dynamic>? created;
  await showDialog<bool>(
    context: context,
    builder: (_) => MaintenanceIncidentDialog(
      prefill: _incidentPrefill(draft),
      onCreated: (occurrence) => created ??= occurrence,
    ),
  );
  final occurrence = created;
  final id = occurrence?['id']?.toString() ?? '';
  if (occurrence == null || id.isEmpty) return AssistantFormResult.cancelled;
  final code = occurrence['code']?.toString() ?? '';
  final title = occurrence['title']?.toString() ?? '';
  return AssistantFormResult(
    'saved',
    id: id,
    label: code.isEmpty ? title : '$code · $title',
    href: '/modules/maintenance#history/${Uri.encodeComponent(id)}',
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Đơn / yêu cầu theo quy trình (`procedure.instance.create`, `ProcedureStartAssistantDraft`; quy trình qua `variant`)

/// Web `isoDateTime`: mốc đọc được thì giữ, đổi về giờ máy cho ô chọn giờ.
DateTime? _isoDateTime(dynamic value) {
  final raw = _text(value);
  return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
}

Future<AssistantFormResult> openAssistantProcedureForm(
  BuildContext context,
  Map<String, dynamic> draft,
  String? variant,
) async {
  final service = ModuleBusinessService();
  final workspace = await service.getProcedureWorkspace();
  if (workspace.permissions['canCreateInstances'] == false) {
    return AssistantFormResult('unavailable', message: 'procedure.assistant.no_permission'.tr());
  }
  final published = workspace.definitions.where((d) => d.status == 'published').toList();
  if (published.isEmpty) {
    return AssistantFormResult('unavailable', message: 'procedure.assistant.no_published'.tr());
  }
  final definitionId = _text(variant);
  if (definitionId != null && !published.any((d) => d.id == definitionId)) {
    return AssistantFormResult('unavailable', message: 'procedure.assistant.unknown_procedure'.tr());
  }
  if (!context.mounted) return AssistantFormResult.cancelled;

  ProcedureInstance? created;
  await showCreateProcedureInstanceDialog(
    context: context,
    definitions: published,
    service: service,
    onCreated: () {},
    initialDefinitionId: definitionId,
    initialTitle: _text(draft['title']),
    initialStartDueAt: _isoDateTime(draft['startDueAt']),
    initialEndDueAt: _isoDateTime(draft['endDueAt']),
    onCreatedInstance: (instance) => created ??= instance,
  );
  final instance = created;
  if (instance == null || instance.id.isEmpty) return AssistantFormResult.cancelled;
  return AssistantFormResult(
    'saved',
    id: instance.id,
    label: instance.code.isEmpty ? instance.title : '${instance.code} · ${instance.title}',
    href: '/modules/procedure#workspace/${Uri.encodeComponent(instance.id)}',
  );
}
