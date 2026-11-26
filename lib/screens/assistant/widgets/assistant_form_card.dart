import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../models/assistant_models.dart';
import '../forms/assistant_form_registry.dart';
import 'assistant_message_view.dart';

/// Mở form của phân hệ cho thẻ [card] và trả thẻ đã cập nhật theo kết quả (web: trang form nhúng gửi `result`).
Future<AssistantFormCard> runAssistantForm(BuildContext context, AssistantFormCard card) async {
  final opener = assistantFormOpeners[card.key];
  if (opener == null) {
    return card.copyWith(state: 'unavailable', message: 'assistant.form.unsupported'.tr());
  }
  try {
    final result = await opener(context, card.draft, card.variant);
    return card.copyWith(
      state: result.outcome,
      label: result.label,
      href: result.href,
      message: result.message,
      clearResult: result.outcome == 'cancelled',
    );
  } catch (e) {
    return card.copyWith(state: 'failed', message: e.toString());
  }
}

/// Thẻ form trong khung chat (web `Vme`): tiêu đề thao tác (hoặc tên bản ghi khi đã tạo), trạng thái
/// (Đã tạo / Đã đóng / Không mở được / Lỗi), "Xem" bản ghi vừa tạo, "Mở lại" khi đã đóng hoặc lỗi.
/// Web đặt form ngay trong thẻ; mobile mở form của phân hệ dạng bảng trượt, thẻ còn mở thì có nút "Mở form".
class AssistantFormCardView extends StatelessWidget {
  final AssistantFormCard card;
  final VoidCallback onOpen;
  const AssistantFormCardView({super.key, required this.card, required this.onOpen});

  static const Map<String, String> _stateKeys = {
    'saved': 'assistant.form.state.saved',
    'cancelled': 'assistant.form.state.cancelled',
    'unavailable': 'assistant.form.state.unavailable',
    'failed': 'assistant.form.state.failed',
  };

  @override
  Widget build(BuildContext context) {
    final state = card.state;
    final (Color bg, Color fg) = switch (state) {
      'saved' => (const Color(0xFFD1FAE5), const Color(0xFF047857)),
      'failed' || 'unavailable' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
    };
    return Container(
      margin: const EdgeInsets.only(left: 42, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.description_outlined, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state == 'saved' && card.label != null ? card.label! : card.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (state != 'open')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Text(_stateKeys[state]?.tr() ?? state, style: TextStyle(fontSize: 11, color: fg)),
              ),
          ]),
          if (card.message != null && state != 'saved') ...[
            const SizedBox(height: 6),
            Text(card.message!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ],
          if (state == 'open' || state == 'cancelled' || state == 'failed' || (state == 'saved' && card.href != null)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: state == 'saved'
                  ? TextButton(
                      onPressed: () => openAssistantLink(context, card.href!),
                      child: Text('assistant.form.view'.tr()),
                    )
                  : state == 'open'
                      ? FilledButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: Text('assistant.form.open'.tr()),
                        )
                      : OutlinedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text('assistant.form.reopen'.tr()),
                        ),
            ),
          ],
        ],
      ),
    );
  }
}
