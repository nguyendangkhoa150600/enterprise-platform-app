import 'package:flutter/material.dart';
import '../../core/i18n/app_i18n.dart';
import '../../theme/colors.dart';

class _LangOption {
  final Locale locale;
  final String flag;
  final String code;
  final String nameKey;
  const _LangOption(this.locale, this.flag, this.code, this.nameKey);
}

const _options = [
  _LangOption(Locale('vi'), '🇻🇳', 'VI', 'language.name_vi'),
  _LangOption(Locale('en'), '🇬🇧', 'EN', 'language.name_en'),
];

/// Settings row showing the current language; tapping opens a bottom sheet to switch.
class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({super.key});

  static const _cyan = Color(0xFF06B6D4);

  static Future<void> _openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: AppI18n.instance,
          builder: (_, __) {
            final current = AppI18n.instance.locale.languageCode;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'language.select_title'.tr(),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final o in _options)
                    _optionRow(sheetContext, o, o.locale.languageCode == current),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _optionRow(BuildContext sheetContext, _LangOption o, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await AppI18n.instance.setLocale(o.locale);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFEDE3) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(o.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${o.nameKey.tr()} (${o.code})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppI18n.instance,
      builder: (context, _) {
        final o = _options.firstWhere(
          (e) => e.locale.languageCode == AppI18n.instance.locale.languageCode,
          orElse: () => _options.first,
        );
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSheet(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.language_rounded, color: _cyan, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'language.app_language'.tr(),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${o.nameKey.tr()} (${o.code}) ${o.flag}',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cyan.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${o.flag} ${o.code}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _cyan),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
