import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../domain/common/crm_page.dart';
import 'crm_dialogs.dart';
import 'crm_paging.dart';
import 'crm_state_views.dart';
import 'crm_ui.dart';

/// Một lựa chọn (web `SearchableSelectOption`): [value], [label], [badge] (mã), [description] (dòng phụ).
class CrmSelectOption {
  final String value;
  final String label;
  final String? badge;
  final String? description;
  const CrmSelectOption({required this.value, required this.label, this.badge, this.description});
}

/// Kết quả chọn: [value] null là "Bỏ chọn" (khi `clearable`).
class CrmSelection {
  final String? value;
  final CrmSelectOption? option;
  const CrmSelection(this.value, [this.option]);
}

/// Bỏ dấu tiếng Việt + chữ thường để lọc ("nguyen" khớp "Nguyễn").
String crmFold(String text) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    var mapped = ch;
    for (final entry in groups.entries) {
      if (entry.value.contains(ch)) {
        mapped = entry.key;
        break;
      }
    }
    buffer.write(mapped);
  }
  return buffer.toString();
}

/// Lọc lựa chọn theo nhãn, mã, mô tả (không dấu).
List<CrmSelectOption> crmFilterOptions(List<CrmSelectOption> options, String query) {
  final q = crmFold(query.trim());
  if (q.isEmpty) return options;
  return options
      .where((o) => crmFold('${o.label} ${o.badge ?? ''} ${o.description ?? ''} ${o.value}').contains(q))
      .toList();
}

/// Mở danh sách chọn một (web `SearchableSelect`) trong bottom sheet: ô tìm (lọc tại chỗ), dấu tích ở lựa chọn hiện
/// tại, "Bỏ chọn" khi [clearable]. [remoteSearch] → tìm trên server (debounce 300 ms) thay cho lọc tại chỗ.
/// Trả null khi đóng không chọn.
Future<CrmSelection?> showCrmSelectSheet(
  BuildContext context, {
  required String title,
  List<CrmSelectOption> options = const [],
  Future<List<CrmSelectOption>> Function(String query)? remoteSearch,
  String? selected,
  String? searchHint,
  String? emptyText,
  bool clearable = false,
  String? clearLabel,
  bool searchable = true,
}) {
  return showCrmSheet<CrmSelection>(
    context,
    builder: (_) => _CrmSelectSheet(
      title: title,
      options: options,
      remoteSearch: remoteSearch,
      selected: selected,
      searchHint: searchHint,
      emptyText: emptyText,
      clearable: clearable,
      clearLabel: clearLabel,
      searchable: searchable,
    ),
  );
}

class _CrmSelectSheet extends StatefulWidget {
  final String title;
  final List<CrmSelectOption> options;
  final Future<List<CrmSelectOption>> Function(String query)? remoteSearch;
  final String? selected;
  final String? searchHint;
  final String? emptyText;
  final bool clearable;
  final String? clearLabel;
  final bool searchable;

  const _CrmSelectSheet({
    required this.title,
    required this.options,
    this.remoteSearch,
    this.selected,
    this.searchHint,
    this.emptyText,
    required this.clearable,
    this.clearLabel,
    required this.searchable,
  });

  @override
  State<_CrmSelectSheet> createState() => _CrmSelectSheetState();
}

class _CrmSelectSheetState extends State<_CrmSelectSheet> {
  final TextEditingController _search = TextEditingController();
  final CrmDebouncer _debouncer = CrmDebouncer();
  List<CrmSelectOption> _remote = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.remoteSearch != null) _runRemote('');
  }

  @override
  void dispose() {
    _search.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _runRemote(String query) async {
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final rows = await widget.remoteSearch!(query.trim());
      if (!mounted || id != _request) return;
      setState(() {
        _remote = rows;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _error = 'crm.common.error_list'.tr();
        _loading = false;
      });
    }
  }

  void _onQuery(String value) {
    if (widget.remoteSearch != null) {
      _debouncer.run(() => _runRemote(value));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.remoteSearch != null ? _remote : crmFilterOptions(widget.options, _search.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: CrmColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CrmColors.text),
                ),
              ),
              IconButton(
                tooltip: 'crm.common.close'.tr(),
                icon: const Icon(Icons.close_rounded, color: CrmColors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: false,
              maxLength: kCrmSearchMaxLength,
              onChanged: _onQuery,
              decoration: crmInputDecoration(
                hint: widget.searchHint ?? 'crm.common.search_placeholder'.tr(),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: CrmColors.muted),
              ).copyWith(counterText: ''),
            ),
          ),
        if (widget.clearable && widget.selected != null && widget.selected!.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.clear_rounded, color: CrmColors.muted),
            title: Text(
              widget.clearLabel ?? 'crm.common.clear_selection'.tr(),
              style: const TextStyle(fontSize: 13.5, color: CrmColors.muted),
            ),
            onTap: () => Navigator.of(context).pop(const CrmSelection(null)),
          ),
        const Divider(height: 1, color: CrmColors.border),
        Flexible(
          child: _loading && rows.isEmpty
              ? const CrmStateView(loading: true)
              : _error != null
              ? CrmStateView(error: _error, onRetry: () => _runRemote(_search.text))
              : rows.isEmpty
              ? CrmStateView(emptyText: widget.emptyText ?? 'crm.common.select_empty'.tr())
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, color: CrmColors.divider),
                  itemBuilder: (context, index) {
                    final option = rows[index];
                    final isSelected = option.value == widget.selected;
                    return ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? CrmColors.primary : CrmColors.text,
                              ),
                            ),
                          ),
                          if (option.badge != null && option.badge!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            CrmCodeBadge(option.badge!),
                          ],
                        ],
                      ),
                      subtitle: option.description == null
                          ? null
                          : Text(option.description!, style: const TextStyle(fontSize: 12, color: CrmColors.muted)),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: CrmColors.primary, size: 20) : null,
                      onTap: () => Navigator.of(context).pop(CrmSelection(option.value, option)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Ô chọn trong biểu mẫu (giao diện như ô nhập): hiện nhãn lựa chọn hoặc [placeholder]; bấm mở [showCrmSelectSheet].
/// [selectedLabel] dùng khi giá trị hiện tại không có trong [options] (vd. chọn từ tìm trên server).
class CrmSelectField extends StatelessWidget {
  final String? value;
  final List<CrmSelectOption> options;
  final Future<List<CrmSelectOption>> Function(String query)? remoteSearch;
  final ValueChanged<CrmSelection> onChanged;
  final String? placeholder;
  final String? sheetTitle;
  final String? searchHint;
  final String? emptyText;
  final String? selectedLabel;
  final bool clearable;
  final bool enabled;

  const CrmSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const [],
    this.remoteSearch,
    this.placeholder,
    this.sheetTitle,
    this.searchHint,
    this.emptyText,
    this.selectedLabel,
    this.clearable = false,
    this.enabled = true,
  });

  CrmSelectOption? get _current {
    if (value == null || value!.isEmpty) return null;
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final hasValue = value != null && value!.isNotEmpty;
    final text = current?.label ?? (hasValue ? (selectedLabel ?? value!) : (placeholder ?? ''));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showCrmSelectSheet(
                context,
                title: sheetTitle ?? placeholder ?? '',
                options: options,
                remoteSearch: remoteSearch,
                selected: value,
                searchHint: searchHint,
                emptyText: emptyText,
                clearable: clearable,
              );
              if (picked != null) onChanged(picked);
            },
      child: InputDecorator(
        isEmpty: false,
        decoration: crmInputDecoration().copyWith(
          enabled: enabled,
          fillColor: enabled ? Colors.white : CrmColors.divider,
          suffixIcon: hasValue && clearable && enabled
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                  onPressed: () => onChanged(const CrmSelection(null)),
                )
              : const Icon(Icons.expand_more_rounded, color: CrmColors.muted),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: hasValue ? CrmColors.text : CrmColors.faint),
              ),
            ),
            if (current?.badge != null && current!.badge!.isNotEmpty) ...[
              const SizedBox(width: 6),
              CrmCodeBadge(current.badge!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip bộ lọc trên thanh công cụ danh sách: chưa chọn thì hiện [placeholder] (vd. "Mọi nhóm"), đã chọn thì nền xanh
/// nhạt + nút xoá. Bấm mở sheet chọn.
class CrmFilterChip extends StatelessWidget {
  final String placeholder;
  final String? value;
  final List<CrmSelectOption> options;
  final ValueChanged<String?> onChanged;
  final String? sheetTitle;
  final String? searchHint;
  final String? emptyText;
  final bool searchable;

  const CrmFilterChip({
    super.key,
    required this.placeholder,
    required this.value,
    required this.options,
    required this.onChanged,
    this.sheetTitle,
    this.searchHint,
    this.emptyText,
    this.searchable = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null && value!.isNotEmpty;
    String label = placeholder;
    if (active) {
      for (final o in options) {
        if (o.value == value) label = o.label;
      }
    }
    return Material(
      color: active ? CrmColors.primarySoft : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: active ? const Color(0xFFBFDBFE) : CrmColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final picked = await showCrmSelectSheet(
            context,
            title: sheetTitle ?? placeholder,
            options: options,
            selected: value,
            searchHint: searchHint,
            emptyText: emptyText,
            clearable: true,
            clearLabel: placeholder,
            searchable: searchable,
          );
          if (picked != null) onChanged(picked.value);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 7, active ? 6 : 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? CrmColors.primary : CrmColors.body,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              if (active)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 16, color: CrmColors.primary),
                  ),
                )
              else
                const Icon(Icons.expand_more_rounded, size: 18, color: CrmColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô tìm kiếm của danh sách (web `<input type="search">` + `useDebounced(…, 300)`): gọi [onChanged] sau 300 ms kể từ
/// phím cuối (hoặc ngay khi bấm tìm / xoá). Tối đa [kCrmSearchMaxLength] ký tự (server trả 400 khi dài hơn).
class CrmSearchField extends StatefulWidget {
  final String? initialValue;
  final String? hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  const CrmSearchField({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.hint,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<CrmSearchField> createState() => _CrmSearchFieldState();
}

class _CrmSearchFieldState extends State<CrmSearchField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialValue ?? '');
  late final CrmDebouncer _debouncer = CrmDebouncer(delay: widget.debounce);
  String _last = '';

  @override
  void initState() {
    super.initState();
    _last = _ctrl.text.trim();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _emit() {
    final value = _ctrl.text.trim();
    if (value == _last) return;
    _last = value;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      maxLength: kCrmSearchMaxLength,
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        setState(() {});
        _debouncer.run(_emit);
      },
      onSubmitted: (_) {
        _debouncer.cancel();
        _emit();
      },
      decoration: crmInputDecoration(
        hint: widget.hint ?? 'crm.common.search_placeholder'.tr(),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: CrmColors.muted),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: CrmColors.faint),
                onPressed: () {
                  _ctrl.clear();
                  setState(() {});
                  _debouncer.cancel();
                  _emit();
                },
              ),
      ).copyWith(counterText: ''),
    );
  }
}
