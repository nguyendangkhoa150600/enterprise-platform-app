import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/colors.dart';
import '../../domain/stocktake/stocktake_models.dart';
import '../utils/inventory_number.dart';

/// Tiện ích hiển thị dùng chung cho khu vực kiểm kê.
class StocktakeUi {
  StocktakeUi._();

  static const blue50 = Color(0xFFEFF6FF);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const red600 = Color(0xFFDC2626);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber300 = Color(0xFFFCD34D);
  static const amber700 = Color(0xFFB45309);
  static const green700 = Color(0xFF15803D);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo800 = Color(0xFF3730A3);

  static final NumberFormat _qty = NumberFormat('#,##0.###', 'vi_VN');
  static final NumberFormat _money = NumberFormat('#,##0', 'vi_VN');

  /// Web `formatNumber` (formatQuantityVn).
  static String qty(num? v) => v == null ? '—' : _qty.format(v);

  /// Chênh lệch có dấu `+` khi dương.
  static String signedQty(num v) => v > 0 ? '+${qty(v)}' : qty(v);

  /// Web `formatCurrencyVn(value, { showUnit: true })`.
  static String currency(num? v) => '${_money.format(v ?? 0)} đ';

  static String dateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  static String date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  /// Đọc số người dùng gõ (chấp nhận `,` là dấu thập phân); rỗng → null.
  static double? parseQty(String text) {
    return parseVnNumber(text);
  }

  /// Số gõ vào ô nhập (không phân tách hàng nghìn).
  static String editable(num? v) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static String statusLabel(String status) => switch (status) {
        StocktakeStatuses.draft => 'inventory.stocktake.status_draft'.tr(),
        StocktakeStatuses.counting => 'inventory.stocktake.status_counting'.tr(),
        StocktakeStatuses.pendingApproval => 'inventory.stocktake.status_pending_approval'.tr(),
        StocktakeStatuses.approved => 'inventory.stocktake.status_approved'.tr(),
        StocktakeStatuses.posted => 'inventory.stocktake.status_posted'.tr(),
        StocktakeStatuses.cancelled => 'inventory.stocktake.status_cancelled'.tr(),
        _ => status,
      };

  /// (nền, viền, chữ) như STATUS_BADGE của web.
  static (Color, Color, Color) statusColors(String status) => switch (status) {
        StocktakeStatuses.counting => (blue50, blue200, blue700),
        StocktakeStatuses.pendingApproval => (const Color(0xFFFEFCE8), const Color(0xFFFEF08A), const Color(0xFF854D0E)),
        StocktakeStatuses.approved => (AppColors.emerald50, AppColors.emerald200, AppColors.emerald700),
        StocktakeStatuses.posted => (const Color(0xFFF0FDF4), const Color(0xFF86EFAC), green700),
        StocktakeStatuses.cancelled => (red50, red200, const Color(0xFFB91C1C)),
        _ => (AppColors.slate100, AppColors.slate300, AppColors.slate600),
      };

  static Widget statusBadge(String status, {double fontSize = 11.5}) {
    final (bg, border, fg) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  static Widget tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  static Color diffColor(num diff) => diff == 0 ? green700 : (diff > 0 ? blue600 : red600);

  static void notice(BuildContext context, String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? red600 : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static InputDecoration input({String? hint, String? label, bool error = false, Widget? prefix}) => InputDecoration(
        hintText: hint,
        labelText: label,
        isDense: true,
        prefixIcon: prefix,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error ? const Color(0xFFF87171) : AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: blue600, width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  /// Khung bottom sheet chuẩn (tay kéo + tiêu đề + nút đóng).
  static Widget sheetFrame({
    required BuildContext context,
    required Widget title,
    required Widget child,
    Widget? footer,
    double heightFactor = 0.92,
  }) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * heightFactor),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: title)),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: AppColors.slate500),
                    tooltip: 'inventory.stocktake.close'.tr(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.slate200),
            Flexible(child: child),
            if (footer != null) ...[
              const Divider(height: 1, color: AppColors.slate200),
              SafeArea(top: false, child: footer),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một lựa chọn trong ô chọn có tìm kiếm (web `SearchableSelect`).
class StocktakePickOption {
  final String value;
  final String label;
  final String? description;
  const StocktakePickOption(this.value, this.label, {this.description});
}

/// Bottom sheet chọn một giá trị có ô tìm kiếm; trả `value` đã chọn hoặc null.
Future<String?> showStocktakePicker(
  BuildContext context, {
  required String title,
  required List<StocktakePickOption> options,
  String? selected,
  String? emptyText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PickerSheet(title: title, options: options, selected: selected, emptyText: emptyText),
  );
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<StocktakePickOption> options;
  final String? selected;
  final String? emptyText;
  const _PickerSheet({required this.title, required this.options, this.selected, this.emptyText});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) =>
                o.label.toLowerCase().contains(q) || (o.description?.toLowerCase().contains(q) ?? false))
            .toList();
    return StocktakeUi.sheetFrame(
      context: context,
      heightFactor: 0.8,
      title: Text(widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: StocktakeUi.input(
                hint: 'inventory.stocktake.search_hint'.tr(),
                prefix: const Icon(Icons.search, size: 20, color: AppColors.slate400),
              ),
            ),
          ),
          Flexible(
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(widget.emptyText ?? 'inventory.stocktake.no_options'.tr(),
                        style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (_, i) {
                      final o = list[i];
                      final sel = o.value == widget.selected;
                      return ListTile(
                        dense: true,
                        title: Text(o.label,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? StocktakeUi.blue700 : AppColors.slate800)),
                        subtitle: o.description == null || o.description!.isEmpty
                            ? null
                            : Text(o.description!, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                        trailing: sel ? const Icon(Icons.check, color: StocktakeUi.blue600, size: 18) : null,
                        onTap: () => Navigator.pop(context, o.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Ô dạng nút mở picker.
class StocktakeSelectField extends StatelessWidget {
  final String text;
  final bool placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  const StocktakeSelectField({super.key, required this.text, this.placeholder = false, this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: placeholder ? AppColors.slate400 : AppColors.slate800),
              ),
            ),
            if (onClear != null && !placeholder)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 16, color: AppColors.slate400),
                ),
              )
            else
              const Icon(Icons.expand_more, size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
