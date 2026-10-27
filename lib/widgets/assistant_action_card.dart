import 'package:flutter/material.dart';
import '../core/i18n/app_i18n.dart';
import '../models/assistant_models.dart';
import '../services/assistant_service.dart';

class AssistantActionCard extends StatefulWidget {
  final AssistantActionDraft draft;
  final VoidCallback? onSubmitted;

  const AssistantActionCard({
    super.key,
    required this.draft,
    this.onSubmitted,
  });

  @override
  State<AssistantActionCard> createState() => _AssistantActionCardState();
}

class _AssistantActionCardState extends State<AssistantActionCard> {
  final AssistantService _assistantService = AssistantService();

  late TextEditingController _titleCtrl;
  late TextEditingController _reasonCtrl;
  late TextEditingController _destCtrl;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.draft.fields['title']?.toString() ?? '');
    _reasonCtrl = TextEditingController(text: widget.draft.fields['reason']?.toString() ?? widget.draft.fields['description']?.toString() ?? '');
    _destCtrl = TextEditingController(text: widget.draft.fields['destination']?.toString() ?? '');
    _locationCtrl = TextEditingController(text: widget.draft.fields['location']?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _reasonCtrl.dispose();
    _destCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitDraft() async {
    setState(() {
      widget.draft.status = ActionDraftStatus.submitting;
    });

    // Cập nhật giá trị đã chỉnh sửa vào fields
    if (widget.draft.fields.containsKey('title')) widget.draft.fields['title'] = _titleCtrl.text.trim();
    if (widget.draft.fields.containsKey('reason')) widget.draft.fields['reason'] = _reasonCtrl.text.trim();
    if (widget.draft.fields.containsKey('description')) widget.draft.fields['description'] = _reasonCtrl.text.trim();
    if (widget.draft.fields.containsKey('destination')) widget.draft.fields['destination'] = _destCtrl.text.trim();
    if (widget.draft.fields.containsKey('location')) widget.draft.fields['location'] = _locationCtrl.text.trim();

    final res = await _assistantService.executeActionDraft(widget.draft);

    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          widget.draft.status = ActionDraftStatus.submitted;
          widget.draft.resultId = res['id']?.toString();
          widget.draft.resultLabel = res['label']?.toString();
          widget.onSubmitted?.call();
        } else {
          widget.draft.status = ActionDraftStatus.error;
          widget.draft.errorMessage = res['error']?.toString() ?? 'widgets.action_card.save_unknown_error'.tr();
        }
      });
    }
  }

  Future<void> _pickDate(String fieldKey, String currentValue) async {
    final current = DateTime.tryParse(currentValue) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final str = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        widget.draft.fields[fieldKey] = str;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final isDone = d.status == ActionDraftStatus.submitted;
    final isCancelled = d.status == ActionDraftStatus.cancelled;
    final isError = d.status == ActionDraftStatus.error;
    final isSubmitting = d.status == ActionDraftStatus.submitting;

    Color headerBg;
    Color iconColor;
    IconData icon;

    switch (d.module) {
      case 'HRM':
        headerBg = const Color(0xFFECFDF5);
        iconColor = const Color(0xFF059669);
        icon = Icons.beach_access_rounded;
        break;
      case 'WORKSPACE':
        headerBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        icon = Icons.assignment_turned_in_rounded;
        break;
      case 'MAINTENANCE':
        headerBg = const Color(0xFFFFF1F2);
        iconColor = const Color(0xFFE11D48);
        icon = Icons.warning_amber_rounded;
        break;
      default:
        headerBg = const Color(0xFFF1F5F9);
        iconColor = const Color(0xFF475569);
        icon = Icons.auto_awesome_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? const Color(0xFF86EFAC)
              : isCancelled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFCBD5E1),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: headerBg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'widgets.action_card.module_subtitle'.tr(args: {'module': d.module}),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFDCFCE7)
                          : isCancelled
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isDone
                          ? 'widgets.action_card.badge_saved'.tr()
                          : isCancelled
                              ? 'widgets.action_card.badge_cancelled'.tr()
                              : 'widgets.action_card.badge_draft'.tr(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? const Color(0xFF15803D)
                            : isCancelled
                                ? const Color(0xFF64748B)
                                : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Body / Form Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: isDone
                  ? _buildSuccessView(d)
                  : isCancelled
                      ? _buildCancelledView()
                      : _buildFormFields(d),
            ),

            // 3. Footer Action Buttons
            if (!isDone && !isCancelled) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                widget.draft.status = ActionDraftStatus.cancelled;
                              });
                            },
                      child: Text('widgets.action_card.cancel_action'.tr(), style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSubmitting ? null : _submitDraft,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('widgets.action_card.confirm_send'.tr(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.send_rounded, size: 14),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],

            if (isError) ...[
              Container(
                padding: const EdgeInsets.all(10),
                color: const Color(0xFFFEF2F2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.errorMessage ?? 'widgets.action_card.error_generic'.tr(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(AssistantActionDraft d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'widgets.action_card.success'.tr(),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 2),
                Text(
                  d.resultLabel ?? d.title,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                ),
                if (d.resultId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'widgets.action_card.record_id'.tr(args: {'id': d.resultId}),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'widgets.action_card.draft_cancelled'.tr(),
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildFormFields(AssistantActionDraft d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title or Destination or Equipment
        if (d.fields.containsKey('title')) ...[
          _buildFieldLabel('widgets.action_card.field_title'.tr()),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: _fieldInputDecoration('widgets.action_card.field_title_hint'.tr()),
          ),
          const SizedBox(height: 10),
        ],

        if (d.fields.containsKey('destination')) ...[
          _buildFieldLabel('widgets.action_card.field_destination'.tr()),
          TextField(
            controller: _destCtrl,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: _fieldInputDecoration('widgets.action_card.field_destination_hint'.tr()),
          ),
          const SizedBox(height: 10),
        ],

        // Date Selectors
        if (d.fields.containsKey('fromDate') || d.fields.containsKey('workDate') || d.fields.containsKey('dueDate')) ...[
          Row(
            children: [
              if (d.fields.containsKey('fromDate'))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('common.from_date'.tr()),
                      _buildDatePickerChip('fromDate', d.fields['fromDate']?.toString() ?? ''),
                    ],
                  ),
                ),
              if (d.fields.containsKey('fromDate') && d.fields.containsKey('toDate'))
                const SizedBox(width: 8),
              if (d.fields.containsKey('toDate'))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('common.to_date'.tr()),
                      _buildDatePickerChip('toDate', d.fields['toDate']?.toString() ?? ''),
                    ],
                  ),
                ),
              if (d.fields.containsKey('workDate'))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('widgets.action_card.field_ot_date'.tr()),
                      _buildDatePickerChip('workDate', d.fields['workDate']?.toString() ?? ''),
                    ],
                  ),
                ),
              if (d.fields.containsKey('dueDate'))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('widgets.action_card.field_deadline'.tr()),
                      _buildDatePickerChip('dueDate', d.fields['dueDate']?.toString() ?? ''),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Location
        if (d.fields.containsKey('location')) ...[
          _buildFieldLabel('widgets.action_card.field_location'.tr()),
          TextField(
            controller: _locationCtrl,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: _fieldInputDecoration('widgets.action_card.field_location_hint'.tr()),
          ),
          const SizedBox(height: 10),
        ],

        // Priority Chips
        if (d.fields.containsKey('priority')) ...[
          _buildFieldLabel('widgets.action_card.field_priority'.tr()),
          Wrap(
            spacing: 6,
            children: ['low', 'normal', 'high', 'urgent'].map((p) {
              final isSel = d.fields['priority'] == p;
              String label;
              Color col;
              switch (p) {
                case 'urgent':
                  label = 'widgets.action_card.priority_urgent'.tr();
                  col = const Color(0xFFE11D48);
                  break;
                case 'high':
                  label = 'widgets.action_card.priority_high'.tr();
                  col = const Color(0xFFD97706);
                  break;
                case 'low':
                  label = 'widgets.action_card.priority_low'.tr();
                  col = const Color(0xFF64748B);
                  break;
                default:
                  label = 'widgets.action_card.priority_normal'.tr();
                  col = const Color(0xFF2563EB);
              }
              return ChoiceChip(
                label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => d.fields['priority'] = p);
                },
                selectedColor: col.withValues(alpha: 0.15),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(color: isSel ? col : const Color(0xFF475569)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        // Reason / Description
        _buildFieldLabel('widgets.action_card.field_reason'.tr()),
        TextField(
          controller: _reasonCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: _fieldInputDecoration('widgets.action_card.field_reason_hint'.tr()),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
      ),
    );
  }

  Widget _buildDatePickerChip(String key, String value) {
    return InkWell(
      onTap: () => _pickDate(key, value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value.isNotEmpty ? value : 'widgets.action_card.pick_date'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
            const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
