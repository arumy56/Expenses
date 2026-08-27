import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/database/local_db.dart';
import 'providers/expense_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final hiveService = HiveService();
  await hiveService.init();

  runApp(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(hiveService),
      ],
      child: const ExpenseApp(),
    ),
  );
}

class ExpenseApp extends ConsumerStatefulWidget {
  const ExpenseApp({super.key});

  @override
  ConsumerState<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends ConsumerState<ExpenseApp> {
  @override
  void initState() {
    super.initState();
    // Hydrate state from Hive database on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(hiveServiceProvider);
      ref.read(themeProvider.notifier).initTheme(db);
      ref.read(expenseProvider.notifier).loadInitialData(db);
      ref.read(targetBudgetProvider.notifier).initTarget(db);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // Custom Light Theme matching Design Specification
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFCF8FA),
        primaryColor: const Color(0xFF7C3AED),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF059669),
          tertiary: Color(0xFFE11D48),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFE11D48),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1B1B1D),
          outline: Color(0xFFE2E8F0),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1B1B1D)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1B1B1D),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Custom Dark Theme matching Design Specification
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131314),
        primaryColor: const Color(0xFF8B5CF6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF10B981),
          tertiary: Color(0xFFF43F5E),
          surface: Color(0xFF1E222B),
          error: Color(0xFFF43F5E),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFE5E2E3),
          outline: Color(0xFF2E3A52),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E222B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2E3A52)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2E3A52),
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E222B),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFE5E2E3)),
          titleTextStyle: TextStyle(
            color: Color(0xFFE5E2E3),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}
