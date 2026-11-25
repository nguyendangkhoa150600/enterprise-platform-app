import 'package:flutter/foundation.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/inventory_api_client.dart';
import '../../domain/inventory_capabilities.dart';
import '../../domain/inventory_exception.dart';

/// Quyền giao diện module Kho, tải một lần từ `/capabilities` và dùng chung cho mọi màn Kho.
/// Lỗi tải quyền → [InventoryCapabilities.none] (ẩn nút thao tác, như web mặc định `false`).
class InventoryScope {
  InventoryScope._();
  static final InventoryScope instance = InventoryScope._();

  final ValueNotifier<InventoryCapabilities> capabilities = ValueNotifier(InventoryCapabilities.none);
  DateTime? _loadedAt;
  Future<InventoryCapabilities>? _inflight;
  int _generation = 0;

  static const Duration _maxAge = Duration(minutes: 2);

  Future<InventoryCapabilities> ensureCapabilities({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < _maxAge;
    if (!force && fresh) return Future.value(capabilities.value);
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  Future<InventoryCapabilities> _load() async {
    final generation = _generation;
    try {
      final res = await InventoryApiClient.instance.get('/capabilities');
      if (generation != _generation) return InventoryCapabilities.none;
      final caps = res is Map ? InventoryCapabilities.fromJson(Map<String, dynamic>.from(res)) : InventoryCapabilities.none;
      capabilities.value = caps;
      _loadedAt = DateTime.now();
      return caps;
    } catch (_) {
      if (generation != _generation) return InventoryCapabilities.none;
      capabilities.value = InventoryCapabilities.none;
      _loadedAt = null;
      return InventoryCapabilities.none;
    }
  }

  /// Thao tác bị 403: tải lại quyền.
  void onError(Object error) {
    if (error is InventoryException && error.isForbidden) ensureCapabilities(force: true);
  }

  /// Đăng xuất / đổi tổ chức.
  void reset() {
    _generation++;
    _inflight = null;
    _loadedAt = null;
    capabilities.value = InventoryCapabilities.none;
  }
}

/// Lời nhắn lỗi cho người dùng: ưu tiên lời nhắn server, không có thì [fallbackKey] đã dịch.
String inventoryErrorMessage(Object? error, [String fallbackKey = 'inventory.common.error_generic']) {
  if (error is InventoryException) {
    final m = error.message;
    if (m != null && m.isNotEmpty) return m;
    if (error.isForbidden) return 'inventory.common.error_forbidden'.tr();
  }
  return fallbackKey.tr();
}
