import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/goods/goods_models.dart';

/// Quy tắc hiển thị, lọc, phân trang của tab Hàng hóa và Nhà kho (web `trade-items.model.ts`,
/// `inventory-labels.ts`).
class GoodsFormat {
  GoodsFormat._();

  /// Số dòng mỗi trang của bảng Hàng hóa và bảng Nhà kho.
  static const pageSizes = [15, 30, 45];

  /// Thuế suất VAT bên bán dùng khi mặt hàng chưa khai.
  static const defaultSaleVatRate = 10;

  static const _legacyUsage = {
    'SALE_ONLY': 'inventory.goods.usage_sale_only',
    'GIFT_ONLY': 'inventory.goods.usage_gift_only',
    'INTERNAL_ONLY': 'inventory.goods.usage_internal_only',
    'MULTI': 'inventory.goods.usage_multi',
  };

  /// Nhãn "Sử dụng"; mã cũ (SALE_ONLY…) đổi sang nhãn, không ghi đè dữ liệu.
  static String usageLabel(String? mode) {
    final v = (mode ?? '').trim();
    final key = _legacyUsage[v];
    return key == null ? v : key.tr();
  }

  /// 'GOODS' | 'SERVICE'.
  static String groupOf(GoodsMaterial m) => m.isService ? 'SERVICE' : 'GOODS';

  static String groupLabel(String group) =>
      group == 'SERVICE' ? 'inventory.goods.group_service'.tr() : 'inventory.goods.group_goods'.tr();

  static String statusLabel(String status) => switch (status) {
        'INACTIVE' => 'inventory.goods.status_inactive'.tr(),
        'ALL' => 'inventory.goods.status_all'.tr(),
        _ => 'inventory.goods.status_active'.tr(),
      };

  static String transactionTypeLabel(String type) {
    const known = {'IMPORT', 'EXPORT', 'TRANSFER_OUT', 'TRANSFER_IN', 'BORROW', 'RETURN', 'ADJUST'};
    return known.contains(type) ? 'inventory.goods.tx_$type'.tr() : type;
  }

  static List<String> categoriesOf(String group, GoodsCatalog catalog) =>
      group == 'SERVICE' ? catalog.serviceCategories : catalog.goodsCategories;

  /// Danh mục kèm giá trị đang dùng, để một lần sửa không làm mất giá trị admin đã bỏ khỏi danh mục.
  static List<String> withCurrent(List<String> options, String current) =>
      current.isNotEmpty && !options.contains(current) ? [...options, current] : options;

  static List<String> _distinct(Iterable<String?> values) {
    final out = <String>[];
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }
    return out;
  }

  /// Lựa chọn lọc "Phân loại": danh mục đã khai cộng giá trị mặt hàng đang dùng; có nhóm thì chỉ nhóm đó.
  static List<String> categoryChoices(List<GoodsMaterial> items, GoodsCatalog catalog, String group) {
    final groups = group.isEmpty ? ['GOODS', 'SERVICE'] : [group];
    final declared = groups.expand((g) => categoriesOf(g, catalog));
    final used = items.where((m) => group.isEmpty || groupOf(m) == group).map((m) => m.tradeCategory);
    return _distinct([...declared, ...used]);
  }

  /// Lựa chọn lọc "Sử dụng": danh mục đã khai cộng giá trị đang dùng (mã cũ đổi sang nhãn).
  static List<String> usageChoices(List<GoodsMaterial> items, GoodsCatalog catalog) =>
      _distinct([...catalog.usageModes, ...items.map((m) => usageLabel(m.tradeMode))]);

  /// So khớp không phân biệt hoa thường và dấu tiếng Việt.
  static String fold(String? value) {
    var s = (value ?? '').toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      var mapped = ch;
      for (final e in groups.entries) {
        if (e.value.contains(ch)) {
          mapped = e.key;
          break;
        }
      }
      buf.write(mapped);
    }
    s = buf.toString().replaceAll(RegExp('[̀-ͯ]'), '');
    return s;
  }

  static List<GoodsMaterial> filterTradeItems(
    List<GoodsMaterial> items, {
    required String search,
    required String group,
    required String category,
    required String usage,
    required String status,
  }) {
    final term = fold(search.trim());
    return items.where((m) {
      if (status == 'ACTIVE' && !m.isActive) return false;
      if (status == 'INACTIVE' && m.isActive) return false;
      if (group.isNotEmpty && groupOf(m) != group) return false;
      if (category.isNotEmpty && (m.tradeCategory ?? '').trim() != category) return false;
      if (usage.isNotEmpty && usageLabel(m.tradeMode) != usage) return false;
      if (term.isEmpty) return true;
      return [m.code, m.name, m.barcode].any((v) => fold(v).contains(term));
    }).toList();
  }

  static final _qty = NumberFormat('#,##0.###', 'vi_VN');
  static final _money = NumberFormat('#,##0', 'vi_VN');
  static final _rate = NumberFormat('#,##0.##', 'vi_VN');

  static String number(double v) => _qty.format(v);

  /// Giá bán; chưa khai (khác 0) hiện "—".
  static String salePrice(double? price) => price == null ? '—' : '${_money.format(price)} đ';

  /// Thuế suất VAT: `8,5%`; chưa khai thì nói rõ bên bán tính mặc định.
  static String vatRate(double? rate) => rate == null
      ? 'inventory.goods.vat_unset'.tr(args: {'rate': defaultSaleVatRate})
      : '${_rate.format(rate)}%';

  static String dateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  /// Đọc số kiểu Việt Nam (`45.000`, `8,5`) hoặc kiểu máy (`8.5`); rỗng → null, sai → NaN.
  static double? parseVnNumber(String raw) {
    var s = raw.trim().replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    return double.tryParse(s) ?? double.nan;
  }

  /// Thuế suất hợp lệ: 0 đến 100, tối đa 2 chữ số thập phân (khớp kiểm ở Kho).
  static bool isValidVatRate(double rate) =>
      rate.isFinite && rate >= 0 && rate <= 100 && ((rate * 100).round() - rate * 100).abs() < 1e-6;
}

/// Một trang của danh sách đã lọc (web `paginate`).
class GoodsPage<T> {
  final List<T> rows;
  final int page;
  final int pageCount;
  final int total;
  final int from;
  final int to;

  const GoodsPage(this.rows, this.page, this.pageCount, this.total, this.from, this.to);

  /// Số trang quá lớn (sau khi lọc ra ít dòng hơn) thì lùi về trang cuối.
  factory GoodsPage.of(List<T> all, int page, int pageSize) {
    final total = all.length;
    final pageCount = total == 0 ? 1 : (total / pageSize).ceil();
    final current = page.clamp(1, pageCount);
    final start = (current - 1) * pageSize;
    final rows = all.skip(start).take(pageSize).toList();
    return GoodsPage(rows, current, pageCount, total, total == 0 ? 0 : start + 1, start + rows.length);
  }
}
