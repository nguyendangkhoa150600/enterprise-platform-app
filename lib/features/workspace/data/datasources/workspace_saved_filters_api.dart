import 'workspace_api_base.dart';

/// Mẫu lọc đã lưu (contracts-workspace `SavedFilter`).
class SavedFilterItem {
  final String id;
  final String name;
  final Map<String, dynamic> filter;
  final bool isShared;
  final String? projectId;
  final String ownerUserId;

  const SavedFilterItem({
    required this.id,
    required this.name,
    required this.filter,
    required this.isShared,
    this.projectId,
    required this.ownerUserId,
  });

  factory SavedFilterItem.fromJson(Map<String, dynamic> json) => SavedFilterItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        filter: json['filter'] is Map ? Map<String, dynamic>.from(json['filter'] as Map) : const {},
        isShared: json['isShared'] == true,
        projectId: json['projectId']?.toString(),
        ownerUserId: json['ownerUserId']?.toString() ?? '',
      );
}

/// /saved-filters (web workspace-api.ts listSavedFilters / saveFilter / removeSavedFilter).
class WorkspaceSavedFiltersApi extends WorkspaceApiBase {
  Future<WorkspaceApiResult<List<SavedFilterItem>>> list(String view, {String? projectId}) {
    return send(
      'GET',
      '${WorkspaceApiBase.root}/saved-filters',
      query: {'view': view, 'projectId': ?projectId},
      parse: (data) => WorkspaceApiBase.itemsOf(data).map(SavedFilterItem.fromJson).toList(),
    );
  }

  /// Lưu trùng tên với mẫu cũ của mình thì server ghi đè mẫu đó.
  Future<WorkspaceApiResult<SavedFilterItem>> save({
    required String viewKey,
    required String name,
    required Map<String, dynamic> filter,
    String? projectId,
  }) {
    return send(
      'POST',
      '${WorkspaceApiBase.root}/saved-filters',
      body: {'viewKey': viewKey, 'name': name, 'filter': filter, 'projectId': ?projectId},
      parse: (data) {
        final map = data is Map ? (data['data'] is Map ? data['data'] as Map : data) : const {};
        return SavedFilterItem.fromJson(Map<String, dynamic>.from(map));
      },
    );
  }

  Future<WorkspaceApiResult<bool>> remove(String id) {
    return send('DELETE', '${WorkspaceApiBase.root}/saved-filters/$id', parse: (_) => true);
  }
}
