import 'package:dio/dio.dart';
import 'workspace_api_base.dart';

/// Phiếu thu/chi hạch toán cho dự án (khớp `ProjectVoucher` ở web `project-vouchers.model.ts`).
class ProjectVoucher {
  final String id;
  final String kind; // RECEIPT | PAYMENT
  final String code;
  final String content;
  final String? reasonName;
  final String status; // DRAFT | PENDING | APPROVED
  final double totalAmount;
  final String link; // ALLOCATION | RELATED
  final String? createdByName;

  /// Ngày hạch toán `YYYY-MM-DD`.
  final String postingDate;

  /// Lúc lập phiếu (ISO).
  final String createdAt;

  /// Dòng tiền luỹ kế sau phiếu; null với phiếu chờ hay chỉ liên quan.
  final double? balance;

  const ProjectVoucher({
    required this.id,
    required this.kind,
    required this.code,
    required this.content,
    required this.reasonName,
    required this.status,
    required this.totalAmount,
    required this.link,
    required this.createdByName,
    required this.postingDate,
    required this.createdAt,
    required this.balance,
  });

  bool get isReceipt => kind == 'RECEIPT';

  /// Phiếu đã ghi sổ hạch toán cho dự án — mới là tiền thật của dự án.
  bool get settled => link == 'ALLOCATION' && status == 'APPROVED';

  /// Bản Tài chính cũ chưa trả ngày hạch toán/ngày lập/dòng tiền: lấy ngày phiếu, không có dòng tiền (như `normalizeProjectVoucherList`).
  factory ProjectVoucher.fromJson(Map<String, dynamic> json) {
    final voucherDate = json['voucherDate']?.toString() ?? '';
    return ProjectVoucher(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'RECEIPT',
      code: json['code']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      reasonName: _text(json['reasonName']),
      status: json['status']?.toString() ?? 'DRAFT',
      totalAmount: _num(json['totalAmount']) ?? 0,
      link: json['link']?.toString() ?? 'ALLOCATION',
      createdByName: _text(json['createdByName']),
      postingDate: _text(json['postingDate']) ?? voucherDate,
      createdAt: _text(json['createdAt']) ?? (voucherDate.isEmpty ? '' : '${voucherDate}T00:00:00.000Z'),
      balance: _num(json['balance']),
    );
  }
}

class ProjectVoucherTotals {
  final double received;
  final double paid;
  final double pendingReceived;
  final double pendingPaid;
  final int receiptCount;
  final int paymentCount;

  const ProjectVoucherTotals({
    this.received = 0,
    this.paid = 0,
    this.pendingReceived = 0,
    this.pendingPaid = 0,
    this.receiptCount = 0,
    this.paymentCount = 0,
  });

  factory ProjectVoucherTotals.fromJson(dynamic raw) {
    if (raw is! Map) return const ProjectVoucherTotals();
    return ProjectVoucherTotals(
      received: _num(raw['received']) ?? 0,
      paid: _num(raw['paid']) ?? 0,
      pendingReceived: _num(raw['pendingReceived']) ?? 0,
      pendingPaid: _num(raw['pendingPaid']) ?? 0,
      receiptCount: (_num(raw['receiptCount']) ?? 0).toInt(),
      paymentCount: (_num(raw['paymentCount']) ?? 0).toInt(),
    );
  }
}

class ProjectVoucherList {
  final List<ProjectVoucher> items;
  final ProjectVoucherTotals totals;
  final bool truncated;

  const ProjectVoucherList({required this.items, required this.totals, required this.truncated});

  factory ProjectVoucherList.fromJson(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final items = map['items'] is List
        ? (map['items'] as List)
            .whereType<Map>()
            .map((e) => ProjectVoucher.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ProjectVoucher>[];
    return ProjectVoucherList(
      items: items,
      totals: ProjectVoucherTotals.fromJson(map['totals']),
      truncated: map['truncated'] == true,
    );
  }
}

/// Lý do không có số thu chi (như `ProjectVoucherResult` của web).
enum ProjectVoucherFailure {
  /// 403 — message server nếu có, không thì câu mặc định.
  forbidden,

  /// 404 `FINANCE_NOT_FOUND`.
  notFound,

  /// `FINANCE_WORKSPACE_UNAVAILABLE` — message server nếu có.
  workspaceUnavailable,

  /// Module chưa bật / gateway lỗi.
  notReady,

  /// Thân 2xx không đọc được.
  unreadable,

  /// Không kết nối được.
  offline,
}

class ProjectVoucherResult {
  final ProjectVoucherList? data;
  final ProjectVoucherFailure? failure;
  final String? serverMessage;

  const ProjectVoucherResult.ok(ProjectVoucherList this.data)
      : failure = null,
        serverMessage = null;
  const ProjectVoucherResult.failed(ProjectVoucherFailure this.failure, [this.serverMessage]) : data = null;
}

/// Số liệu thu chi (module Tài chính) và giá trị hợp đồng (Workspace) của dự án.
class WorkspaceFinanceApi extends WorkspaceApiBase {
  static const String financeRoot = '/api/finance/v1';

  /// `GET /api/finance/v1/projects/{id}/vouchers`, phân loại phản hồi như `classifyProjectVoucherResponse`.
  Future<ProjectVoucherResult> projectVouchers(String projectId) async {
    try {
      final res = await dio.get<dynamic>(
        '$financeRoot/projects/${Uri.encodeComponent(projectId)}/vouchers',
        options: Options(validateStatus: (_) => true),
      );
      final status = res.statusCode ?? 0;
      final body = res.data;
      if (status >= 200 && status < 300) {
        if (body is! Map) return const ProjectVoucherResult.failed(ProjectVoucherFailure.unreadable);
        return ProjectVoucherResult.ok(ProjectVoucherList.fromJson(body));
      }
      final code = body is Map ? body['code']?.toString() : null;
      final message = WorkspaceApiBase.messageOf(body);
      if (status == 403) return ProjectVoucherResult.failed(ProjectVoucherFailure.forbidden, message);
      if (status == 404 && code == 'FINANCE_NOT_FOUND') {
        return const ProjectVoucherResult.failed(ProjectVoucherFailure.notFound);
      }
      if (code == 'FINANCE_WORKSPACE_UNAVAILABLE') {
        return ProjectVoucherResult.failed(ProjectVoucherFailure.workspaceUnavailable, message);
      }
      return const ProjectVoucherResult.failed(ProjectVoucherFailure.notReady);
    } catch (_) {
      return const ProjectVoucherResult.failed(ProjectVoucherFailure.offline);
    }
  }

  /// `PATCH /projects/{id}/finance` — trả `ProjectFinance` mới.
  Future<WorkspaceApiResult<Map<String, dynamic>>> updateProjectFinance(String projectId, {required double? contractValue}) {
    return send(
      'PATCH',
      '${WorkspaceApiBase.root}/projects/$projectId/finance',
      body: {'contractValue': contractValue},
      parse: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _text(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}
