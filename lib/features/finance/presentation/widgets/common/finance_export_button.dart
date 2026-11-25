import 'package:flutter/material.dart';
import '../../../../../utils/app_toast.dart';
import '../../utils/finance_format.dart';
import '../../utils/finance_scope.dart';
import 'finance_ui.dart';

/// Nút "Xuất Excel" / "Export" của web (biểu tượng tải xuống). Chạy [onExport]; lỗi thì báo [errorKey].
/// [compact] = nút biểu tượng cho AppBar.
class FinanceExportButton extends StatefulWidget {
  final String label;
  final Future<void> Function()? onExport;
  final String errorKey;
  final bool compact;

  const FinanceExportButton({
    super.key,
    required this.label,
    required this.onExport,
    this.errorKey = 'finance.export.failed_generic',
    this.compact = false,
  });

  @override
  State<FinanceExportButton> createState() => _FinanceExportButtonState();
}

class _FinanceExportButtonState extends State<FinanceExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    final run = widget.onExport;
    if (run == null || _busy) return;
    setState(() => _busy = true);
    try {
      await run();
    } catch (e) {
      FinanceScope.instance.onError(e);
      if (mounted) AppToast.error(context, financeErrorMessage(e, widget.errorKey));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onExport != null && !_busy;
    final icon = _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download_rounded, size: 18);
    if (widget.compact) {
      return IconButton(tooltip: widget.label, onPressed: enabled ? _run : null, icon: icon);
    }
    return OutlinedButton.icon(
      onPressed: enabled ? _run : null,
      icon: icon,
      label: Text(widget.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: FinanceColors.text,
        side: const BorderSide(color: FinanceColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
