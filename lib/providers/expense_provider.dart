import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/local_db.dart';
import '../data/models/expense.dart';

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  ExpenseNotifier([List<Expense>? initial]) : super(initial ?? []);

  Future<void> loadInitialData(HiveService db) async {
    final expenses = await db.getExpenses();
    // Sort transactions with latest first
    expenses.sort((a, b) => b.date.compareTo(a.date));
    state = expenses;
  }

  Future<void> addExpense(HiveService db, Expense exp) async {
    await db.saveExpense(exp);
    final updatedList = [exp, ...state.where((e) => e.id != exp.id)];
    updatedList.sort((a, b) => b.date.compareTo(a.date));
    state = updatedList;
  }

  Future<void> removeExpense(HiveService db, String id) async {
    await db.deleteExpense(id);
    state = state.where((e) => e.id != id).toList();
  }
}

class TargetBudgetNotifier extends StateNotifier<double?> {
  TargetBudgetNotifier([super.initial]);

  void initTarget(HiveService db) {
    state = db.getMonthlyTarget();
  }

  Future<void> setTarget(HiveService db, double? target) async {
    await db.saveMonthlyTarget(target);
    state = target;
  }
}

/// Unified, immutable state container for Ledger range and category filters
class LedgerFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String selectedCategory; // 'All', 'Inflows', 'Outlays', 'Food', etc.

  const LedgerFilterState({
    this.startDate,
    this.endDate,
    this.selectedCategory = 'All',
  });

  LedgerFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? selectedCategory,
    bool clearDates = false,
  }) {
    return LedgerFilterState(
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class LedgerFilterNotifier extends StateNotifier<LedgerFilterState> {
  LedgerFilterNotifier() : super(const LedgerFilterState());

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void clearDateRange() {
    state = state.copyWith(clearDates: true);
  }

  void reset() {
    state = const LedgerFilterState();
  }
}

final hiveServiceProvider = Provider<HiveService>((ref) => HiveService());

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, List<Expense>>(
  (ref) => ExpenseNotifier([]),
);

final targetBudgetProvider =
    StateNotifierProvider<TargetBudgetNotifier, double?>(
  (ref) => TargetBudgetNotifier(),
);

final ledgerFilterProvider =
    StateNotifierProvider<LedgerFilterNotifier, LedgerFilterState>(
  (ref) => LedgerFilterNotifier(),
);

final navigationIndexProvider = StateProvider<int>((ref) => 0);
