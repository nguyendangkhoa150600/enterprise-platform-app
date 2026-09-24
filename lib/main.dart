import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './providers/auth_provider.dart';
import './providers/analysis_provider.dart';
import './screens/tenant_input_screen.dart';
import './screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
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

        return MaterialApp(
          title: 'Savina Enterprise Platform',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber,
              primary: Colors.amber.shade700,
              secondary: const Color(0xFF10B981),
              surface: Colors.white,
            ),
            fontFamily: 'Roboto', // Modern system font fallback
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          ),
          home: authProvider.isLoggedIn
              ? const HomeScreen()
              : const TenantInputScreen(),
        );
      },
    );
  }
}
