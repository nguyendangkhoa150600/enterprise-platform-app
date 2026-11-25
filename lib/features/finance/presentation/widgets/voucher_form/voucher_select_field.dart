import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';
import 'voucher_form_fields.dart';

/// Một lựa chọn của ô chọn có tìm kiếm (web `SearchableSelect` option).
class VoucherSelectOption {
  final String value;
  final String label;
  final String? description;
  const VoucherSelectOption({required this.value, required this.label, this.description});
}

/// Ô chọn: chạm mở bottom sheet có ô tìm (không dấu). [clearable]: nút xoá lựa chọn.
class VoucherSelectField extends StatelessWidget {
  final List<VoucherSelectOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String? searchPlaceholder;
  final String? emptyText;
  final String? sheetTitle;
  final bool clearable;
  final bool enabled;

  /// Nhãn khi [value] không có trong [options] (vd. đã ngừng hoạt động).
  final String? fallbackLabel;

  const VoucherSelectField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.placeholder,
    this.searchPlaceholder,
    this.emptyText,
    this.sheetTitle,
    this.clearable = true,
    this.enabled = true,
    this.fallbackLabel,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showVoucherSelectSheet(
      context,
      title: sheetTitle ?? placeholder,
      options: options,
      selected: value,
      searchPlaceholder: searchPlaceholder,
      emptyText: emptyText,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    VoucherSelectOption? current;
    for (final o in options) {
      if (o.value == value) current = o;
    }
    final text = value.isEmpty ? null : (current?.label ?? fallbackLabel ?? value);
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: text == null,
        decoration: voucherInputDecoration(
          hint: placeholder,
          disabled: !enabled,
          suffix: clearable && text != null && enabled
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: FinanceColors.muted),
                  onPressed: () => onChanged(''),
                )
              : const Icon(Icons.expand_more_rounded, size: 20, color: FinanceColors.muted),
        ),
        child: text == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: enabled ? FinanceColors.text : FinanceColors.muted)),
                  if (current?.description != null && current!.description!.isNotEmpty)
                    Text(current.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: FinanceColors.muted)),
                ],
              ),
      ),
    );
  }
}

/// Bottom sheet chọn một mục; trả giá trị đã chọn, null khi đóng.
Future<String?> showVoucherSelectSheet(
  BuildContext context, {
  required String title,
  required List<VoucherSelectOption> options,
  String selected = '',
  String? searchPlaceholder,
  String? emptyText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _SelectSheet(
      title: title,
      options: options,
      selected: selected,
      searchPlaceholder: searchPlaceholder,
      emptyText: emptyText,
    ),
  );
}

class _SelectSheet extends StatefulWidget {
  final String title;
  final List<VoucherSelectOption> options;
  final String selected;
  final String? searchPlaceholder;
  final String? emptyText;
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.searchPlaceholder,
    this.emptyText,
  });

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = financeFold(_query);
    final items = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) => financeFold('${o.label} ${o.description ?? ''}').contains(q))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: widget.options.length > 8,
                decoration: voucherInputDecoration(hint: widget.searchPlaceholder ?? 'common.search'.tr())
                    .copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 20)),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(widget.emptyText ?? 'finance.voucher_form.no_options'.tr(),
                          textAlign: TextAlign.center, style: const TextStyle(color: FinanceColors.muted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, color: FinanceColors.border),
                      itemBuilder: (_, i) {
                        final o = items[i];
                        final sel = o.value == widget.selected;
                        return ListTile(
                          dense: true,
                          title: Text(o.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  color: FinanceColors.text)),
                          subtitle: o.description == null || o.description!.isEmpty
                              ? null
                              : Text(o.description!, style: const TextStyle(fontSize: 12, color: FinanceColors.muted)),
                          trailing: sel ? const Icon(Icons.check_rounded, color: FinanceColors.primary, size: 20) : null,
                          onTap: () => Navigator.pop(context, o.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
