import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_api_base.dart';
import '../../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import '../finance/finance_format.dart';
import 'request_card.dart';
import 'request_filter.dart';

/// Ngăn chi tiết đơn từ (web: drawer trong `tab-requests.tsx` + `RequestDetailList`). Chỉ đọc, trừ "Huỷ hiệu lực…".
/// [items] được tab cập nhật sau mỗi lần nạp lại, để trạng thái trong ngăn đổi theo (như `setSelected` của web).
Future<void> showRequestDetailSheet(
  BuildContext context, {
  required String requestId,
  required ValueNotifier<List<ProjectRequestItem>?> items,
  required Future<WorkspaceApiResult<void>> Function(ProjectRequestItem item, String reason, bool createAdjustment) onReverse,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ValueListenableBuilder<List<ProjectRequestItem>?>(
        valueListenable: items,
        builder: (context, list, _) {
          final item = list?.where((e) => e.id == requestId).firstOrNull;
          if (item == null) return const SizedBox.shrink();
          return _DetailBody(item: item, scroll: scroll, onReverse: onReverse);
        },
      ),
    ),
  );
}

class _DetailBody extends StatelessWidget {
  final ProjectRequestItem item;
  final ScrollController scroll;
  final Future<WorkspaceApiResult<void>> Function(ProjectRequestItem item, String reason, bool createAdjustment) onReverse;

  const _DetailBody({required this.item, required this.scroll, required this.onReverse});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final reversal = item.reversalRequest;
    final showReversal = reversal != null && item.status == 'APPROVED';
    final canReverse = item.status == 'APPROVED' && (reversal == null || reversal.error != null);

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
              Expanded(child: value),
            ],
          ),
        );
    Widget text(String value) => Text(value, style: const TextStyle(fontSize: 13));

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('${item.code} · ${item.requestTypeLabel}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('workspace.requests.detail_subtitle'.tr(), style: TextStyle(fontSize: 12, color: muted)),
        const Divider(height: 24),
        row('workspace.requests.d_code'.tr(), text(item.code)),
        row('workspace.requests.d_type'.tr(), text(item.requestTypeLabel)),
        if (item.linkedViaKind != null)
          row('workspace.requests.d_linked'.tr(),
              text('workspace.requests.via_trip'.tr(args: {'code': item.linkedViaCode ?? ''}).trim())),
        row('workspace.requests.col_requester'.tr(), text(requesterNameOf(item))),
        row('workspace.requests.col_time'.tr(), text(formatRequestRange(item.fromDate, item.toDate))),
        row('workspace.requests.col_status'.tr(), Align(alignment: Alignment.centerLeft, child: RequestStatusPill(item.status))),
        row('workspace.requests.col_submitted'.tr(), text(formatDateTime(item.submittedAt))),
        if (item.statusChangedAt != null) row('workspace.requests.d_status_changed'.tr(), text(formatDateTime(item.statusChangedAt))),
        row('workspace.requests.d_procedure'.tr(), text(item.procedureInstanceCode ?? 'workspace.requests.d_no_procedure'.tr())),
        if (item.status == 'REVERSED' && item.statusNote != null)
          row('workspace.requests.d_reversal_reason'.tr(), text(item.statusNote!)),
        if (item.details.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('workspace.requests.details_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          for (final d in item.details) row(d.label, text(d.value)),
        ],
        if (showReversal) ...[
          const SizedBox(height: 10),
          _ReversalNotice(reversal: reversal),
        ],
        if (canReverse) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ReverseRequestDialog(item: item, onConfirm: onReverse),
              ),
              child: Text((reversal?.error != null ? 'workspace.requests.resend_reverse' : 'workspace.requests.reverse').tr()),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReversalNotice extends StatelessWidget {
  final ProjectRequestReversal reversal;
  const _ReversalNotice({required this.reversal});

  @override
  Widget build(BuildContext context) {
    final failed = reversal.error != null;
    final fg = failed ? const Color(0xFFB91C1C) : const Color(0xFF7C2D12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: failed ? const Color(0xFFFECACA) : const Color(0xFFFED7AA)),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 13, color: fg),
          children: failed
              ? [
                  TextSpan(text: 'workspace.requests.reversal_rejected_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                    text: ' ${'workspace.requests.reversal_rejected_body'.tr(args: {
                          'error': reversal.error!.replaceFirst(RegExp(r'^Đơn HRM:\s*'), ''),
                        })}',
                  ),
                ]
              : [
                  TextSpan(text: 'workspace.requests.reversal_pending_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                    text: ' ${'workspace.requests.reversal_pending_body'.tr(args: {
                          'name': reversal.requestedByName ?? 'workspace.requests.reversal_someone'.tr(),
                          'time': formatDateTime(reversal.requestedAt),
                        })}',
                  ),
                ],
        ),
      ),
    );
  }
}

/// Xác nhận huỷ hiệu lực đơn (web `ReverseProjectRequestDialog`): lý do ≥ 3 ký tự, tuỳ chọn lập hồ sơ điều chỉnh.
class ReverseRequestDialog extends StatefulWidget {
  final ProjectRequestItem item;
  final Future<WorkspaceApiResult<void>> Function(ProjectRequestItem item, String reason, bool createAdjustment) onConfirm;

  const ReverseRequestDialog({super.key, required this.item, required this.onConfirm});

  @override
  State<ReverseRequestDialog> createState() => _ReverseRequestDialogState();
}

class _ReverseRequestDialogState extends State<ReverseRequestDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _adjust = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'workspace.requests.reverse_err_reason'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.onConfirm(widget.item, reason, _adjust);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.error ?? 'workspace.requests.reverse_err'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final muted = Theme.of(context).hintColor;
    final hint = [
      'workspace.requests.reverse_hint_effect'.tr(),
      if (item.procedureInstanceCode != null)
        'workspace.requests.reverse_hint_procedure'.tr(args: {'code': item.procedureInstanceCode}),
      'workspace.requests.reverse_hint_blocked'.tr(),
    ].join(' ');
    final valid = _reason.text.trim().length >= 3;

    return AlertDialog(
      title: Text(
        'workspace.requests.reverse_title'.tr(args: {'code': item.code, 'type': item.requestTypeLabel}),
        style: const TextStyle(fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${'workspace.requests.d_reversal_reason'.tr()} *',
                hintText: 'workspace.requests.reverse_placeholder'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            Text(hint, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _adjust,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _submitting ? null : (v) => setState(() => _adjust = v ?? false),
              title: Text('workspace.requests.adjust_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('workspace.requests.adjust_hint'.tr(), style: const TextStyle(fontSize: 12)),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: Text('common.cancel'.tr())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
          onPressed: _submitting || !valid ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('workspace.requests.reverse_confirm'.tr()),
        ),
      ],
    );
  }
}
