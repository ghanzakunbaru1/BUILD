import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/chat_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'pages/home/home_shell.dart';
import 'pages/onboarding/permission_page.dart';
import 'pages/splash/splash_page.dart';
import 'utils/constants.dart';

enum _AppStage { splash, onboarding, home }

class GhanzApp extends StatefulWidget {
  const GhanzApp({super.key});

  @override
  State<GhanzApp> createState() => _GhanzAppState();
}

class _GhanzAppState extends State<GhanzApp> {
  _AppStage _stage = _AppStage.splash;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatController()),
        ChangeNotifierProvider(create: (_) => SettingsController()..init()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: _buildStage(settings),
          );
        },
      ),
    );
  }

  Widget _buildStage(SettingsController settings) {
    switch (_stage) {
      case _AppStage.splash:
        return SplashPage(
          onFinished: () {
            setState(() {
              _stage = settings.onboardingDone ? _AppStage.home : _AppStage.onboarding;
            });
          },
        );
      case _AppStage.onboarding:
        return PermissionPage(
          onDone: () async {
            await settings.setOnboardingDone();
            setState(() => _stage = _AppStage.home);
          },
        );
      case _AppStage.home:
        return const HomeShell();
    }
  }
}
