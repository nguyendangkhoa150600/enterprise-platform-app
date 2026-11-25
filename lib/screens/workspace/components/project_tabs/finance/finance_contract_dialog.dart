import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_api_base.dart';
import 'finance_format.dart';

/// Hộp "Giá trị hợp đồng" (web `ContractDialog`): kiểm số âm / không đọc được ở client, server vẫn kiểm lại.
/// [onSave] trả kết quả API; dialog đóng với `true` khi lưu xong.
class FinanceContractDialog extends StatefulWidget {
  final double? initial;
  final Future<WorkspaceApiResult<void>> Function(double? contractValue) onSave;

  const FinanceContractDialog({super.key, required this.initial, required this.onSave});

  @override
  State<FinanceContractDialog> createState() => _FinanceContractDialogState();
}

class _FinanceContractDialogState extends State<FinanceContractDialog> {
  late final TextEditingController _controller = TextEditingController(text: toVndInput(widget.initial));
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = parseVndInput(_controller.text);
    if (parsed != null && parsed.isNaN) {
      setState(() => _error = 'workspace.finance.err_parse'.tr());
      return;
    }
    if (parsed != null && parsed < 0) {
      setState(() => _error = 'workspace.finance.err_negative'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.onSave(parsed);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.error ?? 'workspace.finance.err_save'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text('workspace.finance.contract_value'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('workspace.finance.dialog_subtitle'.tr(), style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'workspace.finance.contract_value'.tr(),
              helperText: 'workspace.finance.dialog_hint'.tr(),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
