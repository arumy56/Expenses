import '../data/models/expense.dart';

class AnalyticsEngine {
  /// Helper to parse date string from expense into a DateTime object
  static DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// High-precision multi-dimensional filter combining date range boundaries and category segregation
  static List<Expense> filterByCustomRangeAndCategory(
    List<Expense> expenses,
    DateTime? start,
    DateTime? end,
    String category,
  ) {
    return expenses.where((item) {
      final itemDate = _parseDate(item.date);
      if (itemDate == null) return false;

      // 1. Date Range Boundaries Verification
      if (start != null) {
        final startBoundary = DateTime(start.year, start.month, start.day);
        if (itemDate.isBefore(startBoundary)) return false;
      }

      if (end != null) {
        final endBoundary = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        if (itemDate.isAfter(endBoundary)) return false;
      }

      // 2. Type & Category Segregation Filters
      if (category == 'All') return true;
      if (category == 'Inflows') return item.isIncome;
      if (category == 'Outlays') return !item.isIncome;

      return item.category.toLowerCase() == category.toLowerCase();
    }).toList();
  }

  /// Sums entries where isIncome is true
  static double calculateTotalIncome(List<Expense> expenses) {
    double total = 0.0;
    for (final exp in expenses) {
      if (exp.isIncome) {
        total += exp.amount;
      }
    }
    return total;
  }

  /// Sums entries where isIncome is false (outlays/expenses)
  static double calculateTotalExpenses(List<Expense> expenses) {
    double total = 0.0;
    for (final exp in expenses) {
      if (!exp.isIncome) {
        total += exp.amount;
      }
    }
    return total;
  }

  /// Returns net cash flow (Total Income - Total Expenses)
  static double calculateNetFlow(List<Expense> expenses) {
    return calculateTotalIncome(expenses) - calculateTotalExpenses(expenses);
  }

  /// Filters expenses and incomes falling strictly inside the given year and month
  static List<Expense> filterByMonthAndYear(List<Expense> expenses, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return filterByCustomRangeAndCategory(expenses, start, end, 'All');
  }

  /// Groups expenses (isIncome == false) matching target date
  static double calculateDailyTotal(List<Expense> expenses, DateTime targetDate) {
    final targetFormatted = _formatDateKey(targetDate);
    double total = 0.0;

    for (final exp in expenses) {
      if (exp.isIncome) continue;
      final parsed = _parseDate(exp.date);
      if (parsed != null && _formatDateKey(parsed) == targetFormatted) {
        total += exp.amount;
      } else if (exp.date.startsWith(targetFormatted)) {
        total += exp.amount;
      }
    }

    return total;
  }

  /// Filters expenses (isIncome == false) falling within a moving 7-day rolling window relative to now
  static double calculateWeeklyTotal(List<Expense> expenses) {
    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    double total = 0.0;

    for (final exp in expenses) {
      if (exp.isIncome) continue;
      final parsed = _parseDate(exp.date);
      if (parsed != null) {
        if (parsed.isAfter(sevenDaysAgo.subtract(const Duration(milliseconds: 1))) &&
            parsed.isBefore(endOfToday.add(const Duration(milliseconds: 1)))) {
          total += exp.amount;
        }
      }
    }

    return total;
  }

  /// Aggregates expenses (isIncome == false) falling strictly inside the active calendar month
  static double calculateMonthlyTotal(List<Expense> expenses) {
    final now = DateTime.now();
    final monthlyList = filterByMonthAndYear(expenses, now.year, now.month);
    return calculateTotalExpenses(monthlyList);
  }

  /// Aggregates income (isIncome == true) falling strictly inside the active calendar month
  static double calculateMonthlyIncome(List<Expense> expenses) {
    final now = DateTime.now();
    final monthlyList = filterByMonthAndYear(expenses, now.year, now.month);
    return calculateTotalIncome(monthlyList);
  }

  /// Aggregates expenses by category (for expenses)
  static Map<String, double> calculateCategoryTotals(List<Expense> expenses) {
    final Map<String, double> categoryTotals = {};

    for (final exp in expenses) {
      if (exp.isIncome) continue;
      categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0.0) + exp.amount;
    }

    return categoryTotals;
  }

  static String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
