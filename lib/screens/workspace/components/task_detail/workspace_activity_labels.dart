import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../models/workspace_models.dart';

/// Nhãn + màu trạng thái công việc như web `workspace-labels.ts` (WORK_ITEM_STATUS_LABELS / _TONE).
/// Dùng chung cho nhật ký hoạt động và tab Phụ thuộc.
class WorkItemStatusTone {
  final Color bg;
  final Color fg;
  const WorkItemStatusTone(this.bg, this.fg);
}

const Map<String, WorkItemStatusTone> kWorkItemStatusTones = {
  'todo': WorkItemStatusTone(Color(0x2E9CA3AF), Color(0xFF4B5563)),
  'in_progress': WorkItemStatusTone(Color(0x263B82F6), Color(0xFF1D4ED8)),
  'blocked': WorkItemStatusTone(Color(0x26EF4444), Color(0xFFB91C1C)),
  'review': WorkItemStatusTone(Color(0x2EF59E0B), Color(0xFF92400E)),
  'done': WorkItemStatusTone(Color(0x2610B981), Color(0xFF047857)),
  'cancelled': WorkItemStatusTone(Color(0xFFF3F4F6), Color(0xFF6B7280)),
};

/// Màu "Đã huỷ hiệu lực" (web `workItemStatusTone` khi có reversal).
const WorkItemStatusTone kReversedTone = WorkItemStatusTone(Color(0xFFFFF7ED), Color(0xFF9A3412));

const _knownStatuses = {'todo', 'in_progress', 'blocked', 'review', 'done', 'cancelled'};

/// Nhãn trạng thái công việc (web WORK_ITEM_STATUS_LABELS); giá trị lạ giữ nguyên.
String workItemStatusText(String? status) {
  if (status == null || status.isEmpty) return '';
  return _knownStatuses.contains(status) ? 'workspace.activity.status.$status'.tr() : status;
}

WorkItemStatusTone workItemStatusToneOf(String? status) =>
    kWorkItemStatusTones[status] ?? kWorkItemStatusTones['todo']!;

/// Web `workItemStatusLabel(item)`: việc huỷ hiệu lực vẫn là `cancelled` nhưng hiện riêng.
String workItemStatusLabelOf(StandaloneTaskItem item) =>
    item.isReversed ? 'workspace.activity.reversed'.tr() : workItemStatusText(item.status);
