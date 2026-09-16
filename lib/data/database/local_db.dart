import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';

class HiveService {
  static const String expensesBoxName = 'expenses_vault';
  static const String settingsBoxName = 'settings_vault';
  static const String pendingSmsBoxName = 'pending_sms_vault';
  static const String themeModeKey = 'theme_mode';
  static const String monthlyTargetKey = 'monthly_target_budget';

  Box<Map>? _expensesBox;
  Box<dynamic>? _settingsBox;
  Box<Map>? _pendingSmsBox;

  bool get isInitialized =>
      _expensesBox != null &&
      _expensesBox!.isOpen &&
      _settingsBox != null &&
      _settingsBox!.isOpen &&
      _pendingSmsBox != null &&
      _pendingSmsBox!.isOpen;

  Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    _expensesBox = await Hive.openBox<Map>(expensesBoxName);
    _settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    _pendingSmsBox = await Hive.openBox<Map>(pendingSmsBoxName);
  }

  Box<Map> get _safeExpensesBox {
    if (_expensesBox == null || !_expensesBox!.isOpen) {
      throw StateError('HiveService has not been initialized. Call init() first.');
    }
    return _expensesBox!;
  }

  Box<dynamic> get _safeSettingsBox {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      throw StateError('HiveService has not been initialized. Call init() first.');
    }
    return _settingsBox!;
  }

  Box<Map> get _safePendingSmsBox {
    if (_pendingSmsBox == null || !_pendingSmsBox!.isOpen) {
      throw StateError('HiveService has not been initialized. Call init() first.');
    }
    return _pendingSmsBox!;
  }

  // --- CRUD Handlers for Expenses & Cashflow ---

  Future<List<Expense>> getExpenses() async {
    final box = _safeExpensesBox;
    final List<Expense> expenses = [];

    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        expenses.add(Expense.fromMap(item));
      }
    }

    return expenses;
  }

  Future<void> saveExpense(Expense expense) async {
    final box = _safeExpensesBox;
    await box.put(expense.id, expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    final box = _safeExpensesBox;
    await box.delete(id);
  }

  // --- CRUD Handlers for Pending M-Pesa SMS Transactions ---

  Future<List<Map<String, dynamic>>> getPendingSmsTransactions() async {
    final box = _safePendingSmsBox;
    final List<Map<String, dynamic>> items = [];

    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        items.add(Map<String, dynamic>.from(item));
      }
    }

    return items;
  }

  Future<void> savePendingSmsTransaction(Map<String, dynamic> tx) async {
    final box = _safePendingSmsBox;
    final id = tx['id'] as String? ?? 'sms_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(id, tx);
  }

  Future<void> removePendingSmsTransaction(String id) async {
    final box = _safePendingSmsBox;
    await box.delete(id);
  }

  // --- Theme Persistence Handlers ---

  Future<void> saveThemeMode(String mode) async {
    final box = _safeSettingsBox;
    await box.put(themeModeKey, mode);
  }

  String getThemeMode() {
    final box = _safeSettingsBox;
    final storedMode = box.get(themeModeKey) as String?;
    if (storedMode == null || storedMode.isEmpty) {
      return 'light';
    }
    return storedMode;
  }

  // --- Nullable Monthly Target Budget Handlers ---

  Future<void> saveMonthlyTarget(double? target) async {
    final box = _safeSettingsBox;
    if (target == null) {
      await box.delete(monthlyTargetKey);
    } else {
      await box.put(monthlyTargetKey, target);
    }
  }

  double? getMonthlyTarget() {
    final box = _safeSettingsBox;
    final val = box.get(monthlyTargetKey);
    if (val == null) {
      return null;
    }
    if (val is num) {
      return val.toDouble();
    }
    return null;
  }
}
