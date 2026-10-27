import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight JSON based localization.
///
/// Translations live in `assets/translations/{vi,en}.json` as flat
/// dot-separated keys, e.g. `"common.save": "Lưu"`.
/// Placeholders use the `{name}` syntax: `'hrm.hello'.tr(args: {'name': 'A'})`.
class AppI18n extends ChangeNotifier {
  AppI18n._();

  static final AppI18n instance = AppI18n._();

  static const supportedLocales = [Locale('vi'), Locale('en')];
  static const _prefKey = 'app_locale';

  Locale _locale = const Locale('vi');
  final Map<String, Map<String, String>> _bundles = {};

  Locale get locale => _locale;
  bool get isVietnamese => _locale.languageCode == 'vi';

  /// Loads both bundles and the persisted locale. Call before `runApp`.
  Future<void> init() async {
    for (final code in supportedLocales.map((l) => l.languageCode)) {
      final raw = await rootBundle.loadString('assets/translations/$code.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _bundles[code] = decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && _bundles.containsKey(saved)) {
        _locale = Locale(saved);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    if (!_bundles.containsKey(locale.languageCode) || locale == _locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locale.languageCode);
    } catch (_) {}
  }

  String translate(String key, {Map<String, Object?>? args}) {
    var text = _bundles[_locale.languageCode]?[key] ??
        _bundles['vi']?[key] ??
        key;
    if (args != null) {
      args.forEach((name, value) {
        text = text.replaceAll('{$name}', '${value ?? ''}');
      });
    }
    return text;
  }
}

extension AppTranslate on String {
  /// Looks up this key in the active language bundle.
  String tr({Map<String, Object?>? args}) =>
      AppI18n.instance.translate(this, args: args);
}
