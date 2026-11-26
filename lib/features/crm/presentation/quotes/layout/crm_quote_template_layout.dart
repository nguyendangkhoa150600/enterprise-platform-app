import '../../../data/quotes/crm_quotes_repository.dart';
import '../../../domain/quotes/crm_quote_layout_models.dart';

/// Tải bố cục in theo mẫu (web `use-template-layout.ts`): giữ trong bộ nhớ của phiên, nhiều màn cùng mở một mẫu chỉ gọi
/// API một lần; mẫu chưa có bố cục hoặc chưa chọn mẫu thì dùng bố cục mặc định.
class CrmQuoteTemplateLayouts {
  CrmQuoteTemplateLayouts._();

  static final Map<String, CrmQuoteLayout?> _cache = {};
  static final Map<String, Future<CrmQuoteLayout?>> _pending = {};

  static bool has(String templateId) => _cache.containsKey(templateId);
  static CrmQuoteLayout? cached(String templateId) => _cache[templateId];

  static Future<CrmQuoteLayout?> load(String templateId) {
    final running = _pending[templateId];
    if (running != null) return running;
    final next = CrmQuotesRepository.instance
        .getTemplateLayout(templateId)
        .then((layout) {
          _cache[templateId] = layout;
          return layout;
        })
        .whenComplete(() => _pending.remove(templateId));
    _pending[templateId] = next;
    return next;
  }

  static void forget(String templateId) {
    _cache.remove(templateId);
    _pending.remove(templateId);
  }

  static void clear() {
    _cache.clear();
    _pending.clear();
  }
}
