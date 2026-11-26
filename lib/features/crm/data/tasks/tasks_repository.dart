import '../../domain/common/crm_json.dart';
import '../../domain/tasks/crm_task_models.dart';
import '../crm_api_client.dart';

/// Việc cần xử lý (web `crm-api.ts getMyTasks`).
class CrmTasksRepository {
  CrmTasksRepository._();
  static final CrmTasksRepository instance = CrmTasksRepository._();

  final CrmApiClient _api = CrmApiClient.instance;

  /// `GET /my-tasks`.
  Future<CrmTaskList> myTasks() async => CrmTaskList.fromJson(CrmJson.map(await _api.get('/my-tasks')));
}
