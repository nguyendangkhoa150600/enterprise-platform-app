import 'crm_json.dart';

/// Số dòng một trang của mọi danh sách trên giao diện CRM (contracts `CRM_LIST_PAGE_SIZE`).
const int kCrmListPageSize = 15;

/// Số dòng tối đa một trang (contracts `CRM_PAGE_LIMIT_MAX`).
const int kCrmPageLimitMax = 100;

/// Độ dài tối đa chuỗi tìm kiếm; dài hơn server trả 400 (contracts `CRM_SEARCH_MAX_LENGTH`).
const int kCrmSearchMaxLength = 100;

/// Trang kết quả (contracts `CrmPage<T>`): keyset (`nextCursor` rỗng khi hết) hoặc theo số trang (gọi kèm `page`
/// thì có [page] và [total]).
class CrmPage<T> {
  final List<T> items;
  final String? nextCursor;
  final int? page;
  final int? total;

  const CrmPage({required this.items, this.nextCursor, this.page, this.total});

  static CrmPage<T> empty<T>() => CrmPage<T>(items: const []);

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory CrmPage.fromJson(Object? raw, T Function(Map<String, dynamic> json) parse) {
    final json = CrmJson.map(raw);
    return CrmPage<T>(
      items: CrmJson.list(json['items'], parse),
      nextCursor: CrmJson.strOrNull(json['nextCursor']),
      page: CrmJson.intOrNull(json['page']),
      total: CrmJson.intOrNull(json['total']),
    );
  }
}
