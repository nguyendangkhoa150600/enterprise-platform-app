import '../crm_capabilities.dart';
import 'crm_opportunity_models.dart';

/// Logic thuần của Dự án bán hàng (web `sales.model.ts`, `estimate.model.ts`, `promotions.model.ts`). Quyền và luật
/// thật nằm ở API; ở đây chỉ để giao diện phản hồi nhanh. Không phụ thuộc Flutter: lời nhắn dịch ở tầng giao diện.
class CrmOpportunityRules {
  CrmOpportunityRules._();

  /// Luồng mặc định (không có thì luồng đầu tiên).
  static CrmPipeline? defaultPipeline(List<CrmPipeline> pipelines) {
    for (final p in pipelines) {
      if (p.isDefault) return p;
    }
    return pipelines.isEmpty ? null : pipelines.first;
  }

  static CrmPipeline? pipelineById(List<CrmPipeline> pipelines, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in pipelines) {
      if (p.id == id) return p;
    }
    return null;
  }

  static CrmPipelineStage? findStage(CrmPipeline? pipeline, String code) {
    if (pipeline == null) return null;
    for (final s in pipeline.stages) {
      if (s.code == code) return s;
    }
    return null;
  }

  /// Chuyển thẻ từ [from] sang [to] hợp lệ theo bước chuyển cấu hình của luồng; giai đoạn tắt không nhận thẻ mới.
  static bool canDropStage(CrmPipeline? pipeline, String from, String to) {
    final source = findStage(pipeline, from);
    final target = findStage(pipeline, to);
    if (source == null || target == null || source.id == target.id || !target.active) return false;
    return source.nextStageIds.contains(target.id);
  }

  /// Chuyển sang giai đoạn này bắt buộc lý do (nghĩa Thua, hoặc điều kiện REASON bắt buộc).
  static bool stageNeedsReason(String semantic, Iterable<({String kind, bool required})> requirements) {
    return semantic == CrmStageSemantic.lost || requirements.any((r) => r.kind == 'REASON' && r.required);
  }

  static bool pipelineStageNeedsReason(CrmPipelineStage? stage) => stage != null &&
      stageNeedsReason(stage.semantic, stage.requirements.map((r) => (kind: r.kind, required: r.required)));

  /// Lựa chọn giai đoạn để lọc: của một luồng, hoặc gộp theo mã khi chưa chọn luồng (mã → tên).
  static List<MapEntry<String, String>> stageFilterOptions(List<CrmPipeline> pipelines, String? pipelineId) {
    final source = (pipelineId == null || pipelineId.isEmpty)
        ? pipelines
        : pipelines.where((p) => p.id == pipelineId).toList();
    final seen = <String, String>{};
    for (final p in source) {
      for (final s in p.stages) {
        seen.putIfAbsent(s.code, () => s.name);
      }
    }
    return seen.entries.toList();
  }

  /// Chủ dự án hoặc `crm.manage` (kèm quyền ghi cơ hội) mới đổi người đảm nhận.
  static bool canEditStageAssignee(CrmCapabilities caps, String? userId, String ownerUserId) {
    final writer = caps.isTenantAdmin || caps.canWriteOpportunity;
    if (!writer) return false;
    return caps.isTenantAdmin || caps.canManage || (userId != null && userId.isNotEmpty && ownerUserId == userId);
  }

  /// Được chuyển hoặc bỏ qua giai đoạn: chủ dự án, người đảm nhận giai đoạn đang làm, hoặc `crm.manage`.
  static bool canLeaveCurrentStage(
      CrmCapabilities caps, String? userId, String ownerUserId, List<CrmStagePlanItem>? plan) {
    final writer = caps.isTenantAdmin || caps.canWriteOpportunity;
    if (!writer) return false;
    if (caps.isTenantAdmin || caps.canManage) return true;
    if (userId == null || userId.isEmpty) return false;
    if (ownerUserId == userId) return true;
    return plan?.any((i) => i.status == 'ACTIVE' && i.assigneeUserId == userId) ?? false;
  }

  /// Giai đoạn bỏ qua được: cho phép bỏ qua, chưa tới, dự án còn mở.
  static bool canSkipPlanItem(CrmStagePlanItem item, bool opportunityOpen) =>
      opportunityOpen && item.skippable && item.status == 'PENDING';

  /// Chưa có người đảm nhận và chưa xong / bỏ qua.
  static bool stageNeedsAssignee(CrmStagePlanItem item) =>
      (item.assigneeUserId == null || item.assigneeUserId!.isEmpty) &&
      (item.status == 'PENDING' || item.status == 'ACTIVE');

  /// Hạn đã quá (so theo ngày `YYYY-MM-DD`, giờ máy).
  static bool isDueOverdue(String? dueDate, [DateTime? now]) {
    if (dueDate == null || dueDate.isEmpty) return false;
    final n = now ?? DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final day = dueDate.length >= 10 ? dueDate.substring(0, 10) : dueDate;
    return day.compareTo(today) < 0;
  }

  /// Giai đoạn chọn bỏ qua được lúc tạo dự án: đang bật, nghĩa Đang chạy, cho phép bỏ qua, không phải giai đoạn đầu.
  static List<CrmPipelineStage> skippableStartStages(CrmPipeline? pipeline) {
    if (pipeline == null) return const [];
    final open = pipeline.stages.where((s) => s.active && s.semantic == CrmStageSemantic.open).toList();
    if (open.isEmpty) return const [];
    final first = open.first;
    return open.where((s) => s.skippable && s.id != first.id).toList();
  }

  /// Lựa chọn bỏ qua (mã → lý do) thành `skipStages`. [missingReasonStage] là tên giai đoạn thiếu lý do.
  static ({List<Map<String, String>> skipStages, String? missingReasonStage}) buildSkipStages(
      CrmPipeline? pipeline, Map<String, String> chosen) {
    final out = <Map<String, String>>[];
    for (final stage in skippableStartStages(pipeline)) {
      if (!chosen.containsKey(stage.code)) continue;
      final reason = chosen[stage.code]!.trim();
      if (reason.isEmpty) return (skipStages: const [], missingReasonStage: stage.name);
      out.add({'stage': stage.code, 'reason': reason});
    }
    return (skipStages: out, missingReasonStage: null);
  }

  /// Chuyển thẻ sang cột mới (lạc quan). Thẻ không có hoặc cùng cột → null.
  static CrmOpportunityBoard? moveCard(CrmOpportunityBoard board, String id, String to) {
    CrmBoardColumn? fromColumn;
    CrmBoardColumn? toColumn;
    CrmOpportunitySummary? card;
    for (final c in board.columns) {
      if (c.stage == to) toColumn = c;
      for (final item in c.items) {
        if (item.id == id) {
          fromColumn = c;
          card = item;
        }
      }
    }
    if (fromColumn == null || toColumn == null || card == null || fromColumn.stage == to) return null;
    final moved = card.movedTo(to, toColumn.stageInfo);
    final value = card.expectedValue ?? 0;
    return board.withColumns(board.columns.map((c) {
      if (c.stage == fromColumn!.stage) {
        return c.copyWith(
          total: c.total - 1 < 0 ? 0 : c.total - 1,
          totalValue: c.totalValue - value,
          items: c.items.where((i) => i.id != id).toList(),
        );
      }
      if (c.stage == to) {
        return c.copyWith(total: c.total + 1, totalValue: c.totalValue + value, items: [moved, ...c.items]);
      }
      return c;
    }).toList());
  }

  /// Thay một thẻ bằng bản server trả về sau khi chuyển thành công.
  static CrmOpportunityBoard replaceCard(CrmOpportunityBoard board, CrmOpportunitySummary card) =>
      board.withColumns(board.columns
          .map((c) => c.copyWith(items: c.items.map((i) => i.id == card.id ? card : i).toList()))
          .toList());

  /// Nhóm dự án theo khách, giữ thứ tự xuất hiện; [totals] của server thay số và tổng của mọi trang.
  static List<CrmCustomerOpportunityGroup> groupByCustomer(
      List<CrmOpportunitySummary> items, List<CrmOpportunityCustomerTotal> totals) {
    final groups = <String, List<CrmOpportunitySummary>>{};
    for (final item in items) {
      groups.putIfAbsent(item.customerId, () => []).add(item);
    }
    return groups.entries.map((e) {
      final head = e.value.first;
      CrmOpportunityCustomerTotal? total;
      for (final t in totals) {
        if (t.customerId == e.key) total = t;
      }
      final sum = e.value.fold<double>(0, (acc, i) => acc + (i.expectedValue ?? 0));
      final count = total?.count ?? e.value.length;
      return CrmCustomerOpportunityGroup(
        customerId: e.key,
        customerCode: head.customerCode,
        customerName: head.customerName,
        count: count,
        totalValue: total?.totalValue ?? sum,
        items: e.value,
        partial: e.value.length < count,
      );
    }).toList();
  }

  /// Tiền đồng không âm, < 1e16 (web `parseAmount`); rỗng → null; sai → [invalid] true.
  static ({double? value, bool invalid}) parseAmount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (value: null, invalid: false);
    final value = double.tryParse(trimmed);
    if (value == null || !value.isFinite || value < 0 || value >= 1e16) return (value: null, invalid: true);
    return (value: value, invalid: false);
  }

  /// Lợi nhuận dự toán (cần đủ cả hai số); tỷ suất (%, 2 số lẻ) null khi tổng bằng 0.
  static ({double profit, double? marginPercent})? summarizeEstimate(double? total, double? cost) {
    if (total == null || cost == null) return null;
    final profit = total - cost;
    return (profit: profit, marginPercent: total > 0 ? (profit / total * 10000).round() / 100 : null);
  }

  /// Đối chiếu dự toán với PAKD: `NO_PLAN`, `NO_ESTIMATE`, `MATCH`, `DIFFERENT`.
  static ({String status, double? totalDelta, double? costDelta}) compareEstimateWithPlan(
      double? total, double? cost, CrmOpportunityBusinessPlan? plan) {
    if (plan == null) return (status: 'NO_PLAN', totalDelta: null, costDelta: null);
    if (total == null && cost == null) return (status: 'NO_ESTIMATE', totalDelta: null, costDelta: null);
    final totalDelta = total == null ? null : total - plan.revenue;
    final costDelta = (cost == null || plan.totalCost == null) ? null : cost - plan.totalCost!;
    final same = (totalDelta ?? 0) == 0 && (costDelta ?? 0) == 0;
    return (status: same ? 'MATCH' : 'DIFFERENT', totalDelta: totalDelta, costDelta: costDelta);
  }

  /// Danh mục còn hiệu lực chưa được chọn.
  static List<CrmPromotionCatalogItem> selectableCatalog(
          List<CrmPromotionCatalogItem> catalog, Set<String> takenCatalogIds) =>
      catalog.where((i) => i.effective && !takenCatalogIds.contains(i.id)).toList();
}

/// Nhóm dự án theo khách (web `CustomerOpportunityGroup`).
class CrmCustomerOpportunityGroup {
  final String customerId;
  final String customerCode;
  final String customerName;
  final int count;
  final double totalValue;
  final List<CrmOpportunitySummary> items;
  final bool partial;

  const CrmCustomerOpportunityGroup({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.count,
    required this.totalValue,
    required this.items,
    required this.partial,
  });
}
