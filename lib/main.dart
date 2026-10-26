import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'providers/auth_provider.dart';
import 'providers/analysis_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppI18n.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider<AppI18n>.value(value: AppI18n.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1440, 900), // Standard web/desktop resolution design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final authProvider = context.watch<AuthProvider>();
        final i18n = context.watch<AppI18n>();

        return MaterialApp(
          // Rebuild the whole tree when the language changes.
          key: ValueKey(i18n.locale.languageCode),
          locale: i18n.locale,
          supportedLocales: AppI18n.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title: 'Savina Enterprise Platform',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB), // Professional Enterprise Blue
              primary: const Color(0xFF2563EB),
              secondary: const Color(0xFF10B981),
              surface: Colors.white,
              surfaceContainer: Colors.white,
              surfaceContainerLow: Colors.white,
              surfaceContainerHigh: Colors.white,
              surfaceContainerHighest: Colors.white,
              surfaceTint: Colors.transparent,
            ),
            fontFamily: 'Roboto', // Modern system font fallback
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
          ),
          home: authProvider.isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
