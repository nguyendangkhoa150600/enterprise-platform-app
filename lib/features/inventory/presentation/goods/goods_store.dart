import 'package:flutter/foundation.dart';
import '../../data/goods/goods_models.dart';
import '../../data/goods/goods_repository.dart';
import '../utils/inventory_scope.dart';

/// Trạng thái dùng chung của tab Hàng hóa, Nhà kho và các màn chi tiết mở từ đó.
/// Màn chi tiết nghe store này để hiện dữ liệu mới sau mỗi lần sửa, ngừng dùng, dùng lại.
class GoodsStore extends ChangeNotifier {
  GoodsWorkspace workspace = GoodsWorkspace.empty;
  GoodsCatalog catalog = GoodsCatalog.empty;
  bool loading = true;
  bool loaded = false;
  Object? error;
  bool _disposed = false;

  Future<void> reload() async {
    loading = true;
    _notify();
    try {
      final results = await Future.wait<Object>([
        GoodsRepository.instance.loadWorkspace(),
        // Danh mục lỗi thì các ô chọn tạm rỗng, như web khi chưa nạp được Cài đặt.
        GoodsRepository.instance.loadCatalog().catchError((_) => GoodsCatalog.empty),
      ]);
      workspace = results[0] as GoodsWorkspace;
      catalog = results[1] as GoodsCatalog;
      error = null;
      loaded = true;
    } catch (e) {
      error = e;
      InventoryScope.instance.onError(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Số dòng mỗi yêu cầu nhập Excel; 50 dòng dài nhất cũng còn xa mức 100 KB của máy chủ.
  static const importBatchSize = 50;

  /// Nhập hàng hóa từ Excel (web `TradeItemsPage.importRows`): thêm mục mới vào danh mục Cài đặt trước, rồi gửi
  /// theo lô [importBatchSize] dòng; lô lỗi thì mọi dòng của lô mang lời lỗi đó. Xong thì tải lại danh sách và
  /// danh mục. [catalogError]/[batchError] là lời nhắn mặc định khi lỗi không kèm lời của máy chủ.
  Future<GoodsImportResult> importTradeRows(
    List<Map<String, dynamic>> rows, {
    required List<String> goodsCategories,
    required List<String> serviceCategories,
    required List<String> usageModes,
    required String onConflict,
    required String Function(Object error) catalogError,
    required String Function(Object error) batchError,
  }) async {
    if (goodsCategories.length + serviceCategories.length + usageModes.length > 0) {
      try {
        await GoodsRepository.instance.addToTradeCatalog(
          goodsCategories: goodsCategories,
          serviceCategories: serviceCategories,
          usageModes: usageModes,
        );
      } catch (e) {
        // Không thêm được danh mục thì không nhập: dòng sẽ mang phân loại chưa khai báo.
        return GoodsImportResult(failures: [GoodsImportFailure(0, catalogError(e))]);
      }
    }
    var created = 0;
    var updated = 0;
    final skipped = <GoodsImportFailure>[];
    final failures = <GoodsImportFailure>[];
    for (var start = 0; start < rows.length; start += importBatchSize) {
      final end = start + importBatchSize > rows.length ? rows.length : start + importBatchSize;
      final batch = rows.sublist(start, end);
      try {
        final outcome = await GoodsRepository.instance.importMaterials(batch, onConflict);
        created += outcome.created;
        updated += outcome.updated;
        skipped.addAll(outcome.skipped);
        failures.addAll(outcome.failures);
      } catch (e) {
        final message = batchError(e);
        failures.addAll(batch.map((r) => GoodsImportFailure((r['line'] as num?)?.toInt() ?? 0, message)));
      }
    }
    await reload();
    return GoodsImportResult(created: created, updated: updated, skipped: skipped, failures: failures);
  }

  GoodsMaterial? materialByCode(String code) {
    for (final m in workspace.materials) {
      if (m.code == code) return m;
    }
    return null;
  }

  String warehouseName(String id) {
    for (final w in workspace.warehouses) {
      if (w.id == id) return w.name.isEmpty ? '—' : w.name;
    }
    return '—';
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
