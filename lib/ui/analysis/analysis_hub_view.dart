import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/advisor_engine.dart';
import '../../services/analytics.dart';

class AnalysisHubView extends ConsumerWidget {
  const AnalysisHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final themeMode = ref.watch(themeProvider);
    final targetBudget = ref.watch(targetBudgetProvider);
    final isDark = themeMode == ThemeMode.dark;

    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Tokens matching DESIGN.md
    final bg = isDark ? const Color(0xFF131314) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFE5E2E3) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B);
    final primaryAccent = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);

    // Cashflow & Velocity Analytics
    final monthlyExpenses = AnalyticsEngine.calculateMonthlyTotal(expenses);
    final monthlyIncome = AnalyticsEngine.calculateMonthlyIncome(expenses);
    final weeklyExpenses = AnalyticsEngine.calculateWeeklyTotal(expenses);

    final incomeConsumptionRatio =
        monthlyIncome > 0 ? ((monthlyExpenses / monthlyIncome) * 100).clamp(0.0, 999.0) : (monthlyExpenses > 0 ? 100.0 : 0.0);
    final retentionRatio = (100.0 - incomeConsumptionRatio).clamp(0.0, 100.0);

    final insights = AdvisorEngine.generateInsights(expenses);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFEEF2FF) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLight ? const Color(0xFFC7D2FE) : const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 20,
                color: primaryAccent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Analysis Hub',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header Card: Cashflow Consumption Meter
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CASHFLOW CONSUMPTION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (incomeConsumptionRatio > 80
                                  ? const Color(0xFFE11D48)
                                  : (incomeConsumptionRatio > 50 ? const Color(0xFFF59E0B) : const Color(0xFF059669)))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          incomeConsumptionRatio > 100
                              ? 'Deficit Spend'
                              : '${incomeConsumptionRatio.toStringAsFixed(1)}% Consumed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: incomeConsumptionRatio > 80
                                ? (isDark ? const Color(0xFFFFA4AC) : const Color(0xFFE11D48))
                                : (incomeConsumptionRatio > 50
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Month Inflow',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'KSh ${monthlyIncome.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: isDark ? const Color(0xFF6FFBBE) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Active Month Outlay',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'KSh ${monthlyExpenses.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: isDark ? const Color(0xFFFFB2B7) : const Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Visual Consumption Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: LinearProgressIndicator(
                        value: (incomeConsumptionRatio / 100).clamp(0.0, 1.0),
                        backgroundColor: isDark ? const Color(0xFF131314) : const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          incomeConsumptionRatio > 80
                              ? const Color(0xFFE11D48)
                              : (incomeConsumptionRatio > 50 ? const Color(0xFFF59E0B) : const Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    monthlyIncome > 0
                        ? '${retentionRatio.toStringAsFixed(1)}% of your active income pool is retained in your cashflow buffer.'
                        : 'Log your income inflows to measure your monthly consumption ratio.',
                    style: TextStyle(fontSize: 12, color: textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Metrics Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed_rounded, size: 16, color: primaryAccent),
                            const SizedBox(width: 6),
                            Text('7-Day Run Rate', style: TextStyle(fontSize: 11, color: textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'KSh ${weeklyExpenses.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.track_changes_rounded, size: 16, color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text('Target Budget', style: TextStyle(fontSize: 11, color: textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          targetBudget != null ? 'KSh ${targetBudget.toStringAsFixed(0)}' : 'Uncapped',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Advisory Intelligence Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(
                  'Heuristic Advisory Intelligence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Advice Blocks with thick left-accented colored borders
            ...insights.map((insight) {
              final type = insight['type'] ?? 'info';
              Color accentColor;
              IconData iconData;

              switch (type) {
                case 'warning':
                  accentColor = isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48); // Coral Rose
                  iconData = Icons.warning_amber_rounded;
                  break;
                case 'info':
                  accentColor = isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7); // Electric Cyan
                  iconData = Icons.info_outline_rounded;
                  break;
                case 'success':
                default:
                  accentColor = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED); // Electric Violet
                  iconData = Icons.verified_user_outlined;
                  break;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: accentColor,
                          width: 5, // Thick left-accented colored border
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconData, color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (insight['title'] != null) ...[
                                Text(
                                  insight['title']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                insight['message'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
