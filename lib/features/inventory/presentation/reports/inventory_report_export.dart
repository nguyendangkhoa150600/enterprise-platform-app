import '../../../../core/i18n/app_i18n.dart';
import '../../domain/reports/inventory_report_models.dart';
import '../utils/inventory_csv_exporter.dart';
import 'inventory_report_labels.dart';

/// Trang tính của báo cáo (web `ReportSheet` trong `inventory-reports.model.ts`).
class ReportSheet {
  final String name;
  final List<String> intro;
  final List<String> headers;
  final List<List<Object?>> rows;
  const ReportSheet({required this.name, required this.intro, required this.headers, required this.rows});
}

String _t(String key, [Map<String, Object?>? args]) => 'inventory.reports.$key'.tr(args: args);

/// Ghi các trang tính thành một tệp CSV (web ghi .xlsx nhiều trang tính).
/// Mỗi trang: dòng giới thiệu, dòng trống, tiêu đề cột, dữ liệu; nhiều trang thì có tên trang ở đầu và cách nhau một dòng trống.
Future<void> shareReportSheets(String fileName, List<ReportSheet> sheets) {
  final rows = <List<Object?>>[];
  final multi = sheets.length > 1;
  for (var i = 0; i < sheets.length; i++) {
    final s = sheets[i];
    if (i > 0) rows.add(const []);
    if (multi) rows.add([s.name]);
    rows.addAll(s.intro.map((line) => [line]));
    rows.add(const []);
    rows.add(s.headers);
    rows.addAll(s.rows);
  }
  return InventoryCsvExporter.share(fileName, rows);
}

List<String> get _quantityHeaders => [
  ReportLabels.onHand,
  ReportLabels.reserved,
  ReportLabels.blocked,
  ReportLabels.available,
];

/// Trang tính báo cáo tồn theo kiểu đang xem, kèm dòng tổng (web `stockReportSheet`).
ReportSheet stockReportSheet(StockReport report, StockReport rows, List<String> intro) {
  final total = _t('export.total_row');
  switch (report.groupBy) {
    case StockReportGroupBy.serial:
      final t = report.serialTotals;
      return ReportSheet(
        name: ReportLabels.groupLabel(StockReportGroupBy.serial),
        intro: [
          ...intro,
          _t('export.serial_totals', {
            'serials': t.serials,
            'inStock': t.inStock,
            'blocked': t.blocked,
            'available': t.available,
          }),
        ],
        headers: [
          _t('col.material_code'),
          _t('col.material_name'),
          _t('col.category'),
          _t('col.serial'),
          _t('col.warehouse'),
          _t('col.stock_state'),
          _t('col.quality'),
          _t('col.updated_at'),
        ],
        rows: rows.serialRows
            .map(
              (r) => <Object?>[
                r.materialCode,
                r.materialName,
                r.category ?? '',
                r.serialNumber,
                r.warehouseCode ?? '',
                r.stockState == null ? '' : ReportLabels.serialState(r.stockState),
                ReportLabels.quality(r.qualityStatus),
                ReportFormat.dateTime(r.updatedAt),
              ],
            )
            .toList(),
      );
    case StockReportGroupBy.lot:
      final t = report.quantityTotals;
      return ReportSheet(
        name: ReportLabels.groupLabel(StockReportGroupBy.lot),
        intro: intro,
        headers: [
          _t('col.material_code'),
          _t('col.material_name'),
          _t('col.unit'),
          _t('col.lot_no'),
          _t('col.warehouse'),
          _t('col.expires_on'),
          _t('col.days_left'),
          _t('col.quality'),
          ..._quantityHeaders,
        ],
        rows: [
          ...rows.lotRows.map(
            (r) => <Object?>[
              r.materialCode,
              r.materialName,
              r.unit ?? '',
              r.lotNo,
              r.warehouseCode,
              r.expiresOn ?? '',
              r.daysToExpiry ?? '',
              ReportLabels.quality(r.qualityStatus),
              r.qty.onHand,
              r.qty.reserved,
              r.qty.blocked,
              r.qty.available,
            ],
          ),
          [total, '', '', '', '', '', '', '', t.onHand, t.reserved, t.blocked, t.available],
        ],
      );
    case StockReportGroupBy.warehouse:
      final t = report.quantityTotals;
      return ReportSheet(
        name: ReportLabels.groupLabel(StockReportGroupBy.warehouse),
        intro: intro,
        headers: [
          _t('col.warehouse'),
          _t('col.warehouse_name'),
          _t('col.material_code'),
          _t('col.material_name'),
          _t('col.category'),
          _t('col.unit'),
          ..._quantityHeaders,
          _t('col.avg_cost'),
          _t('col.stock_value'),
        ],
        rows: [
          ...rows.warehouseRows.map(
            (r) => <Object?>[
              r.warehouseCode,
              r.warehouseName,
              r.materialCode,
              r.materialName,
              r.category ?? '',
              r.unit ?? '',
              r.qty.onHand,
              r.qty.reserved,
              r.qty.blocked,
              r.qty.available,
              r.avgCost,
              r.stockValue,
            ],
          ),
          [total, '', '', '', '', '', t.onHand, t.reserved, t.blocked, t.available, '', report.stockValueTotal ?? 0],
        ],
      );
  }
}

List<String> get _amountHeaders => [
  _t('col.qty_in'),
  _t('col.qty_out'),
  _t('col.value_in'),
  _t('col.value_out'),
  _t('col.entries'),
];

/// Ba trang tính của báo cáo nhập xuất (web `movementReportSheets`).
List<ReportSheet> movementReportSheets(StockMovementReport report, List<StockMovementLine> lines, List<String> intro) {
  return [
    ReportSheet(
      name: _t('export.sheet_summary'),
      intro: intro,
      headers: [_t('col.group'), ..._amountHeaders],
      rows: [
        ...report.summary.map((r) => <Object?>[ReportLabels.movementCategory(r.category), ...r.amounts.cells]),
        [_t('export.total_row'), ...report.totals.cells],
      ],
    ),
    ReportSheet(
      name: _t('export.sheet_breakdown'),
      intro: intro,
      headers: [_t('col.group'), _t('col.doc_type'), _t('col.warehouse'), _t('col.warehouse_name'), ..._amountHeaders],
      rows: report.breakdown
          .map(
            (r) => <Object?>[
              ReportLabels.movementCategory(r.category),
              r.docType == null ? _t('movements.no_document') : ReportLabels.docType(r.docType),
              r.warehouseCode,
              r.warehouseName,
              ...r.amounts.cells,
            ],
          )
          .toList(),
    ),
    ReportSheet(
      name: _t('export.sheet_lines'),
      intro: intro,
      headers: [
        _t('col.posted_at'),
        _t('col.transaction_code'),
        _t('col.document'),
        _t('col.doc_type'),
        _t('col.group'),
        _t('col.reverses'),
        _t('col.warehouse'),
        _t('col.material_code'),
        _t('col.material_name'),
        _t('col.unit'),
        _t('col.quantity'),
        _t('col.unit_cost'),
        _t('col.value'),
        _t('col.note'),
      ],
      rows: lines
          .map(
            (l) => <Object?>[
              ReportFormat.dateTime(l.postedAt),
              l.transactionCode,
              l.documentCode ?? '',
              l.docType == null ? '' : ReportLabels.docType(l.docType),
              ReportLabels.movementCategory(l.category),
              l.reversesDocumentCode ?? '',
              l.warehouseCode,
              l.materialCode,
              l.materialName,
              l.unit ?? '',
              l.quantity,
              l.unitCost,
              l.value,
              l.note ?? '',
            ],
          )
          .toList(),
    ),
  ];
}

/// Trang tính lịch sử duyệt; người thực hiện ghi theo id người dùng (web `approvalReportSheet`).
ReportSheet approvalReportSheet(List<StockApprovalReportRow> rows, List<String> intro) {
  String dt(String? v) => v == null ? '' : ReportFormat.dateTime(v);
  return ReportSheet(
    name: _t('view.approvals'),
    intro: intro,
    headers: [
      _t('col.document'),
      _t('col.type'),
      _t('col.status'),
      _t('col.document_date'),
      _t('col.warehouse'),
      _t('col.reason'),
      _t('col.created_by'),
      _t('col.submitted_at'),
      _t('col.approved_by'),
      _t('col.approved_at'),
      _t('col.rejected_by'),
      _t('col.rejected_at'),
      _t('col.reject_reason'),
      _t('col.posted_at_doc'),
      _t('col.qty_increase'),
      _t('col.qty_decrease'),
      _t('col.value'),
    ],
    rows: rows
        .map(
          (r) => <Object?>[
            r.documentCode,
            ReportLabels.docType(r.docType),
            ReportLabels.docStatus(r.status),
            r.documentDate,
            r.warehouseCode,
            r.reason ?? '',
            r.createdBy,
            dt(r.submittedAt),
            r.approvedBy ?? '',
            dt(r.approvedAt),
            r.rejectedBy ?? '',
            dt(r.rejectedAt),
            r.rejectReason ?? '',
            dt(r.postedAt),
            r.quantityIn,
            r.quantityOut,
            r.value,
          ],
        )
        .toList(),
  );
}
