import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import 'crm_paging.dart';
import 'crm_ui.dart';

/// Chân danh sách phân trang (web `ListPager`): "{total} {noun} · {n} trang", Trước, các số trang (dải ẩn là `…`),
/// Sau, và "Đến trang" khi quá 7 trang. Ẩn khi chỉ có 1 trang và [alwaysShowSummary] = false.
class CrmPagerBar extends StatelessWidget {
  final int page;
  final int total;
  final int pageSize;
  final bool loading;

  /// Danh từ đếm, vd. 'khách hàng' (đã dịch).
  final String noun;
  final ValueChanged<int> onChanged;
  final bool alwaysShowSummary;

  const CrmPagerBar({
    super.key,
    required this.page,
    required this.total,
    required this.pageSize,
    required this.noun,
    required this.onChanged,
    this.loading = false,
    this.alwaysShowSummary = true,
  });

  /// Dựng từ [CrmPagedListController].
  factory CrmPagerBar.of(CrmPagedListController controller, {Key? key, required String noun}) => CrmPagerBar(
    key: key,
    page: controller.page,
    total: controller.total,
    pageSize: controller.pageSize,
    loading: controller.loading,
    noun: noun,
    onChanged: controller.goTo,
  );

  @override
  Widget build(BuildContext context) {
    final pageCount = crmPageCount(total, pageSize);
    if (pageCount <= 1 && !alwaysShowSummary) return const SizedBox.shrink();
    void go(int next) {
      if (next >= 1 && next <= pageCount && next != page) onChanged(next);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            'crm.common.pager_summary'.tr(args: {'total': total, 'noun': noun, 'pages': pageCount}),
            style: const TextStyle(fontSize: 12, color: CrmColors.muted),
          ),
          if (pageCount > 1) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PagerButton(label: 'crm.common.prev'.tr(), onTap: page <= 1 || loading ? null : () => go(page - 1)),
                  for (final item in crmPageItems(page, pageCount))
                    item == null
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('…', style: TextStyle(color: CrmColors.faint)),
                          )
                        : _PagerButton(
                            label: '$item',
                            current: item == page,
                            onTap: loading && item != page ? null : () => go(item),
                          ),
                  _PagerButton(
                    label: 'crm.common.next'.tr(),
                    onTap: page >= pageCount || loading ? null : () => go(page + 1),
                  ),
                  if (pageCount > 7)
                    _PagerButton(
                      label: 'crm.common.jump_to'.tr(),
                      onTap: loading ? null : () => _jump(context, pageCount, go),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _jump(BuildContext context, int pageCount, void Function(int) go) async {
    final ctrl = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('crm.common.jump_to'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: '$page',
            helperText: 'crm.common.jump_hint'.tr(args: {'pages': pageCount}),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('crm.common.cancel'.tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text('crm.common.go'.tr()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) go(value);
  }
}

class _PagerButton extends StatelessWidget {
  final String label;
  final bool current;
  final VoidCallback? onTap;
  const _PagerButton({required this.label, this.current = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Center(
                widthFactor: 1,
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
        ),
      ),
    );
  }
}

/// Nút "Tải thêm" cuối danh sách keyset ([CrmCursorListController]).
class CrmLoadMoreButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const CrmLoadMoreButton({super.key, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: CrmColors.primary),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text('crm.common.load_more'.tr()),
            ),
    ),
  );
}
