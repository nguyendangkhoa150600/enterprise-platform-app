import 'package:flutter/material.dart';
import '../../../../../core/i18n/app_i18n.dart';
import '../../../../../features/workspace/data/datasources/workspace_requests_api.dart';
import '../finance/finance_format.dart';
import 'request_filter.dart';

/// Nhãn trạng thái đơn từ.
class RequestStatusPill extends StatelessWidget {
  final String status;
  const RequestStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = requestStatusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(requestStatusLabel(status), style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// Một đơn trong danh sách — cùng các cột của bảng web: Đơn từ / Người gửi / Thời gian / Trạng thái / Ngày gửi / Quy trình.
class RequestCard extends StatelessWidget {
  final ProjectRequestItem item;
  final VoidCallback onTap;

  const RequestCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.hintColor;
    final name = requesterNameOf(item);
    final procedure = item.procedureInstanceCode ?? (item.procedureInstanceId != null ? 'workspace.requests.procedure_record'.tr() : null);

    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 84, child: Text(label, style: TextStyle(fontSize: 12, color: muted))),
              Expanded(child: value),
            ],
          ),
        );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${item.code} ', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                      TextSpan(text: item.requestTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                RequestStatusPill(item.status),
              ],
            ),
            if (item.linkedViaKind != null)
              Tooltip(
                message: 'workspace.requests.via_trip_hint'.tr(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'workspace.requests.via_trip'.tr(args: {'code': item.linkedViaCode ?? ''}).trim(),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                  ),
                ),
              ),
            line(
              'workspace.requests.col_requester'.tr(),
              Row(children: [
                CircleAvatar(
                  radius: 10,
                  child: Text(_initials(name), style: const TextStyle(fontSize: 9)),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
              ]),
            ),
            line('workspace.requests.col_time'.tr(),
                Text(formatRequestRange(item.fromDate, item.toDate), style: const TextStyle(fontSize: 13))),
            line('workspace.requests.col_submitted'.tr(),
                Text(formatDateTime(item.submittedAt), style: const TextStyle(fontSize: 13))),
            if (procedure != null)
              line(
                'workspace.requests.col_procedure'.tr(),
                Row(children: [
                  Icon(Icons.account_tree_outlined, size: 13, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Flexible(child: Text(procedure, style: TextStyle(fontSize: 13, color: theme.colorScheme.primary))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chữ cái đầu của hai từ cuối (như `initials` của web project-header).
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final picked = parts.length == 1 ? parts : parts.sublist(parts.length - 2);
  return picked.map((p) => p.characters.first.toUpperCase()).join();
}
