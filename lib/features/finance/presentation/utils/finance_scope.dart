import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/errors/finance_exception.dart';
import '../../domain/models/finance_models.dart';
import '../../domain/repositories/i_finance_repository.dart';
import 'finance_format.dart';

/// Điểm truy cập dùng chung của module Tài chính: một repository và bộ quyền (`/capabilities`) lưu tạm.
///
/// Giống web `FinancePermissionsProvider`: khi đang mở một trang Tài chính ([attach]) thì làm mới quyền 2 phút một lần;
/// quay lại app chỉ làm mới nếu đã quá 30 giây; server trả 403 thì làm mới ngay ([invalidate]). Tải quyền lỗi thì
/// [capabilities] về null và [error] giữ lời nhắn lỗi (web hiện lời nhắn này).
class FinanceScope with WidgetsBindingObserver {
  FinanceScope._();
  static final FinanceScope instance = FinanceScope._();

  final IFinanceRepository repository = FinanceRepositoryImpl();

  final ValueNotifier<FinanceCapabilities?> capabilities = ValueNotifier<FinanceCapabilities?>(null);

  /// Lời nhắn lỗi của lần tải quyền gần nhất (null: không lỗi).
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  DateTime? _loadedAt;
  DateTime? _lastRunAt;
  Future<FinanceCapabilities?>? _inflight;
  int _generation = 0;

  int _attached = 0;
  Timer? _timer;

  static const Duration _maxAge = Duration(minutes: 2);
  static const Duration _resumeAfter = Duration(seconds: 30);

  /// Lấy quyền (dùng bản lưu nếu còn mới).
  Future<FinanceCapabilities?> ensureCapabilities({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < _maxAge;
    if (!force && fresh && capabilities.value != null) return Future.value(capabilities.value);
    final running = _inflight;
    if (running != null) return running;
    late final Future<FinanceCapabilities?> call;
    call = _load().whenComplete(() {
      if (identical(_inflight, call)) _inflight = null;
    });
    return _inflight = call;
  }

  Future<FinanceCapabilities?> _load() async {
    final generation = _generation;
    _lastRunAt = DateTime.now();
    try {
      final caps = await repository.getCapabilities();
      if (generation != _generation) return null;
      capabilities.value = caps;
      error.value = null;
      _loadedAt = DateTime.now();
      return caps;
    } catch (e) {
      if (generation != _generation) return null;
      // Như web: lỗi thì bỏ quyền cũ và giữ lời nhắn lỗi.
      capabilities.value = null;
      _loadedAt = null;
      error.value = financeErrorMessage(e, 'finance.common.error_capabilities');
      return null;
    }
  }

  /// Một trang Tài chính bắt đầu hiển thị: bật làm mới định kỳ (dùng chung cho mọi trang đang mở).
  void attach() {
    _attached++;
    if (_attached > 1) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_maxAge, (_) => ensureCapabilities(force: true));
  }

  /// Trang Tài chính đóng; không còn trang nào thì tắt làm mới định kỳ.
  void detach() {
    if (_attached == 0) return;
    _attached--;
    if (_attached > 0) return;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastRunAt;
    if (last == null || DateTime.now().difference(last) > _resumeAfter) ensureCapabilities(force: true);
  }

  /// Gọi khi một thao tác bị từ chối (403): tải lại quyền ngay.
  void invalidate() {
    _loadedAt = null;
    ensureCapabilities(force: true);
  }

  /// Tiện cho `catch`: lỗi 403 thì làm mới quyền.
  void onError(Object error) {
    if (error is FinanceException && error.isForbidden) invalidate();
  }

  /// Xoá khi đăng xuất / đổi tổ chức.
  void reset() {
    _generation++;
    _inflight = null;
    capabilities.value = null;
    error.value = null;
    _loadedAt = null;
    _lastRunAt = null;
  }
}
