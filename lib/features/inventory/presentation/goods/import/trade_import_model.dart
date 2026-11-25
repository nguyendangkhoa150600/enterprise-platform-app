import '../../../data/goods/goods_models.dart';
import '../../utils/inventory_sheet_io.dart';
import '../goods_format.dart';

/// Nhập hàng hóa, dịch vụ từ tệp Excel bất kỳ (web `trade-import.model.ts`): đọc tiêu đề, tự đoán cột nào là
/// trường nào rồi để người dùng chỉnh, sau đó quyết định giá trị lạ (phân loại, sử dụng chưa có trong Cài đặt)
/// và người tạo. Toàn bộ là hàm thuần; màn hình chỉ gọi.

/// Trường nhập; [labelKey] là khoá i18n nhãn, [exact] là tiêu đề (đã bỏ dấu, chữ thường) khớp nguyên văn.
class TradeImportField {
  final String key;
  final String labelKey;
  final bool required;
  final List<String> exact;
  const TradeImportField(this.key, this.labelKey, this.exact, {this.required = false});
}

/// Thứ tự cũng là thứ tự gán cột khi tự đoán: một cột chỉ thuộc một trường.
const List<TradeImportField> tradeImportFields = [
  TradeImportField('code', 'inventory.goods_import.field_code',
      ['ma', 'ma dich vu', 'ma san pham', 'ma hang hoa', 'ma hang', 'ma vat tu', 'ma sku', 'sku'],
      required: true),
  TradeImportField('name', 'inventory.goods_import.field_name',
      ['ten', 'ten dich vu', 'ten san pham', 'ten hang hoa', 'ten hang', 'ten vat tu'],
      required: true),
  TradeImportField('unit', 'inventory.goods_import.field_unit', ['don vi', 'don vi tinh', 'dvt'], required: true),
  TradeImportField('kind', 'inventory.goods_import.field_kind', ['loai', 'loai mat hang', 'loai hang', 'nhom']),
  TradeImportField('category', 'inventory.goods_import.field_category',
      ['phan loai', 'nhom', 'nhom dich vu', 'nhom san pham', 'nhom hang', 'nhom hang hoa']),
  TradeImportField('usage', 'inventory.goods_import.field_usage',
      ['su dung', 'su dung cho', 'loai dich vu', 'hinh thuc', 'hinh thuc kinh doanh']),
  TradeImportField('price', 'inventory.goods_import.field_price', ['gia ban', 'gia ban mac dinh']),
  TradeImportField('vat', 'inventory.goods_import.field_vat', [
    'thue suat vat',
    'thue suat vat (%)',
    'thue suat',
    'thue suat (%)',
    'thue suat gtgt',
    'thue gtgt',
    'thue vat',
    'vat',
    'vat (%)',
    '% vat',
  ]),
  TradeImportField('cost', 'inventory.goods_import.field_cost', ['gia von', 'gia von mac dinh', 'gia nhap']),
  TradeImportField('barcode', 'inventory.goods_import.field_barcode', ['barcode', 'ma vach']),
  TradeImportField('manufacturer', 'inventory.goods_import.field_manufacturer',
      ['nha san xuat', 'hang san xuat', 'hang sx', 'thuong hieu']),
  TradeImportField('description', 'inventory.goods_import.field_description',
      ['mo ta', 'ghi chu', 'thong tin dich vu', 'thong tin san pham', 'thong tin']),
  TradeImportField('createdBy', 'inventory.goods_import.field_created_by', ['nguoi tao']),
  TradeImportField('createdAt', 'inventory.goods_import.field_created_at', ['ngay tao']),
  TradeImportField('status', 'inventory.goods_import.field_status', ['trang thai']),
];

class TradeImportRow {
  /// Số dòng trong tệp (dòng 1 là tiêu đề).
  final int line;
  final Map<String, Object?> cells;
  const TradeImportRow(this.line, this.cells);
}

class TradeImportSheet {
  final List<String> headers;
  final List<TradeImportRow> rows;
  const TradeImportSheet(this.headers, this.rows);

  /// Trang đầu của tệp, như `XLSX.utils.sheet_to_json(..., { defval: '' })`: tiêu đề lấy từ dòng đầu.
  factory TradeImportSheet.from(InventorySheet? sheet) {
    if (sheet == null) return const TradeImportSheet([], []);
    final records = sheet.records();
    final headers = <String>[];
    if (sheet.rows.isNotEmpty) {
      // Cùng cách đặt tên của `records()` (tiêu đề trùng thêm hậu tố `_1`, `_2`).
      final seen = <String, int>{};
      for (final h in sheet.rows.first) {
        var key = h == null ? '' : h.toString().trim();
        if (key.isEmpty) continue;
        final n = seen[key];
        seen[key] = (n ?? 0) + 1;
        if (n != null) key = '${key}_$n';
        headers.add(key);
      }
    }
    return TradeImportSheet(headers, [for (var i = 0; i < records.length; i++) TradeImportRow(i + 2, records[i])]);
  }
}

/// Lỗi một dòng: khoá i18n kèm tham số, để hiện theo ngôn ngữ đang dùng.
class TradeImportError {
  final String key;
  final Map<String, Object> args;
  const TradeImportError(this.key, [this.args = const {}]);
}

class TradeBuiltRow {
  final int line;
  final Map<String, dynamic>? input;
  final TradeImportError? error;

  /// Mã lặp lại ngay trong tệp: dòng sau trùng dòng trước, không phải dữ liệu lỗi cần nhập lại.
  final bool duplicate;
  const TradeBuiltRow(this.line, {this.input, this.error, this.duplicate = false});
}

/// Cách xử lý một giá trị phân loại hoặc sử dụng chưa khai trong Cài đặt: thêm, bỏ trống hoặc ghép vào mục có sẵn.
class TradeValueDecision {
  static const add = '__add__';
  static const blank = '__blank__';
}

class TradeImportOptions {
  final Map<String, String> mapping;

  /// Loại cho các dòng không có giá trị ở cột Loại (hoặc khi không ghép cột Loại): 'GOODS' | 'SERVICE'.
  final String defaultKind;
  final GoodsCatalog catalog;

  /// Giá trị → lựa chọn ([TradeValueDecision.add], [TradeValueDecision.blank] hoặc tên mục có sẵn).
  /// Giá trị ngoài danh mục mà không có quyết định thì mặc định là thêm vào Cài đặt.
  final Map<String, String> categoryDecisions;
  final Map<String, String> usageDecisions;

  /// Người tạo cần để trống (đã nghỉ việc, xử lý sau); so khớp nguyên văn.
  final Set<String> blankAuthors;

  const TradeImportOptions({
    required this.mapping,
    required this.defaultKind,
    required this.catalog,
    this.categoryDecisions = const {},
    this.usageDecisions = const {},
    this.blankAuthors = const {},
  });
}

class TradeCatalogAdditions {
  final List<String> goodsCategories;
  final List<String> serviceCategories;
  final List<String> usageModes;
  const TradeCatalogAdditions(this.goodsCategories, this.serviceCategories, this.usageModes);

  bool get isEmpty => goodsCategories.isEmpty && serviceCategories.isEmpty && usageModes.isEmpty;
}

class TradeImportValues {
  final List<String> categories;
  final List<String> usages;
  final List<String> authors;
  const TradeImportValues(this.categories, this.usages, this.authors);
}

/// Độ dài tối đa của các cột chữ trong Kho (khớp `materials`).
const _textLimits = <String, int>{'code': 100, 'name': 255, 'unit': 50, 'barcode': 100, 'manufacturer': 180};

const _kindByFolded = <String, String>{'hang hoa': 'GOODS', 'vat tu': 'GOODS', 'dich vu': 'SERVICE'};

const _activeStatus = {'hoat dong', 'dang dung', 'dang hoat dong', 'active', 'con dung', '1', 'true'};

/// Giá trị ô thành chuỗi như `String(value)` của JS (số nguyên không có `.0`).
String tradeCellText(Object? value) {
  if (value == null) return '';
  if (value is DateTime) return value.toIso8601String();
  if (value is double && value.isFinite && value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString().trim();
}

String _fold(String value) => GoodsFormat.fold(value);

List<String> _valuesOf(TradeImportSheet sheet, String header) =>
    sheet.rows.map((r) => tradeCellText(r.cells[header])).where((v) => v.isNotEmpty).toList();

/// Cột "Nhóm" chỉ là loại mặt hàng khi mọi giá trị là Hàng hóa, Vật tư hoặc Dịch vụ; ngược lại là phân loại.
bool _looksLikeKindColumn(TradeImportSheet sheet, String header) {
  final values = _valuesOf(sheet, header);
  return values.isNotEmpty && values.every((v) => _kindByFolded[_fold(v)] != null);
}

/// Đoán cột cho từng trường theo tiêu đề; chỉ nhận khớp nguyên văn nên không ghép nhầm (vd. "Đơn vị quy đổi").
Map<String, String> detectTradeMapping(TradeImportSheet sheet) {
  final mapping = <String, String>{};
  final taken = <String>{};
  for (final field in tradeImportFields) {
    for (final candidate in sheet.headers) {
      if (taken.contains(candidate) || !field.exact.contains(_fold(candidate))) continue;
      if (field.key == 'kind' && !_looksLikeKindColumn(sheet, candidate)) continue;
      mapping[field.key] = candidate;
      taken.add(candidate);
      break;
    }
  }
  return mapping;
}

/// Tệp toàn dịch vụ thường có "dịch vụ" ngay trong tiêu đề cột mã hoặc tên; dùng làm gợi ý loại mặc định.
String guessTradeDefaultKind(TradeImportSheet sheet) {
  final joined = sheet.headers.map(_fold).join(' | ');
  return joined.contains('dich vu') && !joined.contains('san pham') && !joined.contains('hang hoa')
      ? 'SERVICE'
      : 'GOODS';
}

/// Số trong ô Excel hoặc chuỗi kiểu Việt ("1.250.000", "12,5"). Trả `NaN` nếu không đọc được.
double parseTradeAmount(Object? value) {
  if (value is num) return value.toDouble();
  final raw = tradeCellText(value).replaceAll(RegExp(r'\s'), '');
  if (raw.isEmpty) return double.nan;
  if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(raw)) {
    return double.tryParse(raw.replaceAll('.', '').replaceFirst(',', '.')) ?? double.nan;
  }
  if (RegExp(r'^\d+,\d+$').hasMatch(raw)) return double.tryParse(raw.replaceFirst(',', '.')) ?? double.nan;
  return double.tryParse(raw) ?? double.nan;
}

/// Thuế suất VAT theo điểm phần trăm: `8`, `8,5`, `"10%"`. Ô số định dạng phần trăm cho 0..1 (8% thành 0,08)
/// nên số lẻ dưới 1 bị coi là sai. Rỗng là `null`, sai là `NaN`.
double? parseTradeVatCell(Object? value) {
  if (value is num) {
    final v = value.toDouble();
    return v > 0 && v < 1 ? double.nan : (GoodsFormat.isValidVatRate(v) ? v : double.nan);
  }
  final raw = tradeCellText(value).replaceAll(RegExp(r'\s'), '');
  if (raw.isEmpty) return null;
  final parsed = parseTradeAmount(raw.endsWith('%') ? raw.substring(0, raw.length - 1) : raw);
  return GoodsFormat.isValidVatRate(parsed) ? parsed : double.nan;
}

/// "dd/mm/yyyy" hoặc "yyyy-mm-dd" (hoặc ô ngày) thành ISO theo múi giờ Việt Nam; sai thì `null`.
String? parseTradeImportDate(Object? value) {
  final raw = tradeCellText(value);
  if (raw.isEmpty) return null;
  int year, month, day;
  final vn = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})').firstMatch(raw);
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (vn != null) {
    day = int.parse(vn.group(1)!);
    month = int.parse(vn.group(2)!);
    year = int.parse(vn.group(3)!);
  } else if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  String pad(int n) => n.toString().padLeft(2, '0');
  final result = '$year-${pad(month)}-${pad(day)}T00:00:00+07:00';
  return DateTime.tryParse(result) == null ? null : result;
}

/// Mã vạch hỏng do lỗi mã hóa của hệ cũ (ký tự lạ như "·") thì bỏ, không nhập rác.
String? _cleanBarcode(String value) =>
    value.isNotEmpty && RegExp(r'^[\w\-./ ]+$').hasMatch(value) ? value : null;

String _cell(TradeImportRow row, Map<String, String> mapping, String key) {
  final header = mapping[key];
  return header == null ? '' : tradeCellText(row.cells[header]);
}

String? _kindOf(TradeImportRow row, TradeImportOptions options) {
  final value = _cell(row, options.mapping, 'kind');
  if (value.isEmpty) return options.defaultKind;
  return _kindByFolded[_fold(value)];
}

({String? value, bool add}) _resolveValue(String value, List<String> declared, Map<String, String> decisions) {
  if (value.isEmpty) return (value: null, add: false);
  // Danh mục trống nghĩa là tenant chưa khai báo gì: mọi giá trị trong tệp đều là mục mới.
  if (declared.contains(value)) return (value: value, add: false);
  final decision = decisions[value] ?? TradeValueDecision.add;
  if (decision.isEmpty || decision == TradeValueDecision.add) return (value: value, add: true);
  if (decision == TradeValueDecision.blank) return (value: null, add: false);
  return (value: decision, add: false);
}

List<TradeBuiltRow> buildTradeImportRows(TradeImportSheet sheet, TradeImportOptions options) {
  final mapping = options.mapping;
  final catalog = options.catalog;
  final seen = <String>{};
  String cell(TradeImportRow row, String key) => _cell(row, mapping, key);

  return sheet.rows.map((row) {
    final line = row.line;
    final code = cell(row, 'code').toUpperCase();
    final name = cell(row, 'name');
    final unit = cell(row, 'unit');
    if (code.isEmpty) return TradeBuiltRow(line, error: const TradeImportError('inventory.goods_import.err_missing_code'));
    if (name.isEmpty) return TradeBuiltRow(line, error: const TradeImportError('inventory.goods_import.err_missing_name'));
    if (unit.isEmpty) return TradeBuiltRow(line, error: const TradeImportError('inventory.goods_import.err_missing_unit'));
    if (seen.contains(code)) {
      return TradeBuiltRow(line,
          error: TradeImportError('inventory.goods_import.err_duplicate', {'code': code}), duplicate: true);
    }
    seen.add(code);
    // Cột trong DB có độ dài giới hạn; báo ngay ở bước xem trước thay vì để Kho từ chối lúc ghi.
    for (final e in _textLimits.entries) {
      final length = cell(row, e.key).length;
      if (length > e.value) {
        return TradeBuiltRow(line,
            error: TradeImportError('inventory.goods_import.err_too_long',
                {'field': 'inventory.goods_import.field_${e.key}', 'max': e.value, 'length': length}));
      }
    }

    final kind = _kindOf(row, options);
    if (kind == null) {
      return TradeBuiltRow(line,
          error: TradeImportError('inventory.goods_import.err_kind', {'value': cell(row, 'kind')}));
    }

    final category =
        _resolveValue(cell(row, 'category'), GoodsFormat.categoriesOf(kind, catalog), options.categoryDecisions);
    final usage = _resolveValue(cell(row, 'usage'), catalog.usageModes, options.usageDecisions);

    // null = không khai; NaN = sai.
    double? amount(String key) {
      final header = mapping[key];
      if (header == null || tradeCellText(row.cells[header]).isEmpty) return null;
      final parsed = parseTradeAmount(row.cells[header]);
      return parsed.isFinite && parsed >= 0 ? parsed : double.nan;
    }

    final salePrice = amount('price');
    if (salePrice != null && salePrice.isNaN) {
      return TradeBuiltRow(line, error: const TradeImportError('inventory.goods_import.err_price'));
    }
    final vatRate = mapping['vat'] != null ? parseTradeVatCell(row.cells[mapping['vat']]) : null;
    if (vatRate != null && vatRate.isNaN) {
      return TradeBuiltRow(line, error: const TradeImportError('inventory.goods.vat_invalid'));
    }
    final purchasePrice = amount('cost');
    if (purchasePrice != null && purchasePrice.isNaN) {
      return TradeBuiltRow(line, error: const TradeImportError('inventory.goods_import.err_cost'));
    }

    final createdAtText = cell(row, 'createdAt');
    final createdAt = parseTradeImportDate(row.cells[mapping['createdAt'] ?? '']);
    if (createdAtText.isNotEmpty && createdAt == null) {
      return TradeBuiltRow(line, error: TradeImportError('inventory.goods_import.err_date', {'value': createdAtText}));
    }

    final author = cell(row, 'createdBy');
    final statusText = cell(row, 'status');
    final barcode = _cleanBarcode(cell(row, 'barcode'));
    final manufacturer = cell(row, 'manufacturer');
    final description = cell(row, 'description');

    return TradeBuiltRow(line, input: <String, dynamic>{
      'line': line,
      'code': code,
      'name': name,
      'unit': unit,
      'category': 'CONSUMABLE',
      'kind': kind == 'SERVICE' ? 'SERVICE' : 'STOCK',
      'barcode': ?barcode,
      if (manufacturer.isNotEmpty) 'manufacturer': manufacturer,
      'tradeCategory': ?category.value,
      'tradeMode': ?usage.value,
      'salePrice': ?salePrice,
      'purchasePrice': ?purchasePrice,
      if (salePrice != null || purchasePrice != null) 'currency': 'VND',
      'vatRate': ?vatRate,
      if (description.isNotEmpty) 'description': description,
      'createdAt': ?createdAt,
      // Chuỗi rỗng là "không ghi người tạo": khác với bỏ trống ở tạo thường (lấy người đang đăng nhập).
      'createdBy': options.blankAuthors.contains(author) ? '' : author,
      'isActive': statusText.isEmpty ? true : _activeStatus.contains(_fold(statusText)),
    });
  }).toList();
}

/// Dòng của tệp gốc chưa nhập được, để sửa rồi nhập lại mà không dính dữ liệu đã có. Gồm dòng sai ở bước kiểm tra
/// và dòng Kho từ chối vì lỗi dữ liệu; không gồm dòng trùng mã. Lỗi `line` 0 (vd. không cập nhật được danh mục)
/// nghĩa là chưa nhập gì: mọi dòng hợp lệ đều còn lại.
List<int> tradeUnimportedLines(List<TradeBuiltRow> built, List<GoodsImportFailure> failures) {
  final nothingImported = failures.any((f) => f.line == 0);
  final failedByStore = failures.where((f) => !f.duplicate).map((f) => f.line).toSet();
  return built
      .where((row) {
        if (row.duplicate) return false;
        if (row.error != null) return true;
        return nothingImported || failedByStore.contains(row.line);
      })
      .map((row) => row.line)
      .toList();
}

/// Tệp gốc chỉ còn các dòng đã chọn, giữ nguyên tiêu đề, thứ tự cột và giá trị từng ô (dòng đầu là tiêu đề).
List<List<Object?>> tradeUnimportedRows(TradeImportSheet sheet, List<int> lines) {
  final wanted = lines.toSet();
  return [
    sheet.headers,
    for (final row in sheet.rows)
      if (wanted.contains(row.line)) [for (final h in sheet.headers) row.cells[h]],
  ];
}

/// Tên tệp dòng lỗi: `<tên gốc>_chua_nhap` (đuôi .xlsx do nơi ghi thêm).
String tradeUnimportedFileName(String sourceName) {
  final base = sourceName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return '${base.isEmpty ? 'tep' : base}_chua_nhap';
}

/// Giá trị phân loại và sử dụng chưa khai trong Cài đặt, kèm danh sách người tạo, để màn hình hỏi người dùng.
TradeImportValues collectTradeImportValues(TradeImportSheet sheet, TradeImportOptions options) {
  final categories = <String>{};
  final usages = <String>{};
  final authors = <String>{};
  for (final row in sheet.rows) {
    final kind = _kindOf(row, options);
    final category = _cell(row, options.mapping, 'category');
    if (kind != null && category.isNotEmpty && !GoodsFormat.categoriesOf(kind, options.catalog).contains(category)) {
      categories.add(category);
    }
    final usage = _cell(row, options.mapping, 'usage');
    if (usage.isNotEmpty && !options.catalog.usageModes.contains(usage)) usages.add(usage);
    final author = _cell(row, options.mapping, 'createdBy');
    if (author.isNotEmpty) authors.add(author);
  }
  List<String> sorted(Set<String> s) => s.toList()..sort();
  return TradeImportValues(sorted(categories), sorted(usages), sorted(authors));
}

/// Mục cần thêm vào Cài đặt để các dòng sắp nhập có phân loại, sử dụng hợp lệ.
TradeCatalogAdditions tradeCatalogAdditionsFor(List<TradeBuiltRow> rows, GoodsCatalog catalog) {
  final goods = <String>[];
  final services = <String>[];
  final usages = <String>[];
  void addTo(List<String> list, String v) {
    if (!list.contains(v)) list.add(v);
  }

  for (final row in rows) {
    final input = row.input;
    if (input == null) continue;
    final isService = input['kind'] == 'SERVICE';
    final category = input['tradeCategory'] as String?;
    if (category != null && !GoodsFormat.categoriesOf(isService ? 'SERVICE' : 'GOODS', catalog).contains(category)) {
      addTo(isService ? services : goods, category);
    }
    final usage = input['tradeMode'] as String?;
    if (usage != null && !catalog.usageModes.contains(usage)) addTo(usages, usage);
  }
  return TradeCatalogAdditions(goods, services, usages);
}
