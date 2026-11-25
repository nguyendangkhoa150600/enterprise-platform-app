import 'package:flutter/material.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/assets/inventory_asset_models.dart';

// ----------------------------------------------------------------------------- Nhãn (web inventory-labels)

String invAssetTypeLabel(String type) {
  const known = {'PLANT', 'SYSTEM', 'EQUIPMENT', 'COMPONENT'};
  return known.contains(type) ? 'inventory.assets.type_${type.toLowerCase()}'.tr() : (type.isEmpty ? '—' : type);
}

const List<String> kInvAssetStatuses = ['OPERATING', 'STOPPED', 'MAINTENANCE', 'DISPOSED'];
const List<String> kInvAssetCriticalities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
const List<String> kInvAssetTypes = ['PLANT', 'SYSTEM', 'EQUIPMENT', 'COMPONENT'];
const List<String> kInvAssetCategories = ['INDUSTRIAL', 'IT_OFFICE', 'TOOL_PPE', 'VEHICLE'];

String invAssetStatusLabel(String status) =>
    kInvAssetStatuses.contains(status) ? 'inventory.assets.status_${status.toLowerCase()}'.tr() : status;

String invAssetCriticalityLabel(String c) =>
    kInvAssetCriticalities.contains(c) ? 'inventory.assets.criticality_${c.toLowerCase()}'.tr() : c;

String invAssetCategoryLabel(String? c) =>
    c != null && kInvAssetCategories.contains(c) ? 'inventory.assets.category_${c.toLowerCase()}'.tr() : '—';

String invCustodyStateLabel(InvCustodyState s) => switch (s) {
      InvCustodyState.inUse => 'inventory.assets.custody_in_use'.tr(),
      InvCustodyState.maintenance => 'inventory.assets.custody_maintenance'.tr(),
      InvCustodyState.inStock => 'inventory.assets.custody_in_stock'.tr(),
      InvCustodyState.stopped => 'inventory.assets.custody_stopped'.tr(),
      InvCustodyState.disposed => 'inventory.assets.custody_disposed'.tr(),
    };

String invMaintenanceStatusLabel(String s) {
  const known = {'planned', 'generated', 'dispatch_pending', 'in_progress', 'blocked', 'completed', 'failed'};
  return known.contains(s) ? 'inventory.assets.mstatus_$s'.tr() : s;
}

String invFormatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ----------------------------------------------------------------------------- Màu

class InvTone {
  final Color fg;
  final Color bg;
  final Color border;
  const InvTone(this.fg, this.bg, this.border);

  static const success = InvTone(Color(0xFF047857), Color(0xFFECFDF5), Color(0xFFA7F3D0));
  static const info = InvTone(Color(0xFF1D4ED8), Color(0xFFEFF6FF), Color(0xFFBFDBFE));
  static const warn = InvTone(Color(0xFFB45309), Color(0xFFFFFBEB), Color(0xFFFDE68A));
  static const danger = InvTone(Color(0xFFB91C1C), Color(0xFFFEF2F2), Color(0xFFFECACA));
  static const muted = InvTone(AppColors.slate500, AppColors.slate100, AppColors.slate300);

  static InvTone of(String type) => switch (type) {
        'success' => success,
        'warn' => warn,
        'danger' => danger,
        _ => info,
      };
}

InvTone invCustodyTone(InvCustodyState s) => switch (s) {
      InvCustodyState.inUse => const InvTone(Color(0xFF15803D), Color(0xFFF0FDF4), Color(0xFFBBF7D0)),
      InvCustodyState.maintenance => const InvTone(Color(0xFFB45309), Color(0xFFFFFBEB), Color(0xFFFDE68A)),
      InvCustodyState.inStock => const InvTone(Color(0xFF1D4ED8), Color(0xFFEFF6FF), Color(0xFFBFDBFE)),
      InvCustodyState.stopped => const InvTone(AppColors.slate600, AppColors.slate100, AppColors.slate300),
      InvCustodyState.disposed => const InvTone(Color(0xFF991B1B), Color(0xFFFEF2F2), Color(0xFFFECACA)),
    };

/// Web `ASSET_STATUS_TONE` (bảng liệt kê).
InvTone invAssetStatusTone(String status) => switch (status) {
      'OPERATING' => const InvTone(Color(0xFF166534), Color(0xFFF0FDF4), Color(0xFFBBF7D0)),
      'STOPPED' => const InvTone(Color(0xFF991B1B), Color(0xFFFEF2F2), Color(0xFFFECACA)),
      'MAINTENANCE' => InvTone.warn,
      _ => InvTone.muted,
    };

Color invCriticalityColor(String c) => switch (c) {
      'CRITICAL' => const Color(0xFFDC2626),
      'HIGH' => const Color(0xFFEA580C),
      'MEDIUM' => const Color(0xFF0284C7),
      _ => AppColors.slate500,
    };

// ----------------------------------------------------------------------------- Widget dùng chung

class InvPill extends StatelessWidget {
  final String text;
  final InvTone tone;
  final double fontSize;
  const InvPill(this.text, {super.key, this.tone = InvTone.info, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.border),
        ),
        child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: tone.fg)),
      );
}

class InvCodeTag extends StatelessWidget {
  final String code;
  const InvCodeTag(this.code, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Text(code,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
      );
}

class InvSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const InvSectionCard({super.key, required this.title, this.subtitle, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class InvEmptyText extends StatelessWidget {
  final String text;
  const InvEmptyText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
        ),
      );
}

class InvErrorBox extends StatelessWidget {
  final String message;
  const InvErrorBox(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
      );
}

class InvNoticeBox extends StatelessWidget {
  final String message;
  final InvTone tone;
  final IconData? icon;
  const InvNoticeBox(this.message, {super.key, this.tone = InvTone.warn, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: tone.fg), const SizedBox(width: 6)],
            Expanded(child: Text(message, style: TextStyle(fontSize: 12.5, color: tone.fg, height: 1.35))),
          ],
        ),
      );
}

class InvFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Widget? trailing;
  const InvFieldLabel(this.text, {super.key, this.required = false, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Flexible(
              child: Text.rich(TextSpan(
                text: text,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700),
                children: [
                  if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626))),
                ],
              )),
            ),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      );
}

InputDecoration invInputDecoration({String? hint, bool error = false, Widget? suffix, Widget? prefix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.slate300)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: error ? const Color(0xFFEF4444) : AppColors.slate300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: error ? const Color(0xFFEF4444) : const Color(0xFF2563EB), width: 1.4),
      ),
    );

class InvOption {
  final String value;
  final String label;
  final String? badge;
  final String? description;
  const InvOption(this.value, this.label, {this.badge, this.description});
}

/// Ô chọn có tìm kiếm (web `SearchableSelect`): bấm mở danh sách dạng bottom sheet.
class InvSelectField extends StatelessWidget {
  final List<InvOption> options;
  final String value;
  final String placeholder;
  final String? searchHint;
  final String? emptyText;
  final bool enabled;
  final bool clearable;
  final ValueChanged<String> onChanged;

  const InvSelectField({
    super.key,
    required this.options,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    this.searchHint,
    this.emptyText,
    this.enabled = true,
    this.clearable = false,
  });

  @override
  Widget build(BuildContext context) {
    InvOption? picked;
    for (final o in options) {
      if (o.value == value) picked = o;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: !enabled
          ? null
          : () async {
              final next = await invPickOption(
                context,
                title: placeholder,
                options: options,
                selected: value,
                searchHint: searchHint,
                emptyText: emptyText,
              );
              if (next != null) onChanged(next);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                picked == null ? placeholder : (picked.badge != null ? '${picked.label} (${picked.badge})' : picked.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: picked == null ? AppColors.slate400 : AppColors.slate900),
              ),
            ),
            if (clearable && picked != null && enabled)
              GestureDetector(
                onTap: () => onChanged(''),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 16, color: AppColors.slate400),
                ),
              ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.slate500),
          ],
        ),
      ),
    );
  }
}

Future<String?> invPickOption(
  BuildContext context, {
  required String title,
  required List<InvOption> options,
  String? selected,
  String? searchHint,
  String? emptyText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InvOptionPicker(
      title: title,
      options: options,
      selected: selected,
      searchHint: searchHint,
      emptyText: emptyText,
    ),
  );
}

class _InvOptionPicker extends StatefulWidget {
  final String title;
  final List<InvOption> options;
  final String? selected;
  final String? searchHint;
  final String? emptyText;
  const _InvOptionPicker({required this.title, required this.options, this.selected, this.searchHint, this.emptyText});
  @override
  State<_InvOptionPicker> createState() => _InvOptionPickerState();
}

class _InvOptionPickerState extends State<_InvOptionPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final visible = widget.options
        .where((o) =>
            q.isEmpty ||
            o.label.toLowerCase().contains(q) ||
            (o.badge ?? '').toLowerCase().contains(q) ||
            (o.description ?? '').toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (widget.options.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  decoration: invInputDecoration(
                    hint: widget.searchHint ?? 'inventory.assets.search'.tr(),
                    prefix: const Icon(Icons.search, size: 18, color: AppColors.slate500),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            Flexible(
              child: visible.isEmpty
                  ? InvEmptyText(widget.emptyText ?? 'inventory.assets.no_option'.tr())
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.slate100),
                      itemBuilder: (_, i) {
                        final o = visible[i];
                        final isSel = o.value == widget.selected;
                        return ListTile(
                          dense: true,
                          selected: isSel,
                          selectedTileColor: const Color(0xFFEFF6FF),
                          title: Text(o.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: o.description != null
                              ? Text(o.description!, style: const TextStyle(fontSize: 12, color: AppColors.slate500))
                              : null,
                          trailing: o.badge != null
                              ? Text(o.badge!,
                                  style: const TextStyle(
                                      fontSize: 12, fontFamily: 'monospace', color: Color(0xFF2563EB), fontWeight: FontWeight.w600))
                              : (isSel ? const Icon(Icons.check, size: 18, color: Color(0xFF2563EB)) : null),
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

/// Khung bottom sheet chung cho form (thay Dialog web): tiêu đề, mô tả, thân cuộn, chân nút.
class InvSheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback onClose;
  final Widget? headerBottom;

  const InvSheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    required this.actions,
    required this.onClose,
    this.headerBottom,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate500, height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.slate500), onPressed: onClose),
                ],
              ),
            ),
            ?headerBottom,
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: body,
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + mq.padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> invShowSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );

ButtonStyle invPrimaryStyle({Color color = const Color(0xFF1D4ED8)}) => ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.slate300,
      disabledForegroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );

ButtonStyle invOutlineStyle({Color color = AppColors.slate900}) => OutlinedButton.styleFrom(
      foregroundColor: color,
      side: const BorderSide(color: AppColors.slate300),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

/// Hộp xác nhận (web `Popconfirm` / `CloseGuard`).
Future<bool> invConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? okText,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.slate700)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('inventory.assets.cancel'.tr(), style: const TextStyle(color: AppColors.slate500)),
        ),
        ElevatedButton(
          style: invPrimaryStyle(color: danger ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText ?? 'inventory.assets.continue'.tr()),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Đóng form đang có dữ liệu: hỏi trước (web `CloseGuard`).
Future<void> invGuardedClose(BuildContext context, {required bool dirty, required bool busy}) async {
  if (busy) return;
  if (dirty) {
    final ok = await invConfirm(
      context,
      title: 'inventory.assets.discard_title'.tr(),
      message: 'inventory.assets.discard_message'.tr(),
      okText: 'inventory.assets.discard_ok'.tr(),
    );
    if (!ok || !context.mounted) return;
  }
  Navigator.pop(context);
}

void invToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF047857),
    behavior: SnackBarBehavior.floating,
  ));
}
