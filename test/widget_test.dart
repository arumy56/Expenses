import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/sms_queue_provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/services/advisor_engine.dart';
import 'package:expense_tracker/services/analytics.dart';
import 'package:expense_tracker/services/export_engine.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:expense_tracker/services/sms_parser.dart';
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

  group('SmsParser Regex & Extraction Tests', () {
    test('parseMpesaSms extracts Inflow received funds properly', () {
      const msg =
          'QA45TY7890 Confirmed. You have received Ksh1,500.00 from JOHN DOE 0712345678 on 22/8/26 at 4:30 PM. New M-PESA balance is Ksh5,400.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 1500.0);
      expect(parsed['isIncome'], isTrue);
      expect(parsed['description'], contains('JOHN DOE'));
      expect(parsed['referenceCode'], 'QA45TY7890');
      expect(parsed['date'], '2026-08-22');
    });

    test('parseMpesaSms extracts Outlay sent money properly', () {
      const msg =
          'QA45TY7891 Confirmed. Ksh1,200.00 sent to JANE DOE 0722334455 on 22/8/26 at 2:15 PM. New M-PESA balance is Ksh4,200.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 1200.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('JANE DOE'));
      expect(parsed['referenceCode'], 'QA45TY7891');
      expect(parsed['date'], '2026-08-22');
    });

    test('parseMpesaSms extracts Outlay paid to merchant / Buy Goods properly', () {
      const msg =
          'QA45TY7892 Confirmed. Ksh2,450.00 paid to QUICKMART SUPERMARKET. on 28/8/26 at 7:00 PM. New M-PESA balance is Ksh1,750.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 2450.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('QUICKMART SUPERMARKET'));
      expect(parsed['referenceCode'], 'QA45TY7892');
      expect(parsed['date'], '2026-08-28');
    });

    test('parseMpesaSms extracts Outlay withdrawn from Agent properly', () {
      const msg =
          'QA45TY7894 Confirmed. Ksh5,000.00 withdrawn from 123456 - AGENT NAME on 22/8/26 at 11:00 AM. New M-PESA balance is Ksh200.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 5000.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('AGENT NAME'));
      expect(parsed['referenceCode'], 'QA45TY7894');
    });

    test('parseMpesaSms extracts Paybill with account number properly', () {
      const msg =
          'QA45TY7895 Confirmed. Ksh 3,000.00 paid to KPLC PREPAID for account 123456 on 29/8/26 at 8:00 AM. New M-PESA balance is Ksh500.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 3000.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('KPLC PREPAID'));
    });

    test('parseMpesaSms extracts Bank to M-Pesa transfer properly', () {
      const msg =
          'QA45TY7896 Confirmed. Ksh10,000.00 transferred from Equity Bank on 29/8/26 at 9:30 AM.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 10000.0);
      expect(parsed['isIncome'], isTrue);
      expect(parsed['description'], contains('Equity Bank'));
    });

    test('parseMpesaSms extracts Outlay when format is You have sent Ksh... properly', () {
      const msg =
          'QA45TY7897 Confirmed. You have sent Ksh1,200.00 to JANE DOE 0722334455 on 22/8/26 at 2:15 PM. New M-PESA balance is Ksh4,200.00.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 1200.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('JANE DOE'));
      expect(parsed['referenceCode'], 'QA45TY7897');
    });

    test('parseMpesaSms extracts Outlay with Ksh. period prefix properly', () {
      const msg =
          'QA45TY7898 Confirmed. Ksh. 500.00 sent to 0712345678 - JANE DOE on 22/8/26 at 3:00 PM.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 500.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('JANE DOE'));
    });

    test('parseMpesaSms extracts Outlay when format is You have paid Ksh... properly', () {
      const msg =
          'QA45TY7899 Confirmed. You have paid Ksh 2,450.00 to QUICKMART SUPERMARKET on 28/8/26 at 7:00 PM.';
      final parsed = SmsParser.parseMpesaSms(msg);

      expect(parsed, isNotNull);
      expect(parsed!['amount'], 2450.0);
      expect(parsed['isIncome'], isFalse);
      expect(parsed['description'], contains('QUICKMART SUPERMARKET'));
    });

    test('parseMpesaSms returns null on non-M-Pesa or promotional messages', () {
      expect(SmsParser.parseMpesaSms('Your OTP code is 481920. Do not share.'), isNull);
      expect(SmsParser.parseMpesaSms(''), isNull);
      expect(SmsParser.parseMpesaSms('Hey, are we still meeting for lunch today?'), isNull);
      expect(SmsParser.parseMpesaSms('Special offer! Get 50% discount on data bundles today.'), isNull);
    });
  });

  group('SmsQueueNotifier Tests', () {
    test('SmsQueueNotifier initializes with empty state', () {
      final notifier = SmsQueueNotifier();
      expect(notifier.state, isEmpty);
    });

    test('SmsQueueNotifier accepts initial pending items', () {
      final sampleTx = {
        'id': 'mpesa_QA45TY7890',
        'referenceCode': 'QA45TY7890',
        'amount': 1500.0,
        'isIncome': true,
        'description': 'JOHN DOE 0712345678',
        'date': '2026-08-22',
        'timestamp': 1724300000000,
      };
      final notifier = SmsQueueNotifier([sampleTx]);
      expect(notifier.state.length, 1);
      expect(notifier.state.first['amount'], 1500.0);
    });

    test('smsQueueProvider is registered and readable via ProviderContainer', () {
      final container = ProviderContainer();
      expect(container.read(smsQueueProvider), isEmpty);
    });

    test('smsPermissionProvider initializes to false', () {
      final container = ProviderContainer();
      expect(container.read(smsPermissionProvider), isFalse);
    });

    test('batteryOptimizationProvider initializes to false', () {
      final container = ProviderContainer();
      expect(container.read(batteryOptimizationProvider), isFalse);
    });
  });

  group('NotificationService Configuration Tests', () {
    test('NotificationService channel parameters match privacy design tokens', () {
      expect(NotificationService.channelId, 'vault_alerts');
      expect(NotificationService.channelName, 'Vault Alerts');
      expect(NotificationService.channelDescription, contains('Instant M-Pesa'));
    });
  });
}
