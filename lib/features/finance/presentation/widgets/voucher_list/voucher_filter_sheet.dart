import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../utils/finance_format.dart';
import '../common/finance_ui.dart';

/// Một lựa chọn trong ô lọc (web `SearchableSelect` option).
typedef VoucherFilterOption = ({String id, String label});

/// Một ô lọc phụ: nhãn, chữ khi chưa chọn ("Mọi tài khoản"...), danh sách lựa chọn.
class VoucherFilterField {
  final String key;
  final String label;
  final String placeholder;
  final List<VoucherFilterOption> options;
  const VoucherFilterField({required this.key, required this.label, required this.placeholder, required this.options});
}

/// Bộ lọc phụ của danh sách phiếu (tài khoản, lý do, dự án). Trả map key → id ('' = bỏ lọc), null khi đóng.
Future<Map<String, String>?> showVoucherFilterSheet(
  BuildContext context, {
  required List<VoucherFilterField> fields,
  required Map<String, String> values,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _VoucherFilterSheet(fields: fields, values: values),
  );
}

class _VoucherFilterSheet extends StatefulWidget {
  final List<VoucherFilterField> fields;
  final Map<String, String> values;
  const _VoucherFilterSheet({required this.fields, required this.values});

  @override
  State<_VoucherFilterSheet> createState() => _VoucherFilterSheetState();
}

class _VoucherFilterSheetState extends State<_VoucherFilterSheet> {
  late final Map<String, String> _values = Map.of(widget.values);

  Future<void> _pick(VoucherFilterField field) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OptionPicker(field: field, selected: _values[field.key] ?? ''),
    );
    if (!mounted || picked == null) return;
    setState(() => _values[field.key] = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('common.filter'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: FinanceColors.text)),
                ),
                TextButton(
                  onPressed: () => setState(() => _values.updateAll((_, _) => '')),
                  child: Text('common.reset'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final field in widget.fields) ...[
              Text(field.label,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              _selectBox(field),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FinanceColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, _values),
                child: Text('common.apply'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectBox(VoucherFilterField field) {
    final id = _values[field.key] ?? '';
    final label = field.options.where((o) => o.id == id).map((o) => o.label).firstOrNull;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: FinanceColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pick(field),
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(label ?? field.placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: label == null ? FinanceColors.faint : FinanceColors.text)),
              ),
              if (label != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: FinanceColors.muted),
                  onPressed: () => setState(() => _values[field.key] = ''),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.expand_more_rounded, color: FinanceColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách lựa chọn có ô tìm (bỏ dấu).
class _OptionPicker extends StatefulWidget {
  final VoucherFilterField field;
  final String selected;
  const _OptionPicker({required this.field, required this.selected});

  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = financeFold(_search.text);
    final options = q.isEmpty
        ? widget.field.options
        : widget.field.options.where((o) => financeFold(o.label).contains(q)).toList();
    final all = <VoucherFilterOption>[(id: '', label: widget.field.placeholder), ...options];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'common.search'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: all.length,
                  itemBuilder: (_, i) {
                    final o = all[i];
                    final sel = o.id == widget.selected;
                    return ListTile(
                      dense: true,
                      title: Text(o.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                            color: o.id.isEmpty ? FinanceColors.muted : FinanceColors.text,
                          )),
                      trailing: sel ? const Icon(Icons.check_rounded, color: FinanceColors.primary, size: 20) : null,
                      onTap: () => Navigator.pop(context, o.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
