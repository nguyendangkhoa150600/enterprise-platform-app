import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../theme/colors.dart';
import 'goods_ui.dart';

/// Ô nhập của form Hàng hóa: nhãn (dấu * khi bắt buộc), ô nhập, dòng lỗi hoặc gợi ý.
class GoodsFormField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;
  final String? error;
  final String? hint;

  const GoodsFormField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700),
            children: [
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: goodsDanger, fontWeight: FontWeight.bold)),
            ],
          )),
          const SizedBox(height: 6),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error!, style: const TextStyle(fontSize: 12, color: goodsDanger)),
            )
          else if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hint!, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
            ),
        ],
      ),
    );
  }
}

InputDecoration goodsInputDecoration(String? hint, {bool invalid = false}) {
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: border(invalid ? goodsDanger : AppColors.slate300),
    focusedBorder: border(invalid ? goodsDanger : goodsPrimary, 1.5),
    disabledBorder: border(AppColors.slate200),
  );
}

/// Ô chọn mở bottom sheet tìm kiếm ([showGoodsPicker]).
class GoodsSelectField extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final String placeholder;
  final bool clearable;
  final String? emptyText;
  final ValueChanged<String> onChanged;

  const GoodsSelectField({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
    this.clearable = true,
    this.emptyText,
  });

  Future<void> _open(BuildContext context) async {
    final pick = await showGoodsPicker(
      context,
      title: title,
      options: options.map((o) => GoodsOption(o, o)).toList(),
      selected: value,
      clearable: clearable,
      emptyText: emptyText,
    );
    if (pick != null) onChanged(pick.value);
  }

  @override
  Widget build(BuildContext context) {
    final has = value.isNotEmpty;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate300),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              has ? value : placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: has ? AppColors.slate900 : AppColors.slate400),
            ),
          ),
          if (has && clearable)
            GestureDetector(
              onTap: () => onChanged(''),
              child: const Icon(Icons.close, size: 17, color: AppColors.slate400),
            )
          else
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
        ]),
      ),
    );
  }
}

/// Khung bottom sheet của form: tiêu đề, nội dung cuộn, chân nút; chặn đóng khi đã đổi mà chưa lưu.
class GoodsFormSheet extends StatelessWidget {
  final String title;
  final bool dirty;
  final bool busy;
  final List<Widget> children;
  final String? error;
  final String submitText;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const GoodsFormSheet({
    super.key,
    required this.title,
    required this.dirty,
    required this.busy,
    required this.children,
    required this.submitText,
    required this.canSubmit,
    required this.onSubmit,
    this.error,
  });

  Future<void> _close(BuildContext context) async {
    if (busy) return;
    if (dirty && !await goodsConfirmDiscard(context)) return;
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900)),
                    ),
                    IconButton(onPressed: () => _close(context), icon: const Icon(Icons.close, size: 20)),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.slate200),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...children,
                        if (error != null) ...[GoodsErrorBanner(error!), const SizedBox(height: 10)],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.slate200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => _close(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate600,
                          side: const BorderSide(color: AppColors.slate300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('inventory.goods.cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: busy || !canSubmit ? null : onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goodsPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(busy ? 'inventory.goods.saving'.tr() : submitText,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showGoodsFormSheet<T>(BuildContext context, Widget sheet) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => sheet,
    );
