import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/gemini_service.dart';
import '../repository/chat_repository.dart';
import '../utils/constants.dart';

class SettingsController extends ChangeNotifier {
  late Box _box;
  ThemeMode themeMode = ThemeMode.dark;
  String? apiKeyOverride;

  Future<void> init() async {
    _box = await Hive.openBox(AppConstants.settingsBox);
    final storedTheme = _box.get(AppConstants.keyThemeMode, defaultValue: 'dark');
    themeMode = storedTheme == 'light'
        ? ThemeMode.light
        : storedTheme == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;
    apiKeyOverride = _box.get(AppConstants.keyApiKeyOverride);
    if (apiKeyOverride != null) {
      GeminiService.instance.setApiKeyOverride(apiKeyOverride);
    }
    notifyListeners();
  }

  bool get onboardingDone =>
      _box.get(AppConstants.keyOnboardingDone, defaultValue: false);

  Future<void> setOnboardingDone() async {
    await _box.put(AppConstants.keyOnboardingDone, true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _box.put(AppConstants.keyThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    apiKeyOverride = key;
    await _box.put(AppConstants.keyApiKeyOverride, key);
    GeminiService.instance.setApiKeyOverride(key);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await ChatRepository.instance.deleteAllSessions();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _box.clear();
    themeMode = ThemeMode.dark;
    apiKeyOverride = null;
    GeminiService.instance.setApiKeyOverride(null);
    notifyListeners();
  }
}
