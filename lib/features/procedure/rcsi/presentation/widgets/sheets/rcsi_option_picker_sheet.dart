import 'package:flutter/material.dart';

import '../../../../../../core/i18n/app_i18n.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/logic/vietnamese_text.dart';
import '../components/rcsi_common.dart';

/// Một lựa chọn trong [showRcsiOptionPicker].
class RcsiOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const RcsiOption(this.value, this.label, {this.subtitle});
}

/// Kết quả chọn (bọc để phân biệt "chọn giá trị null" với "đóng sheet").
class RcsiPicked<T> {
  final T value;

  const RcsiPicked(this.value);
}

/// Bộ chọn có tìm kiếm (mã + tên, gõ không dấu) dạng bottom sheet — thay `<select>` /
/// `SearchableSelect` của web. Trả null khi người dùng đóng sheet.
Future<RcsiPicked<T>?> showRcsiOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<RcsiOption<T>> options,
  T? selected,
  String? subtitle,
}) =>
    showRcsiSheet<RcsiPicked<T>>(
      context,
      (_) => _RcsiOptionPicker<T>(title: title, subtitle: subtitle, options: options, selected: selected),
    );

class _RcsiOptionPicker<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<RcsiOption<T>> options;
  final T? selected;

  const _RcsiOptionPicker({required this.title, required this.options, this.selected, this.subtitle});

  @override
  State<_RcsiOptionPicker<T>> createState() => _RcsiOptionPickerState<T>();
}

class _RcsiOptionPickerState<T> extends State<_RcsiOptionPicker<T>> {
  final TextEditingController _query = TextEditingController();
  String _needle = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _needle.isEmpty
        ? widget.options
        : widget.options
            .where((option) => foldVietnamese('${option.label} ${option.subtitle ?? ''}').contains(_needle))
            .toList();
    return RcsiSheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.options.length >= 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: RcsiSearchField(
                controller: _query,
                hint: 'procedure.rcsi.common.search_hint'.tr(),
                onChanged: (value) => setState(() => _needle = foldVietnamese(value)),
              ),
            ),
          Flexible(
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'procedure.rcsi.common.no_match'.tr(),
                      style: const TextStyle(color: AppColors.slate500),
                    ),
                  )
                : Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, color: AppColors.slate100),
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final active = option.value == widget.selected;
                        return ListTile(
                          dense: true,
                          title: Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? AppColors.primary : AppColors.slate800,
                            ),
                          ),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(option.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                          trailing: active ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20) : null,
                          onTap: () => Navigator.of(context).pop(RcsiPicked<T>(option.value)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
