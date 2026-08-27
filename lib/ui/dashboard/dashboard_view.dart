import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  void _showTargetBudgetDialog(BuildContext context, WidgetRef ref, double? currentTarget) {
    final controller = TextEditingController(
      text: currentTarget != null ? currentTarget.toStringAsFixed(0) : '',
    );
    final db = ref.read(hiveServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.track_changes_rounded, size: 22),
              SizedBox(width: 8),
              Text('Monthly Target Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a monthly spending ceiling in KSh. Leave blank to disable target tracking.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  prefixText: 'KSh ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF7C3AED),
                  ),
                  hintText: 'e.g. 50000',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF131314) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF45464C) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (currentTarget != null)
              TextButton(
                onPressed: () {
                  ref.read(targetBudgetProvider.notifier).setTarget(db, null);
                  Navigator.pop(context);
                },
                child: const Text('Clear Target', style: TextStyle(color: Color(0xFFE11D48))),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim().replaceAll(',', '.');
                if (text.isEmpty) {
                  ref.read(targetBudgetProvider.notifier).setTarget(db, null);
                } else {
                  final val = double.tryParse(text);
                  if (val != null && val >= 0) {
                    ref.read(targetBudgetProvider.notifier).setTarget(db, val);
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Save Target'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final themeMode = ref.watch(themeProvider);
    final targetBudget = ref.watch(targetBudgetProvider);
    final db = ref.read(hiveServiceProvider);
    final isDark = themeMode == ThemeMode.dark;

    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Tokens matching DESIGN.md
    final bg = isDark ? const Color(0xFF131314) : const Color(0xFFFCF8FA);
    final cardBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFE5E2E3) : const Color(0xFF1B1B1D);
    final textSecondary = isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B);
    final primaryAccent = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);

    // Analytics calculations
    final monthlyExpenses = AnalyticsEngine.calculateMonthlyTotal(expenses);
    final monthlyIncome = AnalyticsEngine.calculateMonthlyIncome(expenses);
    final netMonthlyFlow = monthlyIncome - monthlyExpenses;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: cardBg,
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
                Icons.shield_rounded,
                size: 20,
                color: primaryAccent,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vault',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Cashflow • Local-First',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isLight ? const Color(0xFF059669) : const Color(0xFF4EDEA3),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme(db);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Component 1: Net Cashflow Balance Card (Strictly displays formatted KSh numeric value)
            _buildNetCashflowCard(
              isDark: isDark,
              netFlow: netMonthlyFlow,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // Component 2: Metric Splits (Income vs Expenses with Target Gear)
            _buildMetricSplits(
              context: context,
              ref: ref,
              isDark: isDark,
              monthlyIncome: monthlyIncome,
              monthlyExpenses: monthlyExpenses,
              targetBudget: targetBudget,
              cardBg: cardBg,
              borderColor: borderColor,
            ),

            // Optional Responsive Financial Progress Bar (Shown ONLY when targetBudget != null)
            if (targetBudget != null && targetBudget > 0) ...[
              const SizedBox(height: 14),
              _buildBudgetProgressBar(
                isDark: isDark,
                monthlyExpenses: monthlyExpenses,
                targetBudget: targetBudget,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryAccent: primaryAccent,
              ),
            ],
            const SizedBox(height: 20),

            // Component 3: Category Breakdown Chart
            _buildCategoryBreakdownCard(
              expenses: expenses,
              monthlyTotal: monthlyExpenses,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 20),

            // Component 4: Reinstated Recent Transactions Stream (Capped to 5 items with 'View All')
            _buildRecentTransactionsSection(
              context: context,
              ref: ref,
              expenses: expenses,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryAccent: primaryAccent,
            ),
            const SizedBox(height: 80), // Padding for docked bottom nav
          ],
        ),
      ),
    );
  }

  // --- Component 1: Net Cashflow Balance Card (Strictly displays formatted KSh value) ---
  Widget _buildNetCashflowCard({
    required bool isDark,
    required double netFlow,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isPositive = netFlow >= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E2638), Color(0xFF131824)]
              : const [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isPositive
                      ? (isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669))
                      : (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MONTHLY NET CASHFLOW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${isPositive ? '+' : ''}KSh ${netFlow.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              fontFamily: 'monospace',
              color: isPositive
                  ? (isDark ? const Color(0xFF6FFBBE) : const Color(0xFF059669))
                  : (isDark ? const Color(0xFFFFB2B7) : const Color(0xFFE11D48)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Component 2: Metric Splits with Target Gear ---
  Widget _buildMetricSplits({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required double monthlyIncome,
    required double monthlyExpenses,
    required double? targetBudget,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Row(
      children: [
        // Left Card: Monthly Income
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14241C) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Income',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669),
                      ),
                    ),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '+KSh ${monthlyIncome.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFF6FFBBE) : const Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Inflow',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF4EDEA3).withValues(alpha: 0.8) : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right Card: Monthly Expenses with Target Gear
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF26151B) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFFA4AC) : const Color(0xFFE11D48),
                      ),
                    ),
                    // Gear Icon Button to set/edit Monthly Target
                    InkWell(
                      onTap: () => _showTargetBudgetDialog(context, ref, targetBudget),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.settings_outlined,
                          size: 16,
                          color: isDark ? const Color(0xFFFFA4AC) : const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '-KSh ${monthlyExpenses.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFFFFB2B7) : const Color(0xFFBE123C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetBudget != null
                      ? '${((monthlyExpenses / targetBudget) * 100).toStringAsFixed(0)}% of KSh ${targetBudget.toStringAsFixed(0)}'
                      : 'No target set (Tap ⚙️)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFFFA4AC).withValues(alpha: 0.8) : const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Optional Budget Progress Bar (Height: 8px, Corner Radius: 8px) ---
  Widget _buildBudgetProgressBar({
    required bool isDark,
    required double monthlyExpenses,
    required double targetBudget,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryAccent,
  }) {
    final consumptionRatio = (monthlyExpenses / targetBudget);
    final isExceeded = consumptionRatio > 1.0;
    final progressVal = consumptionRatio.clamp(0.0, 1.0);

    final progressColor = isExceeded
        ? const Color(0xFFE11D48) // Coral Rose if > 100%
        : (isDark ? const Color(0xFF00D2FF) : const Color(0xFF7C3AED)); // Electric Violet / Cyan under budget

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isExceeded ? Icons.warning_amber_rounded : Icons.track_changes_rounded,
                    size: 15,
                    color: progressColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Budget Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${(consumptionRatio * 100).toStringAsFixed(1)}% used',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progressVal,
                backgroundColor: isDark ? const Color(0xFF131314) : const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isExceeded
                ? 'Budget exceeded by KSh ${(monthlyExpenses - targetBudget).toStringAsFixed(0)}.'
                : 'KSh ${(targetBudget - monthlyExpenses).toStringAsFixed(0)} remaining of KSh ${targetBudget.toStringAsFixed(0)} target.',
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Component 3: Category Breakdown Chart ---
  Widget _buildCategoryBreakdownCard({
    required List<Expense> expenses,
    required double monthlyTotal,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((exp) {
      final parsed = DateTime.tryParse(exp.date);
      return !exp.isIncome && parsed != null && parsed.year == now.year && parsed.month == now.month;
    }).toList();

    final categoryTotals = AnalyticsEngine.calculateCategoryTotals(
      currentMonthExpenses.isNotEmpty ? currentMonthExpenses : expenses.where((e) => !e.isIncome).toList(),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                'Monthly Expenses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (categoryTotals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No outlays recorded for breakdown.',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
            )
          else ...[
            // Segmented CustomPainter Bar
            SizedBox(
              height: 22,
              child: CustomPaint(
                painter: CategorySegmentBarPainter(
                  categoryTotals: categoryTotals,
                  total: categoryTotals.values.fold(0.0, (a, b) => a + b),
                  isDark: isDark,
                ),
                size: const Size(double.infinity, 22),
              ),
            ),
            const SizedBox(height: 18),
            // Category Legend Grid
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: categoryTotals.entries.map((e) {
                final color = _getCategoryColor(e.key, isDark);
                final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
                final percent = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key} ($percent%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'KSh ${e.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --- Component 4: Reinstated Recent Transactions Stream (Capped to 5 with 'View All') ---
  Widget _buildRecentTransactionsSection({
    required BuildContext context,
    required WidgetRef ref,
    required List<Expense> expenses,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryAccent,
  }) {
    final db = ref.read(hiveServiceProvider);

    // Pull active data and order chronologically (latest date first)
    final sortedExpenses = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    final topExpenses = sortedExpenses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // Switches parent tab index state provider over to index 2 (Ledger)
                ref.read(navigationIndexProvider.notifier).state = 2;
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                children: [
                  Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (topExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 42,
                    color: textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transaction records yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button below to log your first income or expense.',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topExpenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = topExpenses[index];
              final catColor = _getCategoryColor(item.category, isDark);
              final isIncome = item.isIncome;

              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (DismissDirection direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        backgroundColor: isDark ? const Color(0xFF2A2A2B) : const Color(0xFFFFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          'Confirm Deletion',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: textPrimary,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to permanently erase this transaction record from your local storage vault?',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.delete_forever_rounded, color: Colors.white),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  ref.read(expenseProvider.notifier).removeExpense(db, item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${item.description}" from vault'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: const Color(0xFF00D2FF),
                        onPressed: () {
                          ref.read(expenseProvider.notifier).addExpense(db, item);
                        },
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // 40px Squircle Icon Container
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? catColor.withValues(alpha: 0.15) : const Color(0xFFF0EDEF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(item.category),
                          color: catColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.category} • ${item.date}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${isIncome ? '+' : '-'}KSh ${item.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: isIncome
                              ? (isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669))
                              : (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  static IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Fuel':
        return Icons.local_gas_station_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      case 'Entertainment':
        return Icons.movie_filter_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Salary':
        return Icons.payments_rounded;
      case 'Business':
        return Icons.storefront_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Investments':
        return Icons.trending_up_rounded;
      case 'Gifts':
        return Icons.card_giftcard_rounded;
      case 'Miscellaneous':
      default:
        return Icons.category_rounded;
    }
  }

  static Color _getCategoryColor(String category, bool isDark) {
    switch (category) {
      case 'Food':
        return const Color(0xFFF59E0B);
      case 'Transport':
        return isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7);
      case 'Fuel':
        return const Color(0xFFF97316);
      case 'Utilities':
        return isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669);
      case 'Entertainment':
        return isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
      case 'Shopping':
        return const Color(0xFFEC4899);
      case 'Salary':
      case 'Business':
      case 'Freelance':
      case 'Investments':
      case 'Gifts':
        return isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669);
      case 'Miscellaneous':
      default:
        return const Color(0xFF909096);
    }
  }
}

/// CustomPainter for segmented horizontal category spending distribution
class CategorySegmentBarPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double total;
  final bool isDark;

  CategorySegmentBarPainter({
    required this.categoryTotals,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    canvas.save();
    canvas.clipRRect(rect);

    double currentX = 0.0;
    for (final entry in categoryTotals.entries) {
      final width = (entry.value / total) * size.width;
      final color = DashboardView._getCategoryColor(entry.key, isDark);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(currentX, 0, width, size.height), paint);
      currentX += width;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CategorySegmentBarPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.categoryTotals != categoryTotals ||
        oldDelegate.isDark != isDark;
  }
}
