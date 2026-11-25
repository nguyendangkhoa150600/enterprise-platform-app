import '../../../../../core/i18n/app_i18n.dart';
import '../../../data/goods/goods_models.dart';
import '../../utils/inventory_sheet_io.dart';

/// Tệp mẫu nhập hàng hóa (web `downloadTradeTemplate`): trang `HangHoa` (tiêu đề + 2 dòng mẫu) và trang
/// `HuongDan`. Tiêu đề, dòng mẫu giữ nguyên tiếng Việt như web vì bước ghép cột nhận diện theo tiêu đề này.
class TradeImportTemplate {
  TradeImportTemplate._();

  static const headers = [
    'Mã',
    'Tên',
    'Barcode',
    'Nhóm',
    'Phân loại',
    'Đơn vị',
    'Sử dụng',
    'Giá bán',
    'Giá vốn',
    'Nhà sản xuất',
    'Mô tả',
    'Người tạo',
    'Ngày tạo',
    'Trạng thái',
  ];

  /// Dòng mẫu: một hàng hóa và một dịch vụ; phân loại và sử dụng lấy từ danh mục của tenant để nhập lại là hợp lệ.
  static List<List<Object?>> rows(GoodsCatalog catalog) {
    final h = catalog.goodsCategories.isEmpty ? '' : catalog.goodsCategories.first;
    final s = catalog.serviceCategories.isEmpty ? '' : catalog.serviceCategories.first;
    final u = catalog.usageModes.isEmpty ? 'Chỉ bán' : catalog.usageModes.first;
    return [
      ['VT-001', 'Cáp điện 3 lõi', '8930000000011', 'Hàng hóa', h, 'Mét', u, 45000, 32000, 'Cadivi',
        'Cáp đồng bọc PVC, 3 lõi', 'Nguyễn Văn A', '14/08/2026', 'Hoạt động'],
      ['DV-001', 'Lắp đặt thiết bị', '', 'Dịch vụ', s, 'Gói', u, 5250000, '', '', 'Theo định mức ban hành', '', '',
        'Không hoạt động'],
    ];
  }

  /// Giải thích từng cột: (cột, bắt buộc, khoá i18n cách điền).
  static const _guide = [
    ('Mã', true, 'code'),
    ('Tên', true, 'name'),
    ('Barcode', false, 'barcode'),
    ('Nhóm', false, 'group'),
    ('Phân loại', false, 'category'),
    ('Đơn vị', true, 'unit'),
    ('Sử dụng', false, 'usage'),
    ('Giá bán', false, 'price'),
    ('Giá vốn', false, 'cost'),
    ('Nhà sản xuất', false, 'manufacturer'),
    ('Mô tả', false, 'description'),
    ('Người tạo', false, 'created_by'),
    ('Ngày tạo', false, 'created_at'),
    ('Trạng thái', false, 'status'),
  ];

  static Future<void> share(GoodsCatalog catalog) {
    final guide = <List<Object?>>[
      [
        'inventory.goods_import.guide_column'.tr(),
        'inventory.goods_import.guide_required'.tr(),
        'inventory.goods_import.guide_note'.tr(),
      ],
      for (final (column, required, key) in _guide)
        [
          column,
          (required ? 'inventory.goods_import.guide_yes' : 'inventory.goods_import.guide_no').tr(),
          'inventory.goods_import.guide_$key'.tr(),
        ],
    ];
    return InventorySheetIO.shareXlsx(
      'Mau_nhap_hang_hoa',
      {
        'HangHoa': [headers, ...rows(catalog)],
        'HuongDan': guide,
      },
      colWidths: {
        'HangHoa': [16, 34, 16, 12, 18, 10, 24, 14, 14, 16, 34, 18, 12, 18],
        'HuongDan': [14, 10, 100],
      },
    );
  }
}
