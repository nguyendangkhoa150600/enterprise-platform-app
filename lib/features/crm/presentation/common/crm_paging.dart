import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../domain/common/crm_page.dart';
import '../utils/crm_scope.dart';

/// Web `pageCountOf`: số trang từ tổng số dòng; danh sách rỗng vẫn là một trang.
int crmPageCount(int total, int pageSize) {
  final size = pageSize < 1 ? 1 : pageSize;
  return total <= 0 ? 1 : (total + size - 1) ~/ size;
}

/// Web `pageItems`: các ô số trang (trang đầu, cuối và [around] trang mỗi bên trang đang xem); `null` là dấu `…`.
List<int?> crmPageItems(int current, int pageCount, {int around = 2}) {
  if (pageCount <= 1) return const [1];
  final page = current.clamp(1, pageCount);
  final keep = <int>{1, pageCount};
  for (var i = page - around; i <= page + around; i++) {
    if (i >= 1 && i <= pageCount) keep.add(i);
  }
  final sorted = keep.toList()..sort();
  final items = <int?>[];
  for (var i = 0; i < sorted.length; i++) {
    final value = sorted[i];
    if (i > 0) {
      final previous = sorted[i - 1];
      if (value - previous == 2) {
        items.add(previous + 1);
      } else if (value - previous > 2) {
        items.add(null);
      }
    }
    items.add(value);
  }
  return items;
}

/// Danh sách phân trang theo số trang (web `usePagedList`): API trả `total` nên chọn được trang bất kỳ.
/// [setKey] (đổi bộ lọc) về trang 1 và tải lại; [reload] tải lại trang đang xem; [goTo] sang trang khác.
/// Kết quả của lần tải cũ (bộ lọc trước) bị bỏ. Gọi [dispose] trong `State.dispose`.
///
/// ```dart
/// late final _list = CrmPagedListController<Lead>(
///   load: (page) => repo.listLeads(LeadListQuery(q: _q, page: page, limit: kCrmListPageSize)),
/// )..reload();
/// // bộ lọc đổi: _list.setKey('$_q|$_status');
/// ```
class CrmPagedListController<T> extends ChangeNotifier {
  CrmPagedListController({required this.load, this.pageSize = kCrmListPageSize, String key = ''}) : _key = key;

  /// Tải trang [page] (từ 1) theo bộ lọc hiện tại của màn.
  final Future<CrmPage<T>> Function(int page) load;
  final int pageSize;

  String _key;
  int _page = 1;
  List<T> _items = const [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _request = 0;
  bool _disposed = false;

  int get page => _page;
  List<T> get items => _items;
  int get total => _total;
  bool get loading => _loading;

  /// Lời nhắn lỗi đã dịch (null: không lỗi).
  String? get error => _error;
  int get pageCount => crmPageCount(_total, pageSize);

  /// Đã tải xong ít nhất một lần (phân biệt "đang tải lần đầu" với "rỗng").
  bool get loaded => _loadedOnce;
  bool _loadedOnce = false;

  /// Đổi bộ lọc: về trang 1 và tải lại (khoá giống cũ thì bỏ qua).
  void setKey(String key) {
    if (key == _key) return;
    _key = key;
    _page = 1;
    unawaited(_fetch());
  }

  /// Tải lại trang đang xem.
  Future<void> reload() => _fetch();

  void goTo(int page) {
    final next = page < 1 ? 1 : page;
    if (next == _page && !_loading) return;
    _page = next;
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final id = ++_request;
    _loading = true;
    _notify();
    try {
      final result = await load(_page);
      if (id != _request || _disposed) return;
      _items = result.items;
      _total = result.total ?? result.items.length;
      _error = null;
    } catch (e) {
      if (id != _request || _disposed) return;
      CrmScope.instance.onError(e);
      _error = crmErrorMessage(e, 'crm.common.error_list');
    }
    _loading = false;
    _loadedOnce = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Danh sách keyset "Tải thêm" (`nextCursor`, vd. dòng thời gian khách hàng): [refresh] tải lại từ đầu,
/// [loadMore] nối trang sau khi [hasMore].
class CrmCursorListController<T> extends ChangeNotifier {
  CrmCursorListController({required this.load});

  /// Tải trang bắt đầu từ [cursor] (null: trang đầu).
  final Future<CrmPage<T>> Function(String? cursor) load;

  List<T> _items = const [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _request = 0;
  bool _disposed = false;
  bool _loadedOnce = false;

  List<T> get items => _items;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _cursor != null && _cursor!.isNotEmpty;
  String? get error => _error;
  bool get loaded => _loadedOnce;

  Future<void> refresh() async {
    final id = ++_request;
    _loading = true;
    _loadingMore = false;
    _notify();
    try {
      final result = await load(null);
      if (id != _request || _disposed) return;
      _items = result.items;
      _cursor = result.nextCursor;
      _error = null;
    } catch (e) {
      if (id != _request || _disposed) return;
      CrmScope.instance.onError(e);
      _error = crmErrorMessage(e, 'crm.common.error_list');
    }
    _loading = false;
    _loadedOnce = true;
    _notify();
  }

  Future<void> loadMore() async {
    if (!hasMore || _loading || _loadingMore) return;
    final id = _request;
    _loadingMore = true;
    _notify();
    try {
      final result = await load(_cursor);
      if (id != _request || _disposed) return;
      _items = [..._items, ...result.items];
      _cursor = result.nextCursor;
      _error = null;
    } catch (e) {
      if (id != _request || _disposed) return;
      _error = crmErrorMessage(e, 'crm.common.error_list');
    }
    _loadingMore = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Web `useDebounced`: gọi [run] sau [delay] kể từ lần gọi cuối (ô tìm không gọi API mỗi phím). Gọi [dispose].
class CrmDebouncer {
  CrmDebouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
