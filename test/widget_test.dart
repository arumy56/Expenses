import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/services/advisor_engine.dart';
import 'package:expense_tracker/services/analytics.dart';
import 'package:expense_tracker/services/export_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Expense Model Tests', () {
    test('Expense model serialization and deserialization with isIncome', () {
      const expense = Expense(
        id: 'exp_101',
        date: '2026-08-22',
        amount: 4500.0,
        category: 'Salary',
        description: 'Monthly Salary Inflow',
        isIncome: true,
      );

      final map = expense.toMap();
      expect(map['id'], 'exp_101');
      expect(map['amount'], 4500.0);
      expect(map['isIncome'], true);

      final fromMap = Expense.fromMap(map);
      expect(fromMap, equals(expense));
      expect(fromMap.isIncome, isTrue);
    });
  });

  group('Riverpod Notifier Unit Tests', () {
    test('ExpenseNotifier initial state is empty', () {
      final notifier = ExpenseNotifier();
      expect(notifier.state, isEmpty);
    });

    test('ThemeNotifier initial state is ThemeMode.light by default', () {
      final notifier = ThemeNotifier();
      expect(notifier.state, ThemeMode.light);
    });

    test('TargetBudgetNotifier initial state is null', () {
      final notifier = TargetBudgetNotifier();
      expect(notifier.state, isNull);
    });

    test('LedgerFilterNotifier tracks high-precision range and category state', () {
      final notifier = LedgerFilterNotifier();
      expect(notifier.state.selectedCategory, 'All');
      expect(notifier.state.startDate, isNull);

      notifier.setCategory('Food');
      expect(notifier.state.selectedCategory, 'Food');

      final now = DateTime.now();
      notifier.setDateRange(now.subtract(const Duration(days: 7)), now);
      expect(notifier.state.startDate, isNotNull);
      expect(notifier.state.endDate, isNotNull);

      notifier.clearDateRange();
      expect(notifier.state.startDate, isNull);
    });

    test('navigationIndexProvider defaults to 0 and updates correctly', () {
      final container = ProviderContainer();
      expect(container.read(navigationIndexProvider), 0);

      container.read(navigationIndexProvider.notifier).state = 2;
      expect(container.read(navigationIndexProvider), 2);
    });
  });

  group('AnalyticsEngine Cashflow & Range Tests', () {
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1, 15);
    final lastMonthStr = '${lastMonth.year.toString().padLeft(4, '0')}-${lastMonth.month.toString().padLeft(2, '0')}-${lastMonth.day.toString().padLeft(2, '0')}';

    final testExpenses = [
      Expense(id: '1', date: todayStr, amount: 80000.0, category: 'Salary', description: 'Salary', isIncome: true),
      Expense(id: '2', date: todayStr, amount: 1500.0, category: 'Transport', description: 'Fuel', isIncome: false),
      Expense(id: '3', date: yesterdayStr, amount: 6000.0, category: 'Shopping', description: 'Groceries', isIncome: false),
      Expense(id: '4', date: lastMonthStr, amount: 2000.0, category: 'Utilities', description: 'Tokens', isIncome: false),
    ];

    test('calculateTotalIncome sums entries where isIncome is true', () {
      final totalIncome = AnalyticsEngine.calculateTotalIncome(testExpenses);
      expect(totalIncome, 80000.0);
    });

    test('calculateTotalExpenses sums entries where isIncome is false', () {
      final totalExpenses = AnalyticsEngine.calculateTotalExpenses(testExpenses);
      expect(totalExpenses, 9500.0);
    });

    test('calculateNetFlow computes Income minus Expenses', () {
      final netFlow = AnalyticsEngine.calculateNetFlow(testExpenses);
      expect(netFlow, 70500.0);
    });

    test('filterByCustomRangeAndCategory filters correctly by range and category', () {
      final filtered = AnalyticsEngine.filterByCustomRangeAndCategory(
        testExpenses,
        yesterday,
        now,
        'Transport',
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, '2');
    });
  });

  group('ExportEngine Tests', () {
    test('generateCsvString produces RFC-compliant CSV with expected headers', () {
      final expenses = [
        const Expense(
          id: 'exp_1',
          date: '2026-08-22',
          amount: 1250.50,
          category: 'Food',
          description: 'Lunch, Cafe "Special"',
          isIncome: false,
        ),
      ];

      final csv = ExportEngine.generateCsvString(expenses);
      expect(csv.contains('ID,Date,Type,Amount (KSh),Category,Description'), isTrue);
      expect(csv.contains('exp_1,2026-08-22,Outlay,1250.50,Food,"Lunch, Cafe ""Special"""'), isTrue);
    });
  });

  group('AdvisorEngine Heuristics Tests', () {
    test('generateInsights returns welcome success insight when vault is empty', () {
      final insights = AdvisorEngine.generateInsights([]);
      expect(insights.length, 1);
      expect(insights.first['type'], 'success');
    });

    test('generateInsights triggers velocity warning and concentration info', () {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final sampleExpenses = [
        Expense(id: '1', date: todayStr, amount: 7000.0, category: 'Food', description: 'Dinner', isIncome: false),
        Expense(id: '2', date: todayStr, amount: 3000.0, category: 'Transport', description: 'Fuel', isIncome: false),
      ];

      final insights = AdvisorEngine.generateInsights(sampleExpenses);
      expect(insights.any((i) => i['type'] == 'warning'), isTrue);
      expect(insights.any((i) => i['type'] == 'info'), isTrue);
    });
  });
}
