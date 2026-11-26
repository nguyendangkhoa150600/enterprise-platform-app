import 'package:flutter/foundation.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../data/common/crm_common_repository.dart';
import '../../domain/common/crm_directory_models.dart';
import '../../domain/crm_capabilities.dart';
import '../../domain/crm_exception.dart';

/// Điểm truy cập dùng chung của module CRM (web `CrmScreen` + `CrmDataProvider`):
/// - Trạng thái `GET /status` (quyền [capabilities], `tablesReady`, `userId`), tải một lần và làm mới sau 2 phút;
///   403 → [denied] (người chưa có quyền `crm.*` nào); lỗi khác → [error] (lời nhắn đã dịch).
/// - Danh bạ [people], nhóm khách [groups], phân loại khách [kinds] — tải một lần khi mở phân hệ ([ensureDirectory]);
///   lỗi thì để rỗng (ô chọn trống, thao tác khác vẫn chạy) như web.
/// [reset] khi đăng xuất / đổi tổ chức (gọi trong `AuthProvider`).
class CrmScope {
  CrmScope._();
  static final CrmScope instance = CrmScope._();

  final CrmCommonRepository repository = CrmCommonRepository.instance;

  final ValueNotifier<CrmStatus?> status = ValueNotifier<CrmStatus?>(null);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> denied = ValueNotifier<bool>(false);

  final ValueNotifier<List<CrmPerson>> people = ValueNotifier<List<CrmPerson>>(const []);
  final ValueNotifier<List<CrmCustomerGroup>> groups = ValueNotifier<List<CrmCustomerGroup>>(const []);
  final ValueNotifier<List<CrmCustomerKind>> kinds = ValueNotifier<List<CrmCustomerKind>>(const []);

  DateTime? _loadedAt;
  Future<CrmStatus?>? _inflight;
  int _generation = 0;
  bool _directoryLoaded = false;

  static const Duration _maxAge = Duration(minutes: 2);

  /// Quyền hiện tại; chưa tải xong → [CrmCapabilities.none].
  CrmCapabilities get capabilities => status.value?.capabilities ?? CrmCapabilities.none;

  /// Người dùng hiện tại theo CRM (ẩn nút tự duyệt).
  String? get currentUserId => status.value?.userId;

  /// Lấy trạng thái (dùng bản lưu nếu còn mới). Lỗi không ném ra: xem [error] / [denied], trả null.
  Future<CrmStatus?> ensureStatus({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < _maxAge;
    if (!force && fresh && status.value != null) return Future.value(status.value);
    final running = _inflight;
    if (running != null) return running;
    late final Future<CrmStatus?> call;
    call = _load().whenComplete(() {
      if (identical(_inflight, call)) _inflight = null;
    });
    return _inflight = call;
  }

  Future<CrmStatus?> _load() async {
    final generation = _generation;
    try {
      final next = await repository.loadStatus();
      if (generation != _generation) return null;
      status.value = next;
      error.value = null;
      denied.value = false;
      _loadedAt = DateTime.now();
      return next;
    } catch (e) {
      if (generation != _generation) return null;
      _loadedAt = null;
      if (e is CrmException && e.isForbidden) {
        status.value = null;
        denied.value = true;
        error.value = null;
      } else {
        // Giữ trạng thái cũ (nếu có) để màn đang mở không mất quyền vì lỗi mạng thoáng qua.
        error.value = crmErrorMessage(e, 'crm.common.status_error');
      }
      return status.value;
    }
  }

  /// Tải danh bạ, nhóm khách, phân loại khách một lần (web `CrmDataProvider`). [force] tải lại cả ba.
  void ensureDirectory({bool force = false}) {
    if (_directoryLoaded && !force) return;
    _directoryLoaded = true;
    reloadPeople();
    reloadGroups();
    reloadKinds();
  }

  void reloadPeople() {
    final generation = _generation;
    repository
        .listPeople()
        .then((rows) {
          if (generation == _generation) people.value = rows;
        })
        .catchError((Object _) {});
  }

  void reloadGroups() {
    final generation = _generation;
    repository
        .listGroups()
        .then((rows) {
          if (generation == _generation) groups.value = rows;
        })
        .catchError((Object _) {});
  }

  void reloadKinds() {
    final generation = _generation;
    repository
        .listKinds()
        .then((rows) {
          if (generation == _generation) kinds.value = rows;
        })
        .catchError((Object _) {});
  }

  /// Tên người theo id (web `personName`): rỗng khi không có id; không có trong danh bạ → "Người dùng khác".
  String personName(String? userId) {
    if (userId == null || userId.isEmpty) return '';
    for (final person in people.value) {
      if (person.userId == userId) return person.displayName;
    }
    return 'crm.common.other_user'.tr();
  }

  /// Tên phân loại khách theo mã; không có thì trả mã.
  String kindName(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final kind in kinds.value) {
      if (kind.code == code) return kind.name;
    }
    return code;
  }

  /// Thao tác bị 403: tải lại quyền ngay.
  void onError(Object error) {
    if (error is CrmException && error.isForbidden) ensureStatus(force: true);
  }

  /// Đăng xuất / đổi tổ chức.
  void reset() {
    _generation++;
    _inflight = null;
    _loadedAt = null;
    _directoryLoaded = false;
    status.value = null;
    error.value = null;
    denied.value = false;
    people.value = const [];
    groups.value = const [];
    kinds.value = const [];
    repository.clearCaches();
  }
}

/// Lời nhắn lỗi cho người dùng (web `errorMessage(cause, fallback)`): ưu tiên `message` server; lỗi phía app
/// (mạng, tải file) có lời nhắn riêng; không có thì [fallbackKey] đã dịch.
String crmErrorMessage(Object? error, [String fallbackKey = 'crm.common.error_generic']) {
  if (error is CrmException) {
    final m = error.message;
    if (m != null && m.isNotEmpty) return m;
    switch (error.code) {
      case CrmException.clientNetwork:
        return 'crm.common.error_network'.tr();
      case CrmException.clientUploadExpired:
        return 'crm.upload.expired'.tr();
      case CrmException.clientUploadRejected:
        return 'crm.upload.rejected'.tr(args: {'code': error.statusCode ?? ''});
      case CrmException.clientUploadNetwork:
        return 'crm.upload.network'.tr();
      case CrmException.clientUploadCancelled:
        return 'crm.upload.cancelled'.tr();
    }
    if (error.isUnauthenticated) return 'crm.common.session_expired'.tr();
    if (error.isForbidden) return 'crm.common.error_forbidden'.tr();
  }
  return fallbackKey.tr();
}
