import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/local_db.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier([super.initial = ThemeMode.light]);

  void initTheme(HiveService db) {
    final modeStr = db.getThemeMode();
    if (modeStr == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme(HiveService db) async {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await db.saveThemeMode('dark');
    } else {
      state = ThemeMode.light;
      await db.saveThemeMode('light');
    }
  }

  Future<void> setThemeMode(HiveService db, ThemeMode mode) async {
    state = mode;
    await db.saveThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(ThemeMode.light),
);
