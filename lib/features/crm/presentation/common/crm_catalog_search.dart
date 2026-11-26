import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_catalog_models.dart';
import '../utils/crm_scope.dart';
import 'crm_paging.dart';
import 'crm_select.dart';
import 'crm_ui.dart';

/// Nhãn nhóm mặt hàng ở Kho (web `catalogKindLabel`): dịch vụ hay hàng hoá.
String crmCatalogKindLabel(String? kind) =>
    (kind == CrmCatalogKind.service ? 'crm.catalog.kind_service' : 'crm.catalog.kind_stock').tr();

List<CrmSelectOption> _kindOptions() =>
    CrmCatalogKind.values.map((k) => CrmSelectOption(value: k, label: crmCatalogKindLabel(k))).toList();

/// Tìm mặt hàng theo trang (web `useCatalogSearch`): xếp theo mã, đánh số 1, 2, 3. Kho phân trang theo cursor và
/// không trả tổng số, nên số trang là các trang đã biết: tải xong trang N mà còn hàng thì biết thêm trang N + 1. Đổi
/// từ khoá (debounce 300 ms), nhóm hoặc phân loại thì về trang 1. Gọi [dispose].
class CrmCatalogSearchController extends ChangeNotifier {
  CrmCatalogSearchController({this.pricedFor, String initialSearch = ''}) : _search = initialSearch {
    _query = initialSearch.trim();
    _loadTradeCategories();
    _restart();
  }

  /// Chỉ mặt hàng có giá bán cho phiên bản báo giá này.
  final ({String quoteId, int versionNo})? pricedFor;

  final CrmDebouncer _debouncer = CrmDebouncer();
  String _search;
  String _query = '';
  String _kind = '';
  String _tradeCategory = '';
  List<String> _tradeCategories = const [];
  List<CrmCatalogMaterial> _items = const [];

  /// Cursor mở đầu từng trang đã biết: `[null]` là chỉ biết trang 1.
  List<String?> _starts = const [null];
  int _page = 1;
  bool _loading = false;
  String? _error;
  int _request = 0;
  int _categoryRequest = 0;
  bool _disposed = false;

  String get search => _search;
  String get kind => _kind;
  String get tradeCategory => _tradeCategory;
  List<String> get tradeCategories => _tradeCategories;
  List<CrmCatalogMaterial> get items => _items;
  int get page => _page;

  /// Số trang đã biết (trang cuối có thể còn trang sau khi mở tới).
  int get pageCount => _starts.length;
  bool get loading => _loading;
  String? get error => _error;

  void setSearch(String value) {
    _search = value;
    _debouncer.run(() {
      final next = _search.trim();
      if (next == _query) return;
      _query = next;
      _restart();
    });
  }

  /// Đổi nhóm thì bỏ phân loại đang lọc (phân loại riêng cho hàng hoá, dịch vụ).
  void setKind(String? value) {
    _kind = value ?? '';
    _tradeCategory = '';
    _loadTradeCategories();
    _restart();
  }

  void setTradeCategory(String? value) {
    _tradeCategory = value ?? '';
    _restart();
  }

  void goTo(int target) {
    if (target < 1 || target > _starts.length || target == _page || _loading) return;
    _load(target, _starts[target - 1]);
  }

  void retry() => _load(_page, _starts[_page - 1]);

  void _restart() {
    _starts = const [null];
    _load(1, null);
  }

  Future<void> _load(int target, String? cursor) async {
    final id = ++_request;
    _loading = true;
    _notify();
    try {
      final result = await CrmScope.instance.repository.searchCatalog(
        search: _query,
        cursor: cursor,
        kind: _kind,
        tradeCategory: _tradeCategory,
        pricedFor: pricedFor,
      );
      if (id != _request || _disposed) return;
      _items = result.items;
      _page = target;
      final known = _starts.take(target).toList();
      _starts = result.nextCursor != null ? [...known, result.nextCursor] : known;
      _error = null;
    } catch (e) {
      if (id != _request || _disposed) return;
      _error = crmErrorMessage(e, 'crm.catalog.load_error');
    }
    _loading = false;
    _notify();
  }

  /// Danh sách phân loại theo nhóm đang lọc; lỗi thì chỉ mất ô lọc, vẫn tìm được.
  Future<void> _loadTradeCategories() async {
    final id = ++_categoryRequest;
    try {
      final names = await CrmScope.instance.repository.listCatalogTradeCategories(_kind.isEmpty ? null : _kind);
      if (id != _categoryRequest || _disposed) return;
      _tradeCategories = names;
    } catch (_) {
      if (id != _categoryRequest || _disposed) return;
      _tradeCategories = const [];
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debouncer.dispose();
    super.dispose();
  }
}

/// Ô tìm + lọc nhóm + lọc phân loại đặt trên danh sách mặt hàng (web `CatalogSearchBar`).
class CrmCatalogSearchBar extends StatelessWidget {
  final CrmCatalogSearchController catalog;
  const CrmCatalogSearchBar({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrmSearchField(
          initialValue: catalog.search,
          hint: 'crm.catalog.search_placeholder'.tr(),
          debounce: Duration.zero,
          onChanged: catalog.setSearch,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CrmFilterChip(
              placeholder: 'crm.catalog.all_kinds'.tr(),
              value: catalog.kind,
              options: _kindOptions(),
              searchable: false,
              onChanged: catalog.setKind,
            ),
            CrmFilterChip(
              placeholder: 'crm.catalog.all_categories'.tr(),
              value: catalog.tradeCategory,
              options: catalog.tradeCategories.map((n) => CrmSelectOption(value: n, label: n)).toList(),
              emptyText: 'crm.catalog.no_categories'.tr(),
              onChanged: catalog.setTradeCategory,
            ),
          ],
        ),
      ],
    );
  }
}

/// Thanh trang dưới danh sách mặt hàng (web `CatalogPager`): Trước, 1 2 3 (các trang đã biết), Sau. Ẩn khi 1 trang.
class CrmCatalogPager extends StatelessWidget {
  final CrmCatalogSearchController catalog;
  const CrmCatalogPager({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final page = catalog.page;
    final count = catalog.pageCount;
    if (count <= 1) return const SizedBox.shrink();
    Widget button(String label, VoidCallback? onTap, {bool current = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: current ? CrmColors.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: current ? CrmColors.primary : CrmColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: current ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: current ? Colors.white : (onTap == null ? CrmColors.faint : CrmColors.body),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            'crm.catalog.page'.tr(args: {'page': page}),
            style: const TextStyle(fontSize: 12, color: CrmColors.muted),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button('crm.common.prev'.tr(), page <= 1 || catalog.loading ? null : () => catalog.goTo(page - 1)),
                for (var i = 1; i <= count; i++)
                  button('$i', catalog.loading && i != page ? null : () => catalog.goTo(i), current: i == page),
                button('crm.common.next'.tr(), page >= count || catalog.loading ? null : () => catalog.goTo(page + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
