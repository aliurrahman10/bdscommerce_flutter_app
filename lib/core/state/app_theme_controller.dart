import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_language.dart';
import '../config/app_theme.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController();

  static const _storage = FlutterSecureStorage();
  static const _themeKey = 'app_theme_key';
  static const _languageKey = 'app_language_code';

  String _selectedThemeKey = AppTheme.presets.first.key;
  AppLanguage _language = AppLanguage.english;
  bool _loaded = false;

  String get selectedThemeKey => _selectedThemeKey;
  AppLanguage get language => _language;
  bool get isBangla => _language.isBangla;
  bool get loaded => _loaded;
  PremiumThemePreset get selectedPreset => AppTheme.preset(_selectedThemeKey);
  AppText get text => AppText(_language);

  String t(String english, String bangla) => _language.isBangla ? bangla : english;

  Future<void> load() async {
    final savedTheme = await _storage.read(key: _themeKey);
    if (savedTheme != null && AppTheme.presets.any((item) => item.key == savedTheme)) {
      _selectedThemeKey = savedTheme;
    }
    final savedLanguage = await _storage.read(key: _languageKey);
    _language = AppLanguage.fromCode(savedLanguage);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTheme(String key) async {
    if (!AppTheme.presets.any((item) => item.key == key)) return;
    _selectedThemeKey = key;
    await _storage.write(key: _themeKey, value: key);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _storage.write(key: _languageKey, value: language.code);
    notifyListeners();
  }
}
