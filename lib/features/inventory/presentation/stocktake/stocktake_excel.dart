import '../../domain/stocktake/stocktake_models.dart';
import '../utils/inventory_sheet_io.dart';

/// Số đếm đọc từ một dòng Excel (web `codeToRow` trong `handleImportExcel`).
class StocktakeExcelHit {
  final double? actual;
  final String reason;
  final String? binLocation;
  const StocktakeExcelHit({this.actual, this.reason = '', this.binLocation});
}

/// Xuất/Nhập biên bản kiểm kê Excel như web `stocktake-hub.tsx` (`handleExportExcel` / `handleImportExcel`).
/// Tiêu đề cột giữ nguyên tiếng Việt như web để tệp xuất ra điền xong nhập lại được.
class StocktakeExcel {
  StocktakeExcel._();

  static const sheetName = 'KiemKe';

  static String fileName(String sessionCode) => 'Bien_Ban_Kiem_Ke_$sessionCode';

  /// Các dòng của trang 'KiemKe' (dòng đầu là tiêu đề), cùng cột với web.
  static List<List<Object?>> exportRows(List<InvStocktakeLine> lines) => [
        const ['STT', 'Mã vật tư', 'Tên vật tư', 'ĐVT', 'Vị trí kệ', 'Tồn sổ sách', 'Thực đếm', 'Lý do chênh lệch'],
        for (var i = 0; i < lines.length; i++)
          [
            i + 1,
            lines[i].materialCode,
            lines[i].materialName,
            lines[i].unit,
            lines[i].binLocation ?? '',
            _num(lines[i].systemQuantity),
            lines[i].actualQuantity == null ? '' : _num(lines[i].actualQuantity!),
            lines[i].reason ?? '',
          ],
      ];

  /// Đọc trang đầu tiên: mã vật tư (viết hoa, bỏ khoảng trắng) → số đếm/lý do/vị trí kệ.
  static Map<String, StocktakeExcelHit> parse(InventorySheetFile file) {
    final out = <String, StocktakeExcelHit>{};
    final sheet = file.first;
    if (sheet == null) return out;
    for (final row in sheet.records()) {
      final code = _pick(row, const ['Mã vật tư', 'Ma vat tu', 'Mã VT', 'Code']);
      if (code == null) continue;
      final actual = row.containsKey('Thực đếm') ? _jsNumber(row['Thực đếm']) : null;
      final reason = _pick(row, const ['Lý do chênh lệch', 'Ly do']);
      final bin = _pick(row, const ['Vị trí kệ', 'Vi tri ke', 'Vị trí', 'Vi tri']);
      final binText = bin == null ? null : _text(bin).trim();
      out[_text(code).trim().toUpperCase()] = StocktakeExcelHit(
        actual: actual,
        reason: reason == null ? '' : _text(reason),
        binLocation: binText,
      );
    }
    return out;
  }

  /// `a || b || c` của JS: lấy giá trị "truthy" đầu tiên.
  static Object? _pick(Map<String, Object?> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (_truthy(v)) return v;
    }
    return null;
  }

  static bool _truthy(Object? v) => switch (v) {
        null => false,
        String() => v.isNotEmpty,
        num() => v != 0 && !v.isNaN,
        bool() => v,
        _ => true,
      };

  static String _text(Object v) {
    if (v is double && v == v.truncateToDouble() && v.isFinite) return v.toInt().toString();
    return v.toString();
  }

  /// `Number(x)` của JS; không phải số → null (web bỏ qua NaN).
  static double? _jsNumber(Object? v) {
    final double? n = switch (v) {
      num() => v.toDouble(),
      bool() => v ? 1 : 0,
      String() => v.trim().isEmpty ? 0 : double.tryParse(v.trim()),
      _ => null,
    };
    return (n == null || n.isNaN) ? null : n;
  }

  static num _num(double v) => v == v.truncateToDouble() && v.isFinite ? v.toInt() : v;
}
