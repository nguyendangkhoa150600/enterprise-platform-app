import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../theme/colors.dart';
import '../../../../utils/user_resolver.dart';
import '../../../workspace/presentation/widgets/searchable_dropdown_field.dart';
import '../../domain/documents/stock_document_logic.dart';

/// Thành phần giao diện dùng chung của tab "Xuất/nhập kho" (web `stock-document-parts.tsx`).

const Color kDocBlue = Color(0xFF2563EB);
const Color kDocBorder = AppColors.slate200;

/// Số lượng kiểu web `formatQuantityVn`: phân tách nghìn, tối đa 3 chữ số lẻ.
String formatQty(num? value) {
  if (value == null) return '0';
  final locale = AppI18n.instance.locale.languageCode == 'en' ? 'en_US' : 'vi_VN';
  return NumberFormat('#,##0.###', locale).format(value);
}

String formatDateTimeText(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso;
  return '${Formatters.formatDate(dt)} ${Formatters.formatTime(dt)}';
}

/// Tên người dùng từ id (danh bạ); không tra được thì rút id còn 8 ký tự như web.
String userLabelOf(String? id) {
  final value = (id ?? '').trim();
  if (value.isEmpty) return '—';
  final short = UserResolver.isUuid(value) ? value.substring(0, 8) : value;
  return UserResolver.resolveName(value, fallback: short);
}

class UserNameText extends StatelessWidget {
  final String? id;
  final String prefix;
  final TextStyle? style;
  const UserNameText(this.id, {super.key, this.prefix = '', this.style});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: UserResolver.changeNotifier,
        builder: (_, _, _) => Text('$prefix${userLabelOf(id)}',
            style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

({Color bg, Color fg, Color border}) docStatusColors(String status) => switch (status) {
      'DRAFT' => (bg: const Color(0xFFF5F3FF), fg: const Color(0xFF6D28D9), border: const Color(0xFFDDD6FE)),
      'PENDING' => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309), border: const Color(0xFFFDE68A)),
      'APPROVED' => (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1D4ED8), border: const Color(0xFFBFDBFE)),
      'REJECTED' => (bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), border: const Color(0xFFFECACA)),
      'POSTED' => (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF15803D), border: const Color(0xFFBBF7D0)),
      _ => (bg: AppColors.slate50, fg: AppColors.slate500, border: AppColors.slate200),
    };

class DocStatusBadge extends StatelessWidget {
  final String status;
  const DocStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = docStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(docStatusLabel(status), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: c.fg)),
      ]),
    );
  }
}

/// Ô thông tin nhãn / giá trị / dòng phụ (web lưới `span` + `strong` + `small`).
class DocInfoCell extends StatelessWidget {
  final String label;
  final String value;
  final String? small;
  final Widget? smallWidget;
  const DocInfoCell(this.label, this.value, {super.key, this.small, this.smallWidget});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          if (small != null && small!.isNotEmpty)
            Text(small!, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ?smallWidget,
        ],
      );
}

/// Lưới 2 cột cho các ô thông tin trên màn hẹp.
class DocInfoGrid extends StatelessWidget {
  final List<Widget> children;
  const DocInfoGrid(this.children, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      });
}

class DocBanner extends StatelessWidget {
  final String text;
  final bool error;
  final Widget? trailing;
  const DocBanner(this.text, {super.key, this.error = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final bg = error ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final border = error ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);
    final fg = error ? const Color(0xFF991B1B) : const Color(0xFF92400E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: fg, height: 1.35))),
        ?trailing,
      ]),
    );
  }
}

class DocMessages extends StatelessWidget {
  final List<String> messages;
  const DocMessages(this.messages, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in messages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(m, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
              ),
          ],
        ),
      );
}

void showDocSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
  ));
}

Future<bool> confirmDocAction(
  BuildContext context, {
  required String title,
  required String description,
  required String okLabel,
  String? cancelLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      content: Text(description, style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel ?? 'inventory.documents.common.cancel'.tr()),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? const Color(0xFFDC2626) : kDocBlue,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Hộp nhập lý do từ chối; lý do bắt buộc (server cũng kiểm).
Future<String?> askRejectReason(BuildContext context, String code) {
  return showDialog<String>(context: context, builder: (_) => _RejectReasonDialog(code: code));
}

class _RejectReasonDialog extends StatefulWidget {
  final String code;
  const _RejectReasonDialog({required this.code});

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _ctrl.text.trim();
    return AlertDialog(
      title: Text('inventory.documents.reject.title'.tr(args: {'code': widget.code}),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('inventory.documents.reject.label'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('inventory.documents.common.cancel'.tr())),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0),
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, reason),
          child: Text('inventory.documents.action.reject'.tr()),
        ),
      ],
    );
  }
}

/// Một lựa chọn của bộ lọc / ô chọn.
class DocOption {
  final String value;
  final String label;
  final String? description;
  const DocOption(this.value, this.label, [this.description]);
}

/// Ô chọn có tìm kiếm (web `SearchableSelect`).
class DocSelect extends StatelessWidget {
  final String? label;
  final List<DocOption> options;
  final String? value;
  final String? hint;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const DocSelect({
    super.key,
    this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    Widget field = SearchableDropdownField<DocOption>(
      value: selected,
      items: options,
      hintText: hint ?? (options.isNotEmpty ? options.first.label : ''),
      icon: null,
      itemLabel: (o) => o.label,
      itemSubtitle: (o) => o.description,
      showClear: false,
      onChanged: (o) => onChanged(o.value),
      maxHeight: 240,
    );
    if (!enabled) field = IgnorePointer(child: Opacity(opacity: 0.6, child: field));
    if (label == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      DocFieldLabel(label!),
      const SizedBox(height: 4),
      field,
    ]);
  }
}

class DocFieldLabel extends StatelessWidget {
  final String text;
  const DocFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slate600));
}

/// Ô chọn ngày `YYYY-MM-DD` (web `<Input type="date">`).
class DocDateField extends StatelessWidget {
  final String? label;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;
  final bool clearable;
  const DocDateField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'dd/mm/yyyy',
    this.clearable = true,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(value ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(isoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final has = (value ?? '').isNotEmpty;
    final box = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.slate300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              has ? Formatters.formatDate(value) : placeholder,
              style: TextStyle(fontSize: 12.5, color: has ? AppColors.slate900 : AppColors.slate400),
            ),
          ),
          if (has && clearable)
            InkWell(
              onTap: () => onChanged(null),
              child: const Icon(Icons.close, size: 14, color: AppColors.slate400),
            )
          else
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.slate500),
        ]),
      ),
    );
    if (label == null) return box;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      DocFieldLabel(label!),
      const SizedBox(height: 4),
      box,
    ]);
  }
}

InputDecoration docInputDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.slate300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.slate300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kDocBlue, width: 1.5)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.slate200)),
    );

/// Khung bottom sheet chuẩn: tiêu đề, nút đóng, thân cuộn, chân cố định.
class DocSheetFrame extends StatelessWidget {
  final Widget title;
  final Widget body;
  final Widget? footer;
  final bool closable;
  final double heightFactor;
  const DocSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.closable = true,
    this.heightFactor = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * heightFactor,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(children: [
              Expanded(child: title),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.slate500),
                onPressed: closable ? () => Navigator.of(context).maybePop() : null,
              ),
            ]),
          ),
          const Divider(height: 1, color: kDocBorder),
          Expanded(child: body),
          if (footer != null) ...[
            const Divider(height: 1, color: kDocBorder),
            SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: footer),
            ),
          ],
        ]),
      ),
    );
  }
}

ButtonStyle docButtonStyle({bool primary = false, bool danger = false}) {
  if (primary) {
    return ElevatedButton.styleFrom(
      backgroundColor: kDocBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
  if (danger) {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFDC2626),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.slate800,
    elevation: 0,
    side: const BorderSide(color: AppColors.slate300),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

/// Nút viền đứt nét kiểu web cho "Chọn lô (FEFO)" / "x/y serial".
class DocPickButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool warn;
  const DocPickButton(this.label, {super.key, this.onTap, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final fg = warn ? const Color(0xFF92400E) : const Color(0xFF1D4ED8);
    final bg = warn ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF);
    final border = warn ? const Color(0xFFFBBF24) : const Color(0xFF93C5FD);
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, color: fg)),
        ),
      ),
    );
  }
}
