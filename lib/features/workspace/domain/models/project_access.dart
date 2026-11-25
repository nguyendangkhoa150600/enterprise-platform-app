/// Quyền thao tác trong một dự án, tính đúng như web (`projects-view.tsx`):
/// - lấy `myPermissions` server trả; server cũ không trả thì dùng quyền mặc định của vai;
///   `myRole` rỗng (quản trị tenant) thì có đủ quyền;
/// - dự án đã lưu trữ: chỉ xem, mọi quyền ghi bị bỏ.
class ProjectAccess {
  /// Bảng `DEFAULT_ROLE_PERMISSIONS` của contracts-workspace.
  static const Map<String, List<String>> defaultRolePermissions = {
    'owner': allPermissions,
    'manager': [
      'project.view_all',
      'project.view_related',
      'project.update_all',
      'project.update_related',
      'work_item.cancel',
      'project.update_status',
      'project.manage_members',
    ],
    'member': ['project.view_all', 'project.view_related', 'project.update_related', 'work_item.cancel'],
    'viewer': ['project.view_all', 'project.view_related'],
  };

  /// `PROJECT_PERMISSIONS` của contracts-workspace.
  static const List<String> allPermissions = [
    'project.view_all',
    'project.view_related',
    'project.update_all',
    'project.update_related',
    'work_item.cancel',
    'work_item.delete',
    'project.update_status',
    'project.manage_members',
  ];

  /// Web chặn thêm việc con khi độ sâu đạt mức này.
  static const int maxDepth = 9;

  final String? role;
  final bool archived;
  final Set<String> granted;

  const ProjectAccess._(this.role, this.archived, this.granted);

  factory ProjectAccess.of({
    String? role,
    List<String>? permissions,
    bool archived = false,
  }) {
    final hasRole = role != null && role.isNotEmpty;
    final given = permissions ??
        (hasRole ? (defaultRolePermissions[role] ?? const <String>[]) : allPermissions);
    return ProjectAccess._(hasRole ? role : null, archived, given.toSet());
  }

  /// Quyền còn hiệu lực: dự án lưu trữ thì không còn quyền ghi nào.
  Set<String> get _effective => archived ? const <String>{} : granted;

  bool get canWrite =>
      _effective.contains('project.update_all') || _effective.contains('project.update_related');
  bool get canManage => _effective.contains('project.update_all');
  bool get canCancelItem => _effective.contains('work_item.cancel');
  /// Xoá hẳn cần giữ vai có quyền xoá trong dự án — quản trị tenant không đi tắt.
  bool get canDeleteItem => role != null && _effective.contains('work_item.delete');
  bool get canChangeProjectStatus => _effective.contains('project.update_status');
  bool get canManageMembers => _effective.contains('project.manage_members');
  bool get canUnarchive => archived && granted.contains('project.update_status');
  bool get canOwn => (role == 'owner' || role == null) && !archived;
}

/// Bảng `WORK_ITEM_STATUS_TRANSITIONS` của contracts-workspace: chỉ đưa ra bước hợp lệ
/// thay vì để người dùng chọn rồi mới nhận lỗi từ server.
class WorkItemTransitions {
  static const Map<String, List<String>> _table = {
    'todo': ['in_progress', 'blocked', 'cancelled'],
    'in_progress': ['todo', 'blocked', 'review', 'done', 'cancelled'],
    'blocked': ['todo', 'in_progress', 'cancelled'],
    'review': ['in_progress', 'done', 'cancelled'],
    'done': ['in_progress'],
    'cancelled': ['todo'],
  };

  static bool canTransition(String from, String to) =>
      from == to || (_table[from]?.contains(to) ?? false);
}
