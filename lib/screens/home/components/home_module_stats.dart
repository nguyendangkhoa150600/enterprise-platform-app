import '../../../models/inventory_models.dart';
import '../../../models/maintenance_models.dart';
import '../../../models/procedure_models.dart';
import '../../../services/module_business_service.dart';

/// Real figures for the home dashboard, aggregated from the procedure, maintenance and inventory APIs.
class HomeModuleStats {
  final List<ProcedureInstance> procedureInstances;
  final int publishedDefinitions;
  final List<MaintenanceSchedule> schedules;
  final List<MaintenanceIncident> incidents;
  final List<MaterialItem> materials;

  const HomeModuleStats({
    this.procedureInstances = const [],
    this.publishedDefinitions = 0,
    this.schedules = const [],
    this.incidents = const [],
    this.materials = const [],
  });

  List<ProcedureInstance> get running => procedureInstances.where((i) => i.status == 'running').toList();

  /// Running procedures the current user can act on.
  List<ProcedureInstance> get needAction =>
      running.where((i) => i.authorization?.availableActions.isNotEmpty == true).toList();

  int get openIncidents => incidents.where((i) => i.status != 'RESOLVED').length;
  int get activeSchedules => schedules.where((s) => s.status != 'COMPLETED').length;
  int get dueSchedules => schedules.where((s) => s.status == 'DUE' || s.status == 'OVERDUE').length;

  int get warehouseCount => materials.map((m) => m.warehouseName).where((n) => n.isNotEmpty).toSet().length;
  int get lowStockCount => materials.where((m) => m.status != 'NORMAL').length;

  /// Running procedures grouped by their current RACI stage (S, R, E, C, A, I).
  Map<String, int> get runningByStage {
    final byStage = <String, int>{};
    for (final inst in running) {
      byStage[inst.currentRole] = (byStage[inst.currentRole] ?? 0) + 1;
    }
    return byStage;
  }

  static Future<HomeModuleStats> load(ModuleBusinessService service) async {
    Future<T?> safe<T>(Future<T> f) async {
      try {
        return await f;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(service.getProcedureWorkspace()),
      safe(service.getMaintenanceSchedules()),
      safe(service.getMaintenanceIncidents()),
      safe(service.getInventoryMaterials()),
    ]);
    final ws = results[0] as ProcedureWorkspaceData?;
    return HomeModuleStats(
      procedureInstances: ws?.instances ?? const [],
      publishedDefinitions: ws?.definitions.where((d) => d.status == 'published').length ?? 0,
      schedules: (results[1] as List<MaintenanceSchedule>?) ?? const [],
      incidents: (results[2] as List<MaintenanceIncident>?) ?? const [],
      materials: (results[3] as List<MaterialItem>?) ?? const [],
    );
  }
}
