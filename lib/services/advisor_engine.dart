import '../data/models/expense.dart';
import 'analytics.dart';

class AdvisorEngine {
  /// Analyzes historical transactions and active spending velocities to generate actionable localized advice cards.
  static List<Map<String, String>> generateInsights(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return [
        {
          'type': 'success',
          'title': 'Vault Initialized',
          'message':
              'Vault empty. Use the floating action button below to log your manual entries and initialize your tracking patterns.',
        }
      ];
    }

    final List<Map<String, String>> insights = [];
    final monthlyTotal = AnalyticsEngine.calculateMonthlyTotal(expenses);
    final weeklyTotal = AnalyticsEngine.calculateWeeklyTotal(expenses);

    // Optimization Heuristic 1: High Weekly Spending Velocity
    if (monthlyTotal > 0 && (weeklyTotal / monthlyTotal) > 0.35) {
      final percentage = ((weeklyTotal / monthlyTotal) * 100).toStringAsFixed(0);
      insights.add({
        'type': 'warning',
        'title': 'High Spending Velocity',
        'message':
            'Weekly velocity ($percentage% of monthly total) is disproportionately high. Consider pausing non-essential outlays.',
      });
    }

    // Optimization Heuristic 2: Category Concentration (> 40% of current month)
    if (monthlyTotal > 0) {
      final now = DateTime.now();
      final currentMonthExpenses = expenses.where((exp) {
        final parsed = DateTime.tryParse(exp.date);
        return parsed != null && parsed.year == now.year && parsed.month == now.month;
      }).toList();

      final categoryTotals = AnalyticsEngine.calculateCategoryTotals(currentMonthExpenses);

      for (final entry in categoryTotals.entries) {
        final ratio = entry.value / monthlyTotal;
        if (ratio > 0.40) {
          final catPercent = (ratio * 100).toStringAsFixed(0);
          insights.add({
            'type': 'info',
            'title': '${entry.key} Concentration',
            'message':
                'The ${entry.key} concentration is high ($catPercent% of monthly spend). Trimming minor costs here could recover critical margin.',
          });
        }
      }
    }

    // Default healthy state card if no critical warnings triggered
    if (insights.isEmpty) {
      insights.add({
        'type': 'success',
        'title': 'Balanced Allocation',
        'message':
            'Spending velocity is well-distributed within target monthly boundaries. All transactions are securely held on-device.',
      });
    }

    return insights;
  }
}
