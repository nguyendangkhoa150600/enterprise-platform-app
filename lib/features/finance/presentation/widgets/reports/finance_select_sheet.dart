import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Một lựa chọn trong [showFinanceSelectSheet] (web `SearchableSelect` option).
class FinanceSelectOption {
  final String value;
  final String label;
  final String? description;
  const FinanceSelectOption({required this.value, required this.label, this.description});
}

/// Kết quả chọn: `null` = đóng không chọn; `value == null` = đã bỏ chọn (clearable).
typedef FinanceSelectResult = ({String? value});

/// Bảng chọn có ô tìm kiếm (thay `SearchableSelect` của web).
Future<FinanceSelectResult?> showFinanceSelectSheet(
  BuildContext context, {
  required String title,
  required List<FinanceSelectOption> options,
  String? selected,
  String? clearLabel,
}) {
  return showModalBottomSheet<FinanceSelectResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _FinanceSelectSheet(title: title, options: options, selected: selected, clearLabel: clearLabel),
  );
}

class _FinanceSelectSheet extends StatefulWidget {
  final String title;
  final List<FinanceSelectOption> options;
  final String? selected;
  final String? clearLabel;
  const _FinanceSelectSheet({required this.title, required this.options, this.selected, this.clearLabel});

  @override
  State<_FinanceSelectSheet> createState() => _FinanceSelectSheetState();
}

class _FinanceSelectSheetState extends State<_FinanceSelectSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
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
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: 'common.search'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (widget.clearLabel != null && widget.selected != null && widget.selected!.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.clear_rounded, size: 20, color: FinanceColors.muted),
                title: Text(widget.clearLabel!, style: const TextStyle(color: FinanceColors.muted)),
                onTap: () => Navigator.pop(context, (value: null)),
              ),
            Expanded(
              child: items.isEmpty
                  ? FinanceStateView(emptyText: 'common.no_data'.tr())
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final o = items[i];
                        final sel = o.value == widget.selected;
                        return ListTile(
                          dense: true,
                          title: Text(o.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? FinanceColors.primary : FinanceColors.text)),
                          subtitle: o.description == null || o.description!.isEmpty
                              ? null
                              : Text(o.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: sel ? const Icon(Icons.check_rounded, color: FinanceColors.primary) : null,
                          onTap: () => Navigator.pop(context, (value: o.value)),
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

/// Ô bấm mở bảng chọn / chọn ngày: nhãn hiện giá trị hoặc chữ mờ khi trống.
class FinancePickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const FinancePickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FinanceColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(empty ? placeholder : value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: empty ? FinanceColors.faint : FinanceColors.text)),
            ),
            if (!empty && onClear != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: FinanceColors.muted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(icon, size: 18, color: FinanceColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mở `showDatePicker` với ngày `YYYY-MM-DD`; trả ngày đã chọn dạng `YYYY-MM-DD` (null khi bỏ).
Future<String?> pickFinanceApiDate(BuildContext context, String? current) async {
  final initial = parseFinanceDate(current) ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return picked == null ? null : financeApiDate(picked);
}
