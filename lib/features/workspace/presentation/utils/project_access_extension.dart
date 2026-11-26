import '../../../../models/workspace_models.dart';
import '../../domain/models/project_access.dart';

export '../../domain/models/project_access.dart';

extension ProjectItemAccess on ProjectItem {
  /// Quyền của người đang xem trong dự án này (đã tính dự án lưu trữ).
  ProjectAccess get access => ProjectAccess.of(
        role: myRole,
        permissions: permissionsProvided ? myPermissions : null,
        archived: isArchived,
      );
}
