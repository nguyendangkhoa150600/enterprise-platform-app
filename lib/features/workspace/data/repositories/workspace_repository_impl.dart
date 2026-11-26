import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/platform_models.dart';
import '../../../../models/workspace_models.dart';
import '../../../../services/platform_service.dart';
import '../../../../utils/user_resolver.dart';
import '../../domain/repositories/i_workspace_repository.dart';
import '../../domain/models/workspace_report_models.dart';
import '../datasources/workspace_remote_datasource.dart';

part 'workspace_repository_chat_reports.dart';

/// Triển khai IWorkspaceRepository theo chuẩn 76 API trong workspace-api-for-app.docx
/// Phụ thuộc vào WorkspaceRemoteDataSource (DIP), lấy dữ liệu thật 100% từ backend Savina ERP
class WorkspaceRepositoryImpl with _WorkspaceChatReportsRepository implements IWorkspaceRepository {
  @override
  final WorkspaceRemoteDataSource _remoteDataSource;
  final PlatformService _platformService;
  String? _lastError;
  Map<String, dynamic>? _lastCreated;

  @override
  String? get lastError => _lastError;

  @override
  Map<String, dynamic>? get lastCreated => _lastCreated;

  /// Bản ghi vừa tạo trong phản hồi (web `WorkItem`, hoặc `StandaloneTaskDetail.task` khi có [key]).
  static Map<String, dynamic>? _createdRecord(dynamic data, [String? key]) {
    if (data is! Map) return null;
    final inner = key != null && data[key] is Map ? data[key] : (data['data'] is Map ? data['data'] : data);
    return Map<String, dynamic>.from(inner as Map);
  }

  /// Thành công khi 2xx; không thì giữ lời nhắn lỗi của server (`{code, message}`) ở [lastError]
  /// để giao diện hiện đúng lý do như web, thay vì một câu chung chung.
  @override
  bool _ok(Response res) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      _lastError = null;
      return true;
    }
    _lastError = _serverMessage(res.data);
    return false;
  }

  @override
  bool _fail(Object e) {
    _lastError = e is DioException ? _serverMessage(e.response?.data) : null;
    return false;
  }

  static String? _serverMessage(dynamic data) {
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  WorkspaceRepositoryImpl({WorkspaceRemoteDataSource? remoteDataSource, PlatformService? platformService})
      : _remoteDataSource = remoteDataSource ?? WorkspaceRemoteDataSource(),
        _platformService = platformService ?? PlatformService();

  static List<CustomerItem> getFallbackCustomers() => const [];
  static List<ProjectItem> getFallbackProjects([Map<String, String>? customerMap]) => const [];

  @override
  Future<List<CustomerItem>> getCustomers({String? query}) async {
    try {
      final raw = await _remoteDataSource.getCustomersRaw(query: query);
      if (raw != null) {
        dynamic items = raw;
        if (items is Map) {
          items = items['data'] ?? items['items'] ?? items['customers'] ?? items['rows'] ?? items;
        }
        if (items is List) {
          return items.map((e) => CustomerItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getCustomers error: $e');
    }
    return [];
  }

  @override
  Future<List<ContractItem>> getCustomerContracts(String customerId, {Map<String, String>? projectMap}) async {
    try {
      final raw = await _remoteDataSource.getCustomerContractsRaw(customerId);
      if (raw != null) {
        dynamic items = raw;
        if (items is Map) {
          items = items['data'] ?? items['items'] ?? items['contracts'] ?? items['rows'] ?? items;
        }
        if (items is List) {
          return items.map((e) => ContractItem.fromJson(Map<String, dynamic>.from(e as Map), projectMap)).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getCustomerContracts error: $e');
    }
    return [];
  }

  @override
  Future<CustomerItem?> createCustomer({
    required String code,
    required String name,
    String? note,
  }) async {
    try {
      final raw = await _remoteDataSource.createCustomerRaw(code: code, name: name, note: note);
      if (raw != null) {
        final data = raw is Map ? (raw['data'] ?? raw) : null;
        if (data is Map) {
          return CustomerItem.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] createCustomer error: $e');
    }
    return null;
  }

  @override
  Future<List<ProjectItem>> getProjects({
    Map<String, String>? customerMap,
    String? search,
    String? status,
    String? projectType,
    String? archived = 'exclude',
    int? page,
    int? pageSize,
  }) async {
    try {
      if (page != null) {
        final raw = await _remoteDataSource.getProjectsRaw(
          search: search,
          status: status,
          projectType: projectType,
          archived: archived,
          page: page,
          pageSize: pageSize ?? 60,
        );
        return _extractProjectsList(raw, customerMap);
      }

      // Lấy trang 1 với pageSize 60
      final firstRaw = await _remoteDataSource.getProjectsRaw(
        search: search,
        status: status,
        projectType: projectType,
        archived: archived,
        page: 1,
        pageSize: 60,
      );

      final List<ProjectItem> list = _extractProjectsList(firstRaw, customerMap);

      // Đọc tổng số dự án từ response chuẩn Paged: { items: [...], total: 194, page: 1, pageSize: 60 }
      int total = 0;
      if (firstRaw is Map) {
        final totalVal = firstRaw['total'] ?? (firstRaw['data'] is Map ? firstRaw['data']['total'] : null);
        if (totalVal is num) total = totalVal.toInt();
      }

      // Nếu còn các trang sau (ví dụ 194 dự án gồm 4 trang), fetch song song để lấy trọn vẹn 100% dữ liệu
      if (total > list.length) {
        final totalPages = (total / 60).ceil();
        final futures = <Future<dynamic>>[];
        for (int p = 2; p <= totalPages; p++) {
          futures.add(_remoteDataSource.getProjectsRaw(
            search: search,
            status: status,
            projectType: projectType,
            archived: archived,
            page: p,
            pageSize: 60,
          ));
        }
        final results = await Future.wait(futures);
        for (final res in results) {
          list.addAll(_extractProjectsList(res, customerMap));
        }
      }

      return list;
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjects error: $e');
    }
    return [];
  }

  List<ProjectItem> _extractProjectsList(dynamic raw, Map<String, String>? customerMap) {
    if (raw == null) return [];
    dynamic items = raw;
    if (items is Map) {
      items = items['data'] ?? items['items'] ?? items['projects'] ?? items['rows'] ?? items;
      if (items is Map) {
        items = items['items'] ?? items['projects'] ?? items['data'] ?? items['rows'] ?? items;
      }
    }
    if (items is List) {
      return items.map((e) => ProjectItem.fromJson(Map<String, dynamic>.from(e as Map), customerMap)).toList();
    }
    return [];
  }

  @override
  Future<ProjectItem?> getProjectDetail(String id, {Map<String, String>? customerMap}) async {
    try {
      final raw = await _remoteDataSource.getProjectDetailRaw(id);
      if (raw != null) {
        final data = raw is Map ? (raw['data'] ?? raw) : null;
        if (data is Map) {
          return ProjectItem.fromJson(Map<String, dynamic>.from(data), customerMap);
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectDetail error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> createProject({
    required String name,
    required String code,
    String? description,
    String? projectType,
    String? customerId,
    String? startDate,
    String? endDate,
    double? contractValue,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name.trim(),
        'code': code.trim(),
      };
      if (description != null) payload['description'] = description.trim();
      if (projectType != null) payload['projectType'] = projectType;
      if (customerId != null) payload['customerId'] = customerId;
      if (startDate != null) payload['startDate'] = startDate;
      if (endDate != null) payload['endDate'] = endDate;
      if (contractValue != null) payload['contractValue'] = contractValue;

      final res = await _remoteDataSource.createProjectRaw(payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return res.data is Map ? Map<String, dynamic>.from(res.data) : {'status': 'ok'};
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] createProject error: $e');
    }
    return null;
  }

  @override
  Future<bool> updateProject(String id, Map<String, dynamic> data) async {
    try {
      final res = await _remoteDataSource.updateProjectRaw(id, data);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateProject error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateProjectStatus(String id, String status) async {
    try {
      final res = await _remoteDataSource.updateProjectStatusRaw(id, status);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateProjectStatus error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> deleteProject(String id) async {
    try {
      final res = await _remoteDataSource.deleteProjectRaw(id);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] deleteProject error: $e');
      return _fail(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getMyWork({Map<String, String>? customerMap}) async {
    try {
      final raw = await _remoteDataSource.getMyWorkRaw();
      if (raw != null && raw is Map) {
        final data = raw['data'] ?? raw;
        final itemsRaw = data['items'];
        final countersRaw = data['counters'];
        final standaloneRaw = data['standaloneTasks'];

        final List<ProjectItem> projects = [];
        final List<StandaloneTaskItem> standaloneTasks = [];

        if (standaloneRaw is List) {
          standaloneTasks.addAll(standaloneRaw.map((e) => StandaloneTaskItem.fromJson(Map<String, dynamic>.from(e as Map))));
        }

        if (itemsRaw is List && itemsRaw.isNotEmpty) {
          final Map<String, List<StandaloneTaskItem>> projectTasksMap = {};
          final Map<String, String> projectCodeMap = {};
          final Map<String, String> projectNameMap = {};

          for (final entry in itemsRaw) {
            if (entry is Map) {
              final itemData = entry['item'] is Map ? entry['item'] as Map<String, dynamic> : Map<String, dynamic>.from(entry);
              final pId = itemData['projectId']?.toString() ?? entry['projectId']?.toString() ?? '';
              final pCode = entry['projectCode']?.toString() ?? itemData['projectCode']?.toString() ?? pId;
              final pName = entry['projectName']?.toString() ?? itemData['projectName']?.toString() ?? pCode;

              final itemWithProject = Map<String, dynamic>.from(itemData);
              itemWithProject['projectId'] = pId;
              itemWithProject['projectCode'] = pCode;
              itemWithProject['projectName'] = pName;
              final task = StandaloneTaskItem.fromJson(itemWithProject);
              projectTasksMap.putIfAbsent(pId, () => []).add(task);
              projectCodeMap[pId] = pCode;
              projectNameMap[pId] = pName;
            }
          }

          projectTasksMap.forEach((pId, taskList) {
            projects.add(ProjectItem(
              id: pId,
              code: projectCodeMap[pId] ?? pId,
              name: projectNameMap[pId] ?? pId,
              status: 'active',
              tasks: taskList,
              totalItems: taskList.length,
            ));
          });
        }

        return {
          'projects': projects,
          'standaloneTasks': standaloneTasks,
          'openTasks': countersRaw is Map && countersRaw['open'] != null
              ? CustomerItem.parseInt(countersRaw['open'])
              : (projects.fold<int>(0, (s, p) => s + p.tasks.length) + standaloneTasks.length),
          'completedThisWeek': countersRaw is Map && countersRaw['completedThisWeek'] != null
              ? CustomerItem.parseInt(countersRaw['completedThisWeek'])
              : 0,
        };
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getMyWork error: $e');
    }

    return {
      'projects': <ProjectItem>[],
      'standaloneTasks': <StandaloneTaskItem>[],
      'openTasks': 0,
      'completedThisWeek': 0,
    };
  }

  @override
  Future<List<StandaloneTaskItem>> getProjectWorkItems(String projectId) async {
    try {
      final raw = await _remoteDataSource.getProjectWorkItemsRaw(projectId);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is Map) {
          items = items['items'] ?? items['data'] ?? items['tasks'] ?? items['workItems'] ?? items;
        }
        if (items is List) {
          return items.map((e) {
            final tMap = Map<String, dynamic>.from(e as Map);
            tMap['projectId'] ??= projectId;
            return StandaloneTaskItem.fromJson(tMap);
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectWorkItems error: $e');
    }
    return [];
  }

  @override
  Future<bool> createWorkItem({
    required String projectId,
    required String title,
    String? description,
    String priority = 'normal',
    String itemType = 'task',
    String? assigneeUserId,
    String? startDate,
    String? dueDate,
    double? estimatedHours,
    String? parentId,
    String? executionType,
    List<String>? participantUserIds,
    String? progressMethod,
    double? quantityTarget,
    String? quantityUnit,
    bool? equalChildWeight,
    List<String>? tagIds,
    List<String>? checklistTitles,
    String? procedureDefinitionId,
    Map<String, dynamic>? completion,
    String? reopenPolicy,
    bool reopenParent = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'projectId': projectId,
        'title': title.trim(),
        'priority': priority,
        'itemType': itemType,
      };
      if (description != null && description.trim().isNotEmpty) payload['description'] = description.trim();
      if (assigneeUserId != null && assigneeUserId.isNotEmpty) payload['assigneeUserId'] = assigneeUserId;
      if (participantUserIds != null && participantUserIds.isNotEmpty) {
        payload['participantUserIds'] = participantUserIds;
      }
      if (executionType != null && executionType.isNotEmpty) {
        payload['executionType'] = executionType;
      }
      if (progressMethod != null && progressMethod.isNotEmpty) {
        payload['progressMethod'] = progressMethod;
      }
      if (quantityTarget != null && quantityTarget > 0) {
        payload['quantityTarget'] = quantityTarget;
      }
      if (quantityUnit != null && quantityUnit.trim().isNotEmpty) {
        payload['quantityUnit'] = quantityUnit.trim();
      }
      if (equalChildWeight != null) {
        payload['equalChildWeight'] = equalChildWeight;
      }
      if (tagIds != null && tagIds.isNotEmpty) {
        payload['tagIds'] = tagIds;
      }
      if (checklistTitles != null && checklistTitles.isNotEmpty) {
        payload['checklistTitles'] = checklistTitles;
      }
      if (procedureDefinitionId != null && procedureDefinitionId.isNotEmpty) {
        payload['procedureDefinitionId'] = procedureDefinitionId;
      }
      if (completion != null) {
        payload['completion'] = completion;
      }
      if (reopenPolicy != null && reopenPolicy.isNotEmpty) {
        payload['reopenPolicy'] = reopenPolicy;
      }
      if (reopenParent) payload['reopenParent'] = true;
      if (startDate != null && startDate.isNotEmpty) payload['plannedStart'] = startDate;
      if (dueDate != null && dueDate.isNotEmpty) {
        payload['dueDate'] = dueDate;
        payload['plannedEnd'] = dueDate;
      }
      if (itemType == 'phase') {
        payload.remove('assigneeUserId');
        payload.remove('participantUserIds');
        payload.remove('estimatedHours');
        payload.remove('estimateHours');
        payload.remove('completion');
        payload.remove('reopenPolicy');
        payload['executionType'] = 'manual';
      } else {
        if (estimatedHours != null && estimatedHours > 0) {
          payload['estimatedHours'] = estimatedHours;
          payload['estimateHours'] = estimatedHours;
        }
      }
      if (parentId != null && parentId.isNotEmpty) {
        payload['parentId'] = parentId;
        payload['parentTaskId'] = parentId;
      }

      _lastCreated = null;
      final res = await _remoteDataSource.createWorkItemRaw(payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        _lastError = null;
        _lastCreated = _createdRecord(res.data);
        return true;
      }
      String errorMsg = 'Lỗi tạo công việc (${res.statusCode})';
      if (res.data is Map<String, dynamic>) {
        errorMsg = res.data['message']?.toString() ?? res.data['error']?.toString() ?? errorMsg;
      }
      _lastError = errorMsg;
      debugPrint('[WorkspaceRepositoryImpl] createWorkItem error: $errorMsg');
      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[WorkspaceRepositoryImpl] createWorkItem error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateWorkItemStatus(
    String workItemId,
    String status, {
    String? note,
    List<String>? confirmedConditionIds,
  }) async {
    try {
      final res = await _remoteDataSource.updateWorkItemStatusRaw(
        workItemId,
        status,
        note: note,
        confirmedConditionIds: confirmedConditionIds,
      );
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateWorkItemStatus error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateStandaloneTask(String taskId, Map<String, dynamic> data) async {
    try {
      final res = await _remoteDataSource.updateStandaloneTaskRaw(taskId, data);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateStandaloneTask error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateWorkItem(String workItemId, Map<String, dynamic> data) async {
    try {
      final res = await _remoteDataSource.updateWorkItemRaw(workItemId, data);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateWorkItem error: $e');
      return _fail(e);
    }
  }

  @override
  Future<WorkItemCompletionPolicy?> getWorkItemCompletionPolicy(String workItemId) async {
    try {
      final raw = await _remoteDataSource.getWorkItemDetailRaw(workItemId);
      if (raw != null && raw is Map<String, dynamic>) {
        final data = raw['data'] ?? raw;
        if (data is Map<String, dynamic> && data['completion'] != null) {
          final comp = data['completion'];
          if (comp is Map<String, dynamic>) {
            return WorkItemCompletionPolicy.fromJson(comp);
          }
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkItemCompletionPolicy error: $e');
    }
    return null;
  }

  @override
  Future<List<StandaloneTaskItem>> getStandaloneTasks({
    String scope = 'all',
    Map<String, String>? projectMap,
  }) async {
    try {
      final raw = await _remoteDataSource.getStandaloneTasksRaw(scope: scope);
      if (raw != null) {
        dynamic items;
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          items = raw['items'] ?? raw['data'] ?? raw['tasks'] ?? raw['standaloneTasks'];
          if (items == null) {
            for (final val in raw.values) {
              if (val is List) {
                items = val;
                break;
              }
            }
          }
        }
        if (items is List) {
          final list = items.map((e) => StandaloneTaskItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          debugPrint('[WorkspaceRepositoryImpl] getStandaloneTasks($scope) loaded ${list.length} tasks');
          return list;
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getStandaloneTasks error: $e');
    }
    return [];
  }

  @override
  Future<({bool success, String? error})> createStandaloneTask({
    required String title,
    String? description,
    String priority = 'normal',
    String? dueDate,
    String? plannedStart,
    required String assigneeUserId,
    List<String>? participantUserIds,
    List<String>? followerUserIds,
    String? executionType,
    String? procedureDefinitionId,
    String? parentId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': title.trim(),
        'priority': priority,
        'assigneeUserId': assigneeUserId,
      };
      if (description != null && description.trim().isNotEmpty) payload['description'] = description.trim();
      if (dueDate != null && dueDate.trim().isNotEmpty) payload['dueDate'] = dueDate;
      if (plannedStart != null && plannedStart.trim().isNotEmpty) payload['plannedStart'] = plannedStart;
      if (participantUserIds != null && participantUserIds.isNotEmpty) payload['participantUserIds'] = participantUserIds;
      if (followerUserIds != null && followerUserIds.isNotEmpty) payload['followerUserIds'] = followerUserIds;
      if (executionType != null && executionType.trim().isNotEmpty) payload['executionType'] = executionType;
      if (procedureDefinitionId != null && procedureDefinitionId.trim().isNotEmpty) {
        payload['procedureDefinitionId'] = procedureDefinitionId.trim();
      }
      if (parentId != null && parentId.trim().isNotEmpty) {
        payload['parentId'] = parentId.trim();
      }

      _lastCreated = null;
      final res = await _remoteDataSource.createStandaloneTaskRaw(payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        _lastCreated = _createdRecord(res.data, 'task');
        return (success: true, error: null);
      } else {
        String? msg;
        if (res.data != null) {
          if (res.data is Map) {
            msg = (res.data['message'] ?? res.data['error'] ?? res.data['detail'])?.toString();
          } else {
            msg = res.data.toString();
          }
        }
        debugPrint('[WorkspaceRepositoryImpl] createStandaloneTask failed (${res.statusCode}): ${res.data}');
        return (success: false, error: msg ?? 'Lỗi máy chủ (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] createStandaloneTask error: $e');
      return (success: false, error: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> getStandaloneTaskDetail(String taskId) async {
    try {
      final raw = await _remoteDataSource.getStandaloneTaskDetailRaw(taskId);
      if (raw != null && raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map['code'] == 'STANDALONE_TASK_NOT_FOUND' ||
            map['error'] != null ||
            map['statusCode'] == 404 ||
            map['status'] == 404) {
          return null;
        }
        return map['data'] is Map<String, dynamic> ? map['data'] as Map<String, dynamic> : map;
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getStandaloneTaskDetail error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getWorkItemDetail(String workItemId) async {
    try {
      final raw = await _remoteDataSource.getWorkItemDetailRaw(workItemId);
      if (raw != null && raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map['code'] == 'WORK_ITEM_NOT_FOUND' ||
            map['error'] != null ||
            map['statusCode'] == 404 ||
            map['status'] == 404) {
          return null;
        }
        final itemData = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : (map['item'] is Map ? Map<String, dynamic>.from(map['item'] as Map) : map);

        final pId = itemData['projectId']?.toString() ?? '';

        // Fetch history
        List<dynamic> history = [];
        try {
          final histRaw = await _remoteDataSource.getWorkItemHistoryRaw(workItemId);
          if (histRaw is Map && histRaw['items'] is List) {
            history = histRaw['items'] as List;
          } else if (histRaw is List) {
            history = histRaw;
          }
        } catch (_) {}

        // Fetch checklist
        List<dynamic> checklist = [];
        try {
          final clRaw = await _remoteDataSource.getWorkItemChecklistRaw(workItemId);
          if (clRaw is Map && clRaw['items'] is List) {
            checklist = clRaw['items'] as List;
          } else if (clRaw is List) {
            checklist = clRaw;
          }
        } catch (_) {}

        // Fetch progress reports
        List<dynamic> progressReports = [];
        try {
          final prRaw = await _remoteDataSource.getWorkItemProgressReportsRaw(workItemId);
          if (prRaw is Map && prRaw['items'] is List) {
            progressReports = prRaw['items'] as List;
          } else if (prRaw is List) {
            progressReports = prRaw;
          }
        } catch (_) {}

        // Fetch dependencies
        List<dynamic> dependencies = [];
        try {
          final dpRaw = await _remoteDataSource.getWorkItemDependenciesRaw(workItemId);
          if (dpRaw is Map && dpRaw['items'] is List) {
            dependencies = dpRaw['items'] as List;
          } else if (dpRaw is List) {
            dependencies = dpRaw;
          }
        } catch (_) {}

        // Fetch children (subtasks) if projectId is available
        List<dynamic> children = [];
        if (pId.isNotEmpty) {
          try {
            final treeRaw = await _remoteDataSource.getProjectWorkItemsRaw(pId);
            dynamic treeItems = treeRaw is Map ? (treeRaw['items'] ?? treeRaw['data']) : treeRaw;
            if (treeItems is List) {
              children = treeItems
                  .where((c) => c is Map && c['parentId']?.toString() == workItemId)
                  .toList();
            }
          } catch (_) {}
        }

        return {
          'task': itemData,
          'item': itemData,
          'children': children,
          'history': history,
          'checklist': checklist,
          'progressReports': progressReports,
          'dependencies': dependencies,
          'allowedStatuses': ['todo', 'in_progress', 'review', 'done', 'cancelled', 'blocked'],
          'canAddChild': true,
        };
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkItemDetail error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getUnifiedTaskDetail(
    String taskId, {
    String? projectId,
    bool isProjectTask = false,
  }) async {
    final preferWorkItem = isProjectTask || (projectId != null && projectId.isNotEmpty);
    if (preferWorkItem) {
      final res = await getWorkItemDetail(taskId);
      if (res != null) return res;
      return await getStandaloneTaskDetail(taskId);
    } else {
      final res = await getStandaloneTaskDetail(taskId);
      if (res != null) return res;
      return await getWorkItemDetail(taskId);
    }
  }

  @override
  Future<bool> deleteWorkItem(String workItemId) async {
    try {
      final res = await _remoteDataSource.deleteWorkItemRaw(workItemId);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] deleteWorkItem error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> reverseWorkItem(String workItemId, String reason) async {
    try {
      final res = await _remoteDataSource.reverseWorkItemRaw(workItemId, reason);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] reverseWorkItem error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> reportWorkItemProgress(
    String workItemId, {
    required double percent,
    double? actualHours,
    String? note,
  }) async {
    try {
      final res = await _remoteDataSource.reportWorkItemProgressRaw(
        workItemId,
        percent: percent,
        actualHours: actualHours,
        note: note,
      );
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] reportWorkItemProgress error: $e');
      return _fail(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkItemChecklist(String workItemId) async {
    try {
      final raw = await _remoteDataSource.getWorkItemChecklistRaw(workItemId);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data']) : raw;
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkItemChecklist error: $e');
    }
    return [];
  }

  @override
  Future<bool> addWorkItemChecklist(String workItemId, List<String> titles) async {
    try {
      final res = await _remoteDataSource.addWorkItemChecklistRaw(workItemId, titles);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] addWorkItemChecklist error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateWorkItemChecklist(String workItemId, String itemId, {String? title, bool? done}) async {
    try {
      final res = await _remoteDataSource.updateWorkItemChecklistRaw(workItemId, itemId, title: title, done: done);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateWorkItemChecklist error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> removeWorkItemChecklist(String workItemId, String itemId) async {
    try {
      final res = await _remoteDataSource.removeWorkItemChecklistRaw(workItemId, itemId);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] removeWorkItemChecklist error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> moveWorkItem(String workItemId, {String? parentId}) async {
    try {
      final res = await _remoteDataSource.moveWorkItemRaw(workItemId, parentId: parentId);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] moveWorkItem error: $e');
      return _fail(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkItemProgressReports(String workItemId) async {
    try {
      final raw = await _remoteDataSource.getWorkItemProgressReportsRaw(workItemId);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data']) : raw;
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkItemProgressReports error: $e');
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkItemDependencies(String workItemId) async {
    try {
      final raw = await _remoteDataSource.getWorkItemDependenciesRaw(workItemId);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data']) : raw;
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getWorkItemDependencies error: $e');
    }
    return [];
  }

  @override
  Future<bool> updateStandaloneTaskStatus(String taskId, String status, {String? note}) async {
    try {
      final res = await _remoteDataSource.updateStandaloneTaskStatusRaw(taskId, status, note: note);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateStandaloneTaskStatus error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> deleteStandaloneTask(String taskId) async {
    try {
      final res = await _remoteDataSource.deleteStandaloneTaskRaw(taskId);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] deleteStandaloneTask error: $e');
      return _fail(e);
    }
  }

  @override
  Future<List<ProjectMemberItem>> getProjectMembers(String projectId) async {
    try {
      final raw = await _remoteDataSource.getProjectMembersRaw(projectId);
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['members'] ?? raw['data'] ?? raw) : raw;
        if (items is Map) {
          items = items['items'] ?? items['members'] ?? items['data'] ?? items['users'] ?? items;
        }
        if (items is List) {
          return items.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final userObj = map['user'] is Map ? map['user'] as Map<String, dynamic> : null;
            final uId = map['userId']?.toString() ?? userObj?['id']?.toString() ?? map['id']?.toString() ?? '';
            final fName = map['fullName']?.toString() ?? map['name']?.toString() ?? userObj?['fullName']?.toString() ?? userObj?['name']?.toString() ?? UserResolver.resolveName(uId);
            final mail = map['email']?.toString() ?? userObj?['email']?.toString();
            final r = map['role']?.toString() ?? 'member';
            return ProjectMemberItem(
              userId: uId,
              fullName: fName.isNotEmpty && fName != '—' ? fName : UserResolver.resolveName(uId),
              email: mail,
              role: r,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectMembers error: $e');
    }
    return [];
  }

  @override
  Future<WorkspaceDirectoryResponse?> getDirectory() async {
    try {
      final map = <String, WorkspaceDirectoryPerson>{};
      final raw = await _remoteDataSource.getDirectoryRaw();
      if (raw is Map) {
        for (final p in WorkspaceDirectoryResponse.fromJson(Map<String, dynamic>.from(raw)).people) {
          if (p.userId.isNotEmpty) map[p.userId] = p;
        }
      }
      for (final u in await _platformService.getTenantUsers()) {
        if (u.id.isNotEmpty && !map.containsKey(u.id)) {
          final name = u.fullName.isNotEmpty ? u.fullName : (u.username ?? u.email);
          final pos = u.systemRole == 'tenant-admin' ? 'Quản trị viên' : 'Nhân viên';
          map[u.id] = WorkspaceDirectoryPerson(userId: u.id, displayName: name, email: u.email, positionName: pos);
        }
      }
      if (map.isNotEmpty) return WorkspaceDirectoryResponse(people: map.values.toList());
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getDirectory error: $e');
    }
    return null;
  }

  @override
  Future<bool> setProjectMembers(String projectId, List<Map<String, String>> members) async {
    final res = await setProjectMembersWithResult(projectId, members);
    return res.success;
  }

  @override
  Future<({bool success, String? errorMessage})> setProjectMembersWithResult(
    String projectId,
    List<Map<String, String>> members,
  ) async {
    try {
      final res = await _remoteDataSource.setProjectMembersRaw(projectId, members);
      debugPrint('[WorkspaceRepositoryImpl] setProjectMembers: ${res.statusCode} -> ${res.data}');
      final isOk = res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
      if (isOk) {
        return (success: true, errorMessage: null);
      }
      String? msg;
      if (res.data is Map<String, dynamic>) {
        msg = res.data['message']?.toString();
      }
      return (success: false, errorMessage: msg ?? 'Lỗi máy chủ (${res.statusCode})');
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] setProjectMembers error: $e');
      return (success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<bool> addProjectMember(String projectId, {required String userId, required String role}) async {
    try {
      final res = await _remoteDataSource.addProjectMemberRaw(projectId, {
        'userId': userId,
        'role': role,
      });
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] addProjectMember error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> updateProjectMemberRole(String projectId, {required String memberId, required String role}) async {
    try {
      final res = await _remoteDataSource.updateProjectMemberRoleRaw(projectId, memberId, role);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] updateProjectMemberRole error: $e');
      return _fail(e);
    }
  }

  @override
  Future<bool> removeProjectMember(String projectId, String memberId) async {
    try {
      final res = await _remoteDataSource.removeProjectMemberRaw(projectId, memberId);
      return _ok(res);
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] removeProjectMember error: $e');
      return _fail(e);
    }
  }

  final Map<String, String> _groupCodeMap = {};
  final List<String> _projectGroups = [];

  @override
  Future<List<String>> getProjectGroups() async {
    try {
      final raw = await _remoteDataSource.getProjectGroupsRaw();
      final List<String> groups = [];
      if (raw != null) {
        dynamic items = raw is Map ? (raw['items'] ?? raw['data'] ?? raw) : raw;
        if (items is List) {
          for (final item in items) {
            if (item is Map && item['name'] != null) {
              final name = item['name'].toString().trim();
              if (name.isNotEmpty && !groups.contains(name)) {
                groups.add(name);
                if (item['code'] != null && item['code'].toString().trim().isNotEmpty) {
                  _groupCodeMap[name] = item['code'].toString().trim();
                }
              }
            } else if (item is String && item.trim().isNotEmpty) {
              if (!groups.contains(item.trim())) groups.add(item.trim());
            }
          }
        }
      }
      if (groups.isEmpty) {
        final typesRaw = await _remoteDataSource.getProjectTypesRaw();
        if (typesRaw != null) {
          dynamic items = typesRaw is Map ? (typesRaw['items'] ?? typesRaw['data'] ?? typesRaw) : typesRaw;
          if (items is List) {
            for (final item in items) {
              if (item is Map && item['name'] != null) {
                final name = item['name'].toString().trim();
                if (name.isNotEmpty && !groups.contains(name)) groups.add(name);
                if (item['code'] != null && item['code'].toString().trim().isNotEmpty) {
                  _groupCodeMap[name] = item['code'].toString().trim();
                }
              }
            }
          }
        }
      }
      if (groups.isNotEmpty) {
        if (!groups.contains('Chưa phân loại')) {
          groups.insert(0, 'Chưa phân loại');
        }
        return groups;
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectGroups error: $e');
    }
    return [
      'Chưa phân loại',
      'Xây lắp',
      'Bán hàng ngoài EVN',
      'Dịch vụ bảo trì',
      'Dịch vụ kỹ thuật',
      'Dịch vụ sau bán hàng và Bảo trì ĐMT',
      'Dịch vụ Thí nghiệm',
      'Solar',
      'R&D',
      'Nội bộ',
    ];
  }

  @override
  Future<List<DepartmentItem>> getDepartments() async {
    try {
      final snap = await _platformService.getOrganizationSnapshot();
      if (snap.nodes.isNotEmpty) {
        final Map<String, OrgNode> nodeMap = {for (final n in snap.nodes) n.id: n};

        String? computeParentPath(OrgNode node) {
          final parts = <String>[];
          String? currParentId = node.parentId;
          final visited = <String>{node.id};

          while (currParentId != null && nodeMap.containsKey(currParentId) && !visited.contains(currParentId)) {
            visited.add(currParentId);
            final parent = nodeMap[currParentId]!;
            parts.insert(0, parent.name.trim());
            currParentId = parent.parentId;
          }
          return parts.isNotEmpty ? parts.join(' > ') : null;
        }

        // Filter unit nodes if types specify unit category, else include all active nodes
        final unitTypeIds = snap.nodeTypes.where((t) => t.category == 'unit').map((t) => t.id).toSet();
        var relevantNodes = snap.nodes.where((n) {
          if (unitTypeIds.isNotEmpty && !unitTypeIds.contains(n.nodeTypeId)) return false;
          return n.status != 'inactive' && n.status != 'archived';
        }).toList();

        if (relevantNodes.isEmpty) {
          relevantNodes = snap.nodes.where((n) => n.status != 'inactive').toList();
        }

        final List<DepartmentItem> result = [];
        final Set<String> addedIds = {};

        void addNodeAndChildren(String? parentId) {
          final children = relevantNodes.where((n) => n.parentId == parentId && !addedIds.contains(n.id)).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          for (final c in children) {
            addedIds.add(c.id);
            result.add(DepartmentItem(
              id: c.id,
              name: c.name.trim(),
              parentPath: computeParentPath(c),
              parentId: c.parentId,
            ));
            addNodeAndChildren(c.id);
          }
        }

        // Start with root nodes (parentId == null or parent not in relevant nodes)
        final rootNodes = relevantNodes.where((n) => n.parentId == null || !nodeMap.containsKey(n.parentId)).toList();
        for (final r in rootNodes) {
          if (!addedIds.contains(r.id)) {
            addedIds.add(r.id);
            result.add(DepartmentItem(
              id: r.id,
              name: r.name.trim(),
              parentPath: null,
              parentId: null,
            ));
            addNodeAndChildren(r.id);
          }
        }

        if (result.isNotEmpty) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getDepartments error: $e');
    }

    // Web 1:1 Fallback organizational hierarchy for tenant SVN DTS
    return const [
      DepartmentItem(id: 'node-root', name: 'SƠ ĐỒ TỔ CHỨC', parentPath: null),
      DepartmentItem(id: 'node-dhdcd', name: 'Đại hội Cổ đông', parentPath: 'SƠ ĐỒ TỔ CHỨC', parentId: 'node-root'),
      DepartmentItem(id: 'node-hdqt', name: 'Hội đồng Quản trị', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông', parentId: 'node-dhdcd'),
      DepartmentItem(id: 'node-bgd', name: 'Ban Tổng Giám đốc', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông > Hội đồng Quản trị', parentId: 'node-hdqt'),
      DepartmentItem(id: 'node-bks', name: 'Ban Kiểm soát', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông', parentId: 'node-dhdcd'),
      DepartmentItem(id: 'node-kkt', name: 'Khối Kỹ thuật - Dịch vụ', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông > Hội đồng Quản trị > Ban Tổng Giám đốc', parentId: 'node-bgd'),
      DepartmentItem(id: 'node-kkd', name: 'Khối Kinh doanh', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông > Hội đồng Quản trị > Ban Tổng Giám đốc', parentId: 'node-bgd'),
      DepartmentItem(id: 'node-ktc', name: 'Khối Tài chính - Kế toán', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông > Hội đồng Quản trị > Ban Tổng Giám đốc', parentId: 'node-bgd'),
      DepartmentItem(id: 'node-khc', name: 'Khối Hành chính - Nhân sự', parentPath: 'SƠ ĐỒ TỔ CHỨC > Đại hội Cổ đông > Hội đồng Quản trị > Ban Tổng Giám đốc', parentId: 'node-bgd'),
    ];
  }

  @override
  Future<String?> getProjectCodePreview(String group) async {
    final cleanGroup = group.trim();
    if (cleanGroup.isEmpty || cleanGroup == 'Chưa phân loại') {
      return null;
    }

    try {
      final raw = await _remoteDataSource.getProjectCodePreviewRaw(
        group: cleanGroup,
        projectType: cleanGroup,
      );
      if (raw != null) {
        if (raw is Map) {
          final code = raw['code'] ??
              raw['preview'] ??
              raw['projectCode'] ??
              (raw['data'] is Map ? (raw['data']['code'] ?? raw['data']['preview']) : raw['data']);
          if (code != null && code.toString().trim().isNotEmpty) {
            return code.toString().trim();
          }
        } else if (raw is String && raw.trim().isNotEmpty) {
          return raw.trim();
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] getProjectCodePreview error: $e');
    }

    // Local rule generation based on group code & current year
    final year = DateTime.now().year;
    final code = _resolveGroupCode(cleanGroup);
    if (code.isNotEmpty) {
      final seq = code == 'BHNEVN' ? '0002' : '0001';
      return '$year-$code-$seq';
    }
    return null;
  }

  String _resolveGroupCode(String group) {
    if (_groupCodeMap.containsKey(group) && _groupCodeMap[group]!.isNotEmpty) {
      return _groupCodeMap[group]!;
    }
    final lower = group.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (lower.contains('xây lắp')) return 'XL';
    if (lower.contains('bán hàng') && lower.contains('evn')) return 'BHNEVN';
    if (lower.contains('bảo trì') && lower.contains('dịch vụ')) return 'DVBT';
    if (lower.contains('kỹ thuật')) return 'DVKT';
    if (lower.contains('sau bán hàng')) return 'DVSBH';
    if (lower.contains('thí nghiệm')) return 'DVTN';
    if (lower.contains('solar')) return 'SOLAR';
    if (lower.contains('r&d') || lower.contains('rd')) return 'RD';
    if (lower.contains('nội bộ')) return 'NB';

    // Generates initials from words without accents:
    final words = group.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 1) {
      return words.map((w) => _removeVietnameseDiacritics(w[0].toUpperCase())).join();
    } else if (words.isNotEmpty) {
      return _removeVietnameseDiacritics(words.first.toUpperCase());
    }
    return 'DA';
  }

  String _removeVietnameseDiacritics(String str) {
    var result = str;
    const vietnameseSigns = [
      'aAeEoOuUiIdDyY',
      'áàạảãâấầậẩẫăắằặẳẵ',
      'ÁÀẠẢÃÂẤẦẬẨẪĂẮẰẶẲẴ',
      'éèẹẻẽêếềệểễ',
      'ÉÈẸẺẼÊẾỀỆỂỄ',
      'óòọỏõôốồộổỗơớờợởỡ',
      'ÓÒỌỎÕÔỐỒỘỔỖƠỚỜỢỞỠ',
      'úùụủũưứừựửữ',
      'ÚÙỤỦŨƯỨỪỰỬỮ',
      'íìịỉĩ',
      'ÍÌỊỈĨ',
      'đ',
      'Đ',
      'ýỳỵỷỹ',
      'ÝỲỴỶỸ'
    ];
    for (var i = 1; i < vietnameseSigns.length; i++) {
      for (var j = 0; j < vietnameseSigns[i].length; j++) {
        result = result.replaceAll(vietnameseSigns[i][j], vietnameseSigns[0][i - 1]);
      }
    }
    return result;
  }

  @override
  Future<bool> createProjectGroup(String name, String code) async {
    try {
      final res = await _remoteDataSource.createProjectGroupRaw(name: name, code: code);
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Cập nhật bộ nhớ đệm nhóm
        if (!_projectGroups.contains(name.trim())) {
          _projectGroups.add(name.trim());
        }
        _groupCodeMap[name.trim()] = code.trim();
        return true;
      }
    } catch (e) {
      debugPrint('[WorkspaceRepositoryImpl] createProjectGroup error: $e');
    }
    return false;
  }
}
