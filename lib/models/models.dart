import 'package:excel/excel.dart' as ex;

class Project {
  final int? projectId;
  final String projectName;
  final String? projectAddress;
  final String? projectDescription;
  final String? closeDate;

  Project({
    this.projectId,
    required this.projectName,
    this.projectAddress,
    this.projectDescription,
    this.closeDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['project_id'] != null ? int.tryParse(json['project_id'].toString()) : null,
      projectName: json['project_name'] ?? '',
      projectAddress: json['project_address'],
      projectDescription: json['project_description'],
      closeDate: json['close_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (projectId != null) 'project_id': projectId,
      'project_name': projectName,
      'project_address': projectAddress,
      'project_description': projectDescription,
      'close_date': closeDate,
    };
  }
}

class TestingMedia {
  final int mediaId;
  final String? mediaName;
  final String? mediaType;
  final String? mediaReferenceType;
  final String? mediaUrl;

  TestingMedia({
    required this.mediaId,
    this.mediaName,
    this.mediaType,
    this.mediaReferenceType,
    this.mediaUrl,
  });

  factory TestingMedia.fromJson(Map<String, dynamic> json) {
    return TestingMedia(
      mediaId: int.tryParse(json['media_id'].toString()) ?? 0,
      mediaName: json['media_name'],
      mediaType: json['media_type'],
      mediaReferenceType: json['media_reference_type'],
      mediaUrl: json['media_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media_id': mediaId,
      'media_name': mediaName,
      'media_type': mediaType,
      'media_reference_type': mediaReferenceType,
      'media_url': mediaUrl,
    };
  }
}

class Testing {
  final int? testingId;
  final String testingName;
  final String testingStatus;
  final int projectId;
  final List<TestingMedia> media;

  Testing({
    this.testingId,
    required this.testingName,
    required this.testingStatus,
    required this.projectId,
    this.media = const [],
  });

  factory Testing.fromJson(Map<String, dynamic> json) {
    var mediaList = json['media'] as List?;
    return Testing(
      testingId: json['testing_id'] != null ? int.tryParse(json['testing_id'].toString()) : null,
      testingName: json['testing_name'] ?? '',
      testingStatus: json['testing_status'] ?? 'pending',
      projectId: int.tryParse((json['project_id'] ?? 0).toString()) ?? 0,
      media: mediaList != null
          ? mediaList.map((m) => TestingMedia.fromJson(m)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (testingId != null) 'testing_id': testingId,
      'testing_name': testingName,
      'testing_status': testingStatus,
      'project_id': projectId,
    };
  }
}

class TableColumn {
  final String key;
  final String label;

  TableColumn({required this.key, required this.label});
}

class WorkbookTable {
  final String title;
  final List<TableColumn> columns;
  final List<Map<String, dynamic>> rows;

  WorkbookTable({
    required this.title,
    required this.columns,
    required this.rows,
  });

  static WorkbookTable fromExcelSheet(String sheetName, List<List<ex.Data?>> excelRows) {
    if (excelRows.isEmpty) {
      return WorkbookTable(title: sheetName, columns: [], rows: []);
    }

    // Determine the columns based on the first row's values
    final columns = <TableColumn>[];
    final firstRow = excelRows.first;

    for (int colIndex = 0; colIndex < firstRow.length; colIndex++) {
      final cell = firstRow[colIndex];
      final key = 'col_$colIndex';
      final cellVal = cell?.value;
      
      // Clean display label
      String label = cellVal != null ? cellVal.toString().trim() : '';
      if (label.isEmpty) {
        label = 'Cột ${colIndex + 1}';
      }
      columns.add(TableColumn(key: key, label: label));
    }

    final rows = <Map<String, dynamic>>[];
    // Populate rows (skip header row)
    for (int rowIndex = 1; rowIndex < excelRows.length; rowIndex++) {
      final rowData = excelRows[rowIndex];
      final rowMap = <String, dynamic>{};
      
      for (int colIndex = 0; colIndex < columns.length; colIndex++) {
        final colKey = columns[colIndex].key;
        if (colIndex < rowData.length) {
          final cell = rowData[colIndex];
          final val = cell?.value;
          rowMap[colKey] = val != null ? val.toString() : '';
        } else {
          rowMap[colKey] = '';
        }
      }
      rows.add(rowMap);
    }

    return WorkbookTable(
      title: sheetName,
      columns: columns,
      rows: rows,
    );
  }
}

class PowerQualityAnalysisDataset {
  final List<WorkbookTable> summaryTables;
  final List<WorkbookTable> harmonicTables;
  final List<WorkbookTable> statisticTables;
  final List<WorkbookTable> otherTables;

  PowerQualityAnalysisDataset({
    required this.summaryTables,
    required this.harmonicTables,
    required this.statisticTables,
    required this.otherTables,
  });

  factory PowerQualityAnalysisDataset.fromExcelBytes(List<int> bytes) {
    final excel = ex.Excel.decodeBytes(bytes);
    final summary = <WorkbookTable>[];
    final harmonics = <WorkbookTable>[];
    final statistics = <WorkbookTable>[];
    final other = <WorkbookTable>[];

    final summaryRegex = RegExp(r'(summary|tdd|thd)', caseSensitive: false);
    final harmonicsRegex = RegExp(r'harmonics', caseSensitive: false);
    final statisticsRegex = RegExp(r'statistics', caseSensitive: false);

    for (var tableEntry in excel.tables.entries) {
      final sheetName = tableEntry.key;
      final sheet = tableEntry.value;

      // Extract rows from the sheet
      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      final workbookTable = WorkbookTable.fromExcelSheet(sheetName, rows);

      if (summaryRegex.hasMatch(sheetName)) {
        summary.add(workbookTable);
      } else if (harmonicsRegex.hasMatch(sheetName)) {
        harmonics.add(workbookTable);
      } else if (statisticsRegex.hasMatch(sheetName)) {
        statistics.add(workbookTable);
      } else {
        other.add(workbookTable);
      }
    }

    // Fallback if all lists are empty, treat all as other tables
    if (summary.isEmpty && harmonics.isEmpty && statistics.isEmpty && other.isEmpty) {
      for (var tableEntry in excel.tables.entries) {
        final sheetName = tableEntry.key;
        final sheet = tableEntry.value;
        if (sheet.rows.isNotEmpty) {
          other.add(WorkbookTable.fromExcelSheet(sheetName, sheet.rows));
        }
      }
    }

    return PowerQualityAnalysisDataset(
      summaryTables: summary,
      harmonicTables: harmonics,
      statisticTables: statistics,
      otherTables: other,
    );
  }
}
