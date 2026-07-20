class AppConstants {
  AppConstants._();

  static const String appName = 'GHANZ AI';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your All-in-One AI Assistant';

  // Hive box names
  static const String chatBox = 'ghanz_chat_sessions';
  static const String messageBoxPrefix = 'ghanz_messages_';
  static const String settingsBox = 'ghanz_settings';

  // Gemini
  static const String geminiModel = 'gemini-2.5-flash';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Settings keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyApiKeyOverride = 'api_key_override';
}
