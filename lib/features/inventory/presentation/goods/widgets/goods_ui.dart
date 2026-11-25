import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../theme/colors.dart';
import '../goods_format.dart';

const Color goodsPrimary = Color(0xFF2563EB);
const Color goodsDanger = Color(0xFFDC2626);

/// Khung danh sách có thanh tìm kiếm/bộ lọc nổi: lướt xuống thì ẩn, kéo nhẹ xuống thì hiện lại.
class GoodsFloatingHeaderList extends StatelessWidget {
  final Widget header;
  final List<Widget> slivers;
  final Future<void> Function() onRefresh;

  const GoodsFloatingHeaderList({super.key, required this.header, required this.slivers, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFloatingHeader(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(bottom: BorderSide(color: AppColors.slate200)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: header,
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

class GoodsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const GoodsSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: AppColors.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, color: AppColors.slate900),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Icon(Icons.clear, size: 18, color: AppColors.slate400),
            ),
        ],
      ),
    );
  }
}

/// Nút lọc dạng viên: hiện giá trị đang chọn hoặc nhãn ô lọc; có nút xoá khi [onClear] khác null.
class GoodsFilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const GoodsFilterChip({super.key, required this.label, required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final active = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFFBFDBFE) : AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                active ? value! : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? goodsPrimary : AppColors.slate600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (active && onClear != null)
              GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 15, color: goodsPrimary))
            else
              Icon(Icons.keyboard_arrow_down, size: 16, color: active ? goodsPrimary : AppColors.slate500),
          ],
        ),
      ),
    );
  }
}

class GoodsOption {
  final String value;
  final String label;
  const GoodsOption(this.value, this.label);
}

/// Kết quả chọn; `null` khi đóng sheet mà không chọn. [value] rỗng nghĩa là bỏ chọn.
class GoodsPick {
  final String value;
  const GoodsPick(this.value);
}

/// Bottom sheet chọn một mục, có ô tìm (theo nhãn, không phân biệt dấu) và mục bỏ chọn.
Future<GoodsPick?> showGoodsPicker(
  BuildContext context, {
  required String title,
  required List<GoodsOption> options,
  String? selected,
  bool clearable = true,
  String? emptyText,
}) {
  return showModalBottomSheet<GoodsPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _GoodsPickerSheet(
      title: title,
      options: options,
      selected: selected,
      clearable: clearable,
      emptyText: emptyText,
    ),
  );
}

class _GoodsPickerSheet extends StatefulWidget {
  final String title;
  final List<GoodsOption> options;
  final String? selected;
  final bool clearable;
  final String? emptyText;

  const _GoodsPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.clearable,
    required this.emptyText,
  });

  @override
  State<_GoodsPickerSheet> createState() => _GoodsPickerSheetState();
}

class _GoodsPickerSheetState extends State<_GoodsPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = GoodsFormat.fold(_term.trim());
    final shown = widget.options.where((o) => term.isEmpty || GoodsFormat.fold(o.label).contains(term)).toList();
    final hasSelection = widget.selected != null && widget.selected!.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate900)),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GoodsSearchField(
                  controller: _search,
                  hint: 'inventory.goods.picker_search'.tr(),
                  onChanged: (v) => setState(() => _term = v),
                ),
              ),
              if (widget.clearable && hasSelection)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.clear_all, size: 18, color: AppColors.slate500),
                  title: Text('inventory.goods.picker_clear'.tr(),
                      style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
                  onTap: () => Navigator.of(context).pop(const GoodsPick('')),
                ),
              Flexible(
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(widget.emptyText ?? 'inventory.goods.picker_empty'.tr(),
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                      )
                    : Scrollbar(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final o = shown[i];
                            final isSel = o.value == widget.selected;
                            return ListTile(
                              dense: true,
                              title: Text(o.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? goodsPrimary : AppColors.slate800,
                                  )),
                              trailing: isSel ? const Icon(Icons.check, size: 18, color: goodsPrimary) : null,
                              onTap: () => Navigator.of(context).pop(GoodsPick(o.value)),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn trạng thái mặt hàng: đang dùng (xanh) hay ngừng dùng (đỏ).
class GoodsStatusBadge extends StatelessWidget {
  final bool active;
  const GoodsStatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFF86EFAC) : const Color(0xFFFDA4AF)),
      ),
      child: Text(
        active ? 'inventory.goods.status_active'.tr() : 'inventory.goods.status_inactive'.tr(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF15803D) : const Color(0xFFBE123C),
        ),
      ),
    );
  }
}

class GoodsSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const GoodsSectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.slate700)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.slate100)),
          child,
        ],
      ),
    );
  }
}

/// Trường "nhãn nhỏ phía trên, giá trị bên dưới"; [hint] hiện khi chạm biểu tượng (i).
class GoodsField extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final String? hint;

  const GoodsField({super.key, required this.label, this.value, this.child, this.hint});

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.slate500)),
            ),
            if (hint != null) ...[
              const SizedBox(width: 3),
              Tooltip(
                message: hint!,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: const Icon(Icons.info_outline, size: 13, color: AppColors.slate400),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        child ?? Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.slate900)),
      ],
    );
  }
}

/// Lưới 2 cột các [GoodsField].
class GoodsFieldGrid extends StatelessWidget {
  final List<Widget> children;
  const GoodsFieldGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: children.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}

class GoodsMessage extends StatelessWidget {
  final String text;
  final bool isError;
  final VoidCallback? onRetry;
  const GoodsMessage({super.key, required this.text, this.isError = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: isError ? goodsDanger : AppColors.slate500)),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('inventory.goods.retry'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

class GoodsErrorBanner extends StatelessWidget {
  final String text;
  const GoodsErrorBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
    );
  }
}

/// Thanh phân trang: "a–b / n", chọn số dòng mỗi trang (15/30/45), trang trước/sau.
class GoodsPager extends StatelessWidget {
  final GoodsPage<dynamic> view;
  final int pageSize;
  final ValueChanged<int> onPageChange;
  final ValueChanged<int> onPageSizeChange;

  const GoodsPager({
    super.key,
    required this.view,
    required this.pageSize,
    required this.onPageChange,
    required this.onPageSizeChange,
  });

  @override
  Widget build(BuildContext context) {
    if (view.total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'inventory.goods.pager_range'.tr(args: {'from': view.from, 'to': view.to, 'total': view.total}),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
          PopupMenuButton<int>(
            initialValue: pageSize,
            onSelected: onPageSizeChange,
            itemBuilder: (_) => GoodsFormat.pageSizes
                .map((s) => PopupMenuItem(value: s, child: Text('inventory.goods.pager_size'.tr(args: {'n': s}))))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('inventory.goods.pager_size'.tr(args: {'n': pageSize}),
                    style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
                const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.slate500),
              ]),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: view.page > 1 ? () => onPageChange(view.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${view.page}/${view.pageCount}', style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: view.page < view.pageCount ? () => onPageChange(view.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Future<bool> goodsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String okText,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.slate600)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('inventory.goods.cancel'.tr())),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: danger ? goodsDanger : goodsPrimary),
          child: Text(okText),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Hỏi trước khi bỏ dữ liệu đang nhập (web `CloseGuard`).
Future<bool> goodsConfirmDiscard(BuildContext context) => goodsConfirm(
      context,
      title: 'inventory.goods.discard_title'.tr(),
      message: 'inventory.goods.discard_message'.tr(),
      okText: 'inventory.goods.discard_ok'.tr(),
    );

void goodsSnack(BuildContext context, String text, {String? description, bool error = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(description == null || description.isEmpty ? text : '$text\n$description'),
    backgroundColor: error ? goodsDanger : const Color(0xFF15803D),
  ));
}
