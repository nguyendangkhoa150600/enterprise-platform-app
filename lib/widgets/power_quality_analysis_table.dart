import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class PowerQualityAnalysisTable extends StatefulWidget {
  final PowerQualityAnalysisDataset data;

  const PowerQualityAnalysisTable({super.key, required this.data});

  @override
  State<PowerQualityAnalysisTable> createState() => _PowerQualityAnalysisTableState();
}

class _PowerQualityAnalysisTableState extends State<PowerQualityAnalysisTable>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawTable = widget.data.otherTables.isNotEmpty
        ? widget.data.otherTables.first
        : widget.data.summaryTables.isNotEmpty
            ? widget.data.summaryTables.first
            : widget.data.harmonicTables.isNotEmpty
                ? widget.data.harmonicTables.first
                : widget.data.statisticTables.isNotEmpty
                    ? widget.data.statisticTables.first
                    : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.amber,
              unselectedLabelColor: AppColors.slate600,
              indicatorColor: AppColors.amber,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: const [
                Tab(text: 'Summary Tables'),
                Tab(text: 'Harmonics Details'),
                Tab(text: 'Power Statistics'),
                Tab(text: 'Raw Data'),
              ],
            ),
          ),

          // Tab Views
          SizedBox(
            height: 560,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableList(widget.data.summaryTables, 'Không có dữ liệu Summary.'),
                _buildTableList(widget.data.harmonicTables, 'Không có dữ liệu Harmonics.'),
                _buildTableList(widget.data.statisticTables, 'Không có dữ liệu Statistics.'),
                rawTable != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildExcelTable(rawTable),
                      )
                    : const Center(
                        child: Text(
                          'Không có bảng Excel thô nào được chọn để xem trước.',
                          style: TextStyle(color: AppColors.slate500, fontSize: 13),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList(List<WorkbookTable> tables, String emptyMessage) {
    if (tables.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.slate500, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildExcelTable(table),
        );
      },
    );
  }

  Widget _buildExcelTable(WorkbookTable table) {
    if (table.columns.isEmpty) {
      return Container();
    }

    final firstRow = table.rows.isNotEmpty ? table.rows.first : null;
    final hasSupplemental = firstRow != null && !_hasNumericValue(firstRow);
    final bodyRows = hasSupplemental ? table.rows.sublist(1) : table.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Title
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            table.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.slate800,
            ),
          ),
        ),

        // Horizontally scrollable container
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border.fromBorderSide(BorderSide(color: AppColors.slate200)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.slate100),
                  headingRowHeight: hasSupplemental ? 76 : 40,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 32,
                  horizontalMargin: 12,
                  columnSpacing: 16,
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: AppColors.slate100, width: 1),
                  ),
                  columns: table.columns.map((col) {
                    // Check if headers have empty labels, display empty in that case
                    final displayLabel = col.label.toLowerCase().contains('empty') ? '' : col.label;
                    
                    return DataColumn(
                      label: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayLabel,
                            style: const TextStyle(
                              color: AppColors.slate800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          if (hasSupplemental) ...[
                            const SizedBox(height: 4),
                            Text(
                              firstRow[col.key]?.toString() ?? '',
                              style: const TextStyle(
                                color: AppColors.slate600,
                                fontWeight: FontWeight.normal,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  rows: bodyRows.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;
                    final isOdd = rowIndex % 2 == 1;

                    return DataRow(
                      color: WidgetStateProperty.all(isOdd ? AppColors.slate50 : Colors.white),
                      cells: table.columns.map((col) {
                        final val = row[col.key]?.toString() ?? '';
                        final displayDetails = _getCellPresentation(val);

                        return DataCell(
                          Text(
                            displayDetails.display,
                            style: TextStyle(
                              fontSize: 12,
                              color: displayDetails.textColor,
                              fontWeight: displayDetails.fontWeight,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Check if a row has any numeric values
  bool _hasNumericValue(Map<String, dynamic> row) {
    return row.values.any((val) {
      if (val == null) return false;
      final str = val.toString().trim();
      if (str.isEmpty) return false;
      return double.tryParse(str) != null;
    });
  }

  // Cell presentation helper (PASS/FAIL/values)
  _CellDisplayDetails _getCellPresentation(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _CellDisplayDetails(display: '', textColor: AppColors.slate800);
    }

    final upper = trimmed.toUpperCase();
    if (upper == 'PASS') {
      return _CellDisplayDetails(
        display: 'PASS',
        textColor: AppColors.emerald700,
        fontWeight: FontWeight.bold,
      );
    }
    if (upper == 'FAIL') {
      return _CellDisplayDetails(
        display: 'FAIL',
        textColor: Colors.red.shade700,
        fontWeight: FontWeight.bold,
      );
    }

    return _CellDisplayDetails(display: trimmed, textColor: AppColors.slate800);
  }
}

class _CellDisplayDetails {
  final String display;
  final Color textColor;
  final FontWeight fontWeight;

  _CellDisplayDetails({
    required this.display,
    required this.textColor,
    this.fontWeight = FontWeight.normal,
  });
}
