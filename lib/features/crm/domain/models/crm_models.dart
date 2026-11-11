// Các mô hình dữ liệu của phân hệ CRM (Bán hàng & Khách hàng)
// Đồng bộ 1:1 với contracts-crm từ backend REST API /api/crm/v1

class CrmStatus {
  final bool isTenantAdmin;
  final bool canManage;
  final bool canWriteOpportunity;
  final bool canWriteQuote;
  final bool canApproveQuote;
  final bool canWriteOrder;
  final bool canWriteContract;
  final bool canWriteReceivable;
  final bool canWriteWarranty;
  final bool canReadReport;
  final String scope;

  const CrmStatus({
    this.isTenantAdmin = false,
    this.canManage = false,
    this.canWriteOpportunity = false,
    this.canWriteQuote = false,
    this.canApproveQuote = false,
    this.canWriteOrder = false,
    this.canWriteContract = false,
    this.canWriteReceivable = false,
    this.canWriteWarranty = false,
    this.canReadReport = false,
    this.scope = '',
  });

  factory CrmStatus.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] as Map<String, dynamic>? ?? json;
    return CrmStatus(
      isTenantAdmin: caps['isTenantAdmin'] == true,
      canManage: caps['canManage'] == true,
      canWriteOpportunity: caps['canWriteOpportunity'] == true,
      canWriteQuote: caps['canWriteQuote'] == true,
      canApproveQuote: caps['canApproveQuote'] == true,
      canWriteOrder: caps['canWriteOrder'] == true,
      canWriteContract: caps['canWriteContract'] == true,
      canWriteReceivable: caps['canWriteReceivable'] == true,
      canWriteWarranty: caps['canWriteWarranty'] == true,
      canReadReport: caps['canReadReport'] == true,
      scope: json['scope']?.toString() ?? '',
    );
  }
}

class CrmDashboard {
  final String period;
  final String asOf;
  final double revenue;
  final double profit;
  final double marginPercent;
  final int newOrders;
  final double winRate;
  final int wonOpportunities;
  final int lostOpportunities;
  final int pipelineCount;
  final double pipelineValue;
  final double receivablesBalance;
  final double receivablesOverdue;
  final int pendingQuotesCount;
  final double pendingQuotesValue;
  final List<CrmPipelineStage> pipeline;
  final List<CrmTopCustomer> topCustomers;

  const CrmDashboard({
    this.period = 'month',
    this.asOf = '',
    this.revenue = 0,
    this.profit = 0,
    this.marginPercent = 0,
    this.newOrders = 0,
    this.winRate = 0,
    this.wonOpportunities = 0,
    this.lostOpportunities = 0,
    this.pipelineCount = 0,
    this.pipelineValue = 0,
    this.receivablesBalance = 0,
    this.receivablesOverdue = 0,
    this.pendingQuotesCount = 0,
    this.pendingQuotesValue = 0,
    this.pipeline = const [],
    this.topCustomers = const [],
  });

  factory CrmDashboard.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};

    double parseNum(dynamic val) {
      if (val == null) return 0;
      if (val is Map) return parseNum(val['value'] ?? val['current'] ?? val['rate'] ?? val['balance']);
      return double.tryParse(val.toString()) ?? 0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is Map) return parseInt(val['value'] ?? val['current'] ?? val['count']);
      return int.tryParse(val.toString()) ?? 0;
    }

    final rawPipeline = json['pipeline'];
    final pipelineList = <CrmPipelineStage>[];
    if (rawPipeline is List) {
      for (final e in rawPipeline) {
        if (e is Map<String, dynamic>) pipelineList.add(CrmPipelineStage.fromJson(e));
      }
    }

    final rawTop = json['topCustomers'];
    final topList = <CrmTopCustomer>[];
    if (rawTop is List) {
      for (final e in rawTop) {
        if (e is Map<String, dynamic>) topList.add(CrmTopCustomer.fromJson(e));
      }
    }

    final winRateMap = kpis['winRate'] as Map<String, dynamic>? ?? {};

    return CrmDashboard(
      period: json['period']?.toString() ?? 'month',
      asOf: json['asOf']?.toString() ?? '',
      revenue: parseNum(kpis['revenue']),
      profit: parseNum(kpis['profit']),
      marginPercent: parseNum(kpis['marginPercent']),
      newOrders: parseInt(kpis['newOrders']),
      winRate: parseNum(winRateMap['rate'] ?? winRateMap['value']),
      wonOpportunities: parseInt(winRateMap['won']),
      lostOpportunities: parseInt(winRateMap['lost']),
      pipelineCount: parseInt(kpis['pipeline']),
      pipelineValue: parseNum(kpis['pipeline']),
      receivablesBalance: parseNum(kpis['receivables']),
      receivablesOverdue: parseNum((kpis['receivables'] as Map<String, dynamic>?)?['overdue']),
      pendingQuotesCount: parseInt(kpis['pendingQuotes']),
      pendingQuotesValue: parseNum(kpis['pendingQuotes']),
      pipeline: pipelineList,
      topCustomers: topList,
    );
  }
}

class CrmPipelineStage {
  final String stage;
  final int count;
  final double value;
  final double weightedValue;

  const CrmPipelineStage({
    required this.stage,
    this.count = 0,
    this.value = 0,
    this.weightedValue = 0,
  });

  factory CrmPipelineStage.fromJson(Map<String, dynamic> json) {
    return CrmPipelineStage(
      stage: json['stage']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
      weightedValue: double.tryParse(json['weightedValue']?.toString() ?? '0') ?? 0,
    );
  }

  String get stageLabel {
    switch (stage.toUpperCase()) {
      case 'QUALIFICATION':
      case 'KHAO_SAT':
        return 'Khảo sát / Đánh giá';
      case 'PROPOSAL':
      case 'DE_XUAT':
        return 'Đề xuất giải pháp';
      case 'NEGOTIATION':
      case 'DAM_PHAN':
        return 'Đàm phán';
      case 'WON':
      case 'THANG':
        return 'Thành công (Won)';
      case 'LOST':
      case 'THUA':
        return 'Thất bại (Lost)';
      default:
        return stage;
    }
  }
}

class CrmTopCustomer {
  final String customerId;
  final String code;
  final String name;
  final double revenue;
  final double profit;
  final int orderCount;

  const CrmTopCustomer({
    required this.customerId,
    required this.code,
    required this.name,
    this.revenue = 0,
    this.profit = 0,
    this.orderCount = 0,
  });

  factory CrmTopCustomer.fromJson(Map<String, dynamic> json) {
    return CrmTopCustomer(
      customerId: json['customerId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0,
      profit: double.tryParse(json['profit']?.toString() ?? '0') ?? 0,
      orderCount: int.tryParse(json['orderCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class CrmCustomerSummary {
  final String id;
  final String code;
  final String name;
  final String? taxCode;
  final String? province;
  final String? groupName;
  final String ownerUserId;
  final String? primaryContactName;
  final String updatedAt;

  const CrmCustomerSummary({
    required this.id,
    required this.code,
    required this.name,
    this.taxCode,
    this.province,
    this.groupName,
    required this.ownerUserId,
    this.primaryContactName,
    this.updatedAt = '',
  });

  factory CrmCustomerSummary.fromJson(Map<String, dynamic> json) {
    return CrmCustomerSummary(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      taxCode: json['taxCode']?.toString(),
      province: json['province']?.toString(),
      groupName: json['groupName']?.toString(),
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      primaryContactName: json['primaryContactName']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class CrmOpportunitySummary {
  final String id;
  final String name;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String stage;
  final int probability;
  final double? expectedValue;
  final String? expectedCloseDate;
  final String ownerUserId;
  final String updatedAt;

  const CrmOpportunitySummary({
    required this.id,
    required this.name,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.stage,
    this.probability = 0,
    this.expectedValue,
    this.expectedCloseDate,
    required this.ownerUserId,
    this.updatedAt = '',
  });

  factory CrmOpportunitySummary.fromJson(Map<String, dynamic> json) {
    return CrmOpportunitySummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'QUALIFICATION',
      probability: int.tryParse(json['probability']?.toString() ?? '0') ?? 0,
      expectedValue: json['expectedValue'] != null ? double.tryParse(json['expectedValue'].toString()) : null,
      expectedCloseDate: json['expectedCloseDate']?.toString(),
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class CrmQuoteSummary {
  final String id;
  final String code;
  final String customerName;
  final String status;
  final double totalAmount;
  final String? validUntil;
  final String ownerUserId;
  final String updatedAt;

  const CrmQuoteSummary({
    required this.id,
    required this.code,
    required this.customerName,
    required this.status,
    this.totalAmount = 0,
    this.validUntil,
    required this.ownerUserId,
    this.updatedAt = '',
  });

  factory CrmQuoteSummary.fromJson(Map<String, dynamic> json) {
    return CrmQuoteSummary(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      validUntil: json['validUntil']?.toString(),
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return 'Bản nháp';
      case 'PENDING_APPROVAL':
        return 'Chờ phê duyệt';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'REJECTED':
        return 'Từ chối';
      case 'SENT':
        return 'Đã gửi khách';
      case 'ACCEPTED':
        return 'Khách đồng ý';
      case 'EXPIRED':
        return 'Hết hiệu lực';
      default:
        return status;
    }
  }
}

class CrmLeadSummary {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? source;
  final String status;
  final String ownerUserId;
  final String updatedAt;

  const CrmLeadSummary({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.source,
    required this.status,
    required this.ownerUserId,
    this.updatedAt = '',
  });

  factory CrmLeadSummary.fromJson(Map<String, dynamic> json) {
    return CrmLeadSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactName: json['contactName']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      source: json['source']?.toString(),
      status: json['status']?.toString() ?? 'NEW',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'NEW':
        return 'Mới tiếp nhận';
      case 'CONTACTED':
        return 'Đã liên hệ';
      case 'QUALIFIED':
        return 'Tiềm năng';
      case 'CONVERTED':
        return 'Đã chuyển đổi';
      case 'UNQUALIFIED':
        return 'Không phù hợp';
      default:
        return status;
    }
  }
}
