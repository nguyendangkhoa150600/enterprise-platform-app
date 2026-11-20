/// Tổng hợp số liệu báo cáo Văn thư trong năm
class CorrespondenceReportTotals {
  final int incoming;
  final int outgoing;
  final int completed;
  final int open;
  final int late;

  const CorrespondenceReportTotals({
    this.incoming = 0,
    this.outgoing = 0,
    this.completed = 0,
    this.open = 0,
    this.late = 0,
  });

  factory CorrespondenceReportTotals.fromJson(Map<String, dynamic> json) {
    return CorrespondenceReportTotals(
      incoming: (json['incoming'] as num?)?.toInt() ?? 0,
      outgoing: (json['outgoing'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Một dòng trong bảng thống kê (theo tháng, loại văn bản, hoặc phòng ban)
class CorrespondenceReportRow {
  final String label;
  final int incoming;
  final int outgoing;
  final int completed;
  final int late;

  const CorrespondenceReportRow({
    required this.label,
    this.incoming = 0,
    this.outgoing = 0,
    this.completed = 0,
    this.late = 0,
  });

  factory CorrespondenceReportRow.fromJson(Map<String, dynamic> json) {
    return CorrespondenceReportRow(
      label: json['label']?.toString() ?? '',
      incoming: (json['incoming'] as num?)?.toInt() ?? 0,
      outgoing: (json['outgoing'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Dữ liệu báo cáo tổng hợp Văn thư theo năm (matching contracts-correspondence 1:1)
class CorrespondenceReport {
  final int year;
  final CorrespondenceReportTotals totals;
  final List<CorrespondenceReportRow> byMonth;
  final List<CorrespondenceReportRow> byType;
  final List<CorrespondenceReportRow> byUnit;

  const CorrespondenceReport({
    required this.year,
    this.totals = const CorrespondenceReportTotals(),
    this.byMonth = const [],
    this.byType = const [],
    this.byUnit = const [],
  });

  factory CorrespondenceReport.fromJson(Map<String, dynamic> json) {
    final rawTotals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    final rawByMonth = json['byMonth'] as List? ?? [];
    final rawByType = json['byType'] as List? ?? [];
    final rawByUnit = json['byUnit'] as List? ?? [];

    return CorrespondenceReport(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      totals: CorrespondenceReportTotals.fromJson(rawTotals),
      byMonth: rawByMonth
          .whereType<Map>()
          .map((r) => CorrespondenceReportRow.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      byType: rawByType
          .whereType<Map>()
          .map((r) => CorrespondenceReportRow.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      byUnit: rawByUnit
          .whereType<Map>()
          .map((r) => CorrespondenceReportRow.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}
