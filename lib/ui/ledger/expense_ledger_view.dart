import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics.dart';
import '../../services/export_engine.dart';

class ExpenseLedgerView extends ConsumerStatefulWidget {
  const ExpenseLedgerView({super.key});

  @override
  ConsumerState<ExpenseLedgerView> createState() => _ExpenseLedgerViewState();
}

class _ExpenseLedgerViewState extends ConsumerState<ExpenseLedgerView> {
  static const List<String> _filterCategories = [
    'All',
    'Inflows',
    'Outlays',
    'Food',
    'Transport',
    'Fuel',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Salary',
    'Business',
    'Freelance',
    'Investments',
    'Gifts',
    'Miscellaneous',
  ];

  static const List<String> _monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize default date range to current active month if not already set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterState = ref.read(ledgerFilterProvider);
      if (filterState.startDate == null || filterState.endDate == null) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        ref.read(ledgerFilterProvider.notifier).setDateRange(startOfMonth, endOfMonth);
      }
    });
  }

  /// Launches the native, flexible DateRangePicker allowing multi-month / multi-year range selection
  Future<void> _openDateRangePicker(BuildContext context, bool isDark) async {
    final now = DateTime.now();
    final filterState = ref.read(ledgerFilterProvider);

    final initialStart = filterState.startDate ?? DateTime(now.year, now.month, 1);
    final initialEnd = filterState.endDate ?? DateTime(now.year, now.month + 1, 0);

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5), // Allows scrolling back 5 years (e.g. June or previous years)
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'SELECT CUSTOM TRANSACTION RANGE',
      confirmText: 'APPLY RANGE',
      saveText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF00D2FF),
                    onPrimary: Color(0xFF131314),
                    surface: Color(0xFF1E222B),
                    onSurface: Color(0xFFE5E2E3),
                    secondary: Color(0xFF8B5CF6),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF7C3AED),
                    onPrimary: Colors.white,
                    surface: Color(0xFFFFFFFF),
                    onSurface: Color(0xFF1B1B1D),
                    secondary: Color(0xFF7C3AED),
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      // Cleanly dispatch selected DateTime limits directly to manual state notifier
      ref.read(ledgerFilterProvider.notifier).setDateRange(pickedRange.start, pickedRange.end);
    }
  }

  void _stepMonth(int offset) {
    final filterState = ref.read(ledgerFilterProvider);
    final currentStart = filterState.startDate ?? DateTime.now();
    final newDate = DateTime(currentStart.year, currentStart.month + offset, 1);
    final startOfMonth = DateTime(newDate.year, newDate.month, 1);
    final endOfMonth = DateTime(newDate.year, newDate.month + 1, 0);
    ref.read(ledgerFilterProvider.notifier).setDateRange(startOfMonth, endOfMonth);
  }

  String _formatRangeLabel(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      final now = DateTime.now();
      return '${_monthNames[now.month - 1]} ${now.year}';
    }

    final startMonth = _monthNames[start.month - 1].substring(0, 3);
    final endMonth = _monthNames[end.month - 1].substring(0, 3);

    // If spans an exact single calendar month: e.g. "OCTOBER 2026"
    final isFullMonth = start.year == end.year &&
        start.month == end.month &&
        start.day == 1 &&
        end.day == DateTime(end.year, end.month + 1, 0).day;

    if (isFullMonth) {
      return '${_monthNames[start.month - 1]} ${start.year}';
    }

    // Same year custom range: e.g. "JUN 22 – AUG 22" or "AUG 01 – AUG 15"
    if (start.year == end.year) {
      if (start.month == end.month) {
        return '$startMonth ${start.day.toString().padLeft(2, '0')} – ${end.day.toString().padLeft(2, '0')}';
      }
      return '$startMonth ${start.day.toString().padLeft(2, '0')} – $endMonth ${end.day.toString().padLeft(2, '0')}';
    }

    // Multi-year custom range: e.g. "DEC 22, 2025 – AUG 22, 2026"
    return '$startMonth ${start.day.toString().padLeft(2, '0')} \'${start.year % 100} – $endMonth ${end.day.toString().padLeft(2, '0')} \'${end.year % 100}';
  }

  Future<void> _handleExport(BuildContext context, List<Expense> expenses) async {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No transactions in active range to export.'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      final file = await ExportEngine.exportToCsv(expenses);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 24),
                  SizedBox(width: 10),
                  Text('Export Complete', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Successfully serialized ${expenses.length} records into standard CSV format.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131314) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF45464C) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: SelectableText(
                      file.path,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'TODAY, ${_monthNames[date.month - 1].substring(0, 3)} ${date.day}';
    } else if (itemDate == yesterday) {
      return 'YESTERDAY, ${_monthNames[date.month - 1].substring(0, 3)} ${date.day}';
    } else {
      const weekdayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      final weekday = weekdayNames[date.weekday - 1];
      return '$weekday, ${_monthNames[date.month - 1].substring(0, 3)} ${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final themeMode = ref.watch(themeProvider);
    final filterState = ref.watch(ledgerFilterProvider);
    final db = ref.read(hiveServiceProvider);
    final isDark = themeMode == ThemeMode.dark;

    final cardBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
    final inputBg = isDark ? const Color(0xFF1B1B1D) : const Color(0xFFF8F9FA);
    final borderColor = isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFE5E2E3) : const Color(0xFF1B1B1D);
    final textSecondary = isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B);
    final primaryAccent = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);

    // Apply high-precision custom range and category filter
    final filteredExpenses = AnalyticsEngine.filterByCustomRangeAndCategory(
      allExpenses,
      filterState.startDate,
      filterState.endDate,
      filterState.selectedCategory,
    );

    // Group filtered records by Date string
    final Map<String, List<Expense>> groupedByDate = {};
    for (final exp in filteredExpenses) {
      groupedByDate.putIfAbsent(exp.date, () => []).add(exp);
    }
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Calculate totals for currently active range slice
    final rangeIncome = AnalyticsEngine.calculateTotalIncome(filteredExpenses);
    final rangeExpense = AnalyticsEngine.calculateTotalExpenses(filteredExpenses);
    final rangeNet = rangeIncome - rangeExpense;

    final rangeLabel = _formatRangeLabel(filterState.startDate, filterState.endDate);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131314) : const Color(0xFFFCF8FA),
      appBar: AppBar(
        backgroundColor: cardBg,
        scrolledUnderElevation: 0,
        title: const Text(
          'Notebook Ledger',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          // Range Picker Quick Trigger in AppBar
          IconButton(
            tooltip: 'Custom Date Range',
            icon: Icon(
              Icons.date_range_rounded,
              color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF7C3AED),
            ),
            onPressed: () => _openDateRangePicker(context, isDark),
          ),
          // Export CSV Icon Button exclusively situated at top right
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _handleExport(context, filteredExpenses),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dynamic Horizontal Date Range Switcher Block (< JUN 22 – AUG 22 >)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: primaryAccent, size: 28),
                    onPressed: () => _stepMonth(-1),
                    tooltip: 'Previous Month',
                  ),
                  InkWell(
                    onTap: () => _openDateRangePicker(context, isDark),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: primaryAccent),
                          const SizedBox(width: 6),
                          Text(
                            rangeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              fontFamily: 'monospace',
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, color: textSecondary, size: 18),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: primaryAccent, size: 28),
                    onPressed: () => _stepMonth(1),
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ),

            // Active Range Summary Mini Banner
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inflows',
                        style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '+KSh ${rangeIncome.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: borderColor),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlays',
                        style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '-KSh ${rangeExpense.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: borderColor),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Flow',
                        style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${rangeNet >= 0 ? '+' : ''}KSh ${rangeNet.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: rangeNet >= 0
                              ? (isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7))
                              : (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Horizontal Scrollable Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filterCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _filterCategories[index];
                  final isSelected = cat == filterState.selectedCategory;

                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(ledgerFilterProvider.notifier).setCategory(cat);
                      }
                    },
                    selectedColor: primaryAccent,
                    backgroundColor: inputBg,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : borderColor,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Grouped Notebook Ledger List
            Expanded(
              child: filteredExpenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 48,
                            color: textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No records for $rangeLabel with filter "${filterState.selectedCategory}".',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final dateStr = sortedDates[dateIndex];
                        final dateItems = groupedByDate[dateStr] ?? [];
                        final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
                        final dateHeader = _formatDateHeader(parsedDate);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bold Uppercase Date Tag with Geist/monospace feel
                            Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
                              child: Text(
                                dateHeader,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  fontFamily: 'monospace',
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            // Date's item rows
                            ...dateItems.map((item) {
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
                                  margin: const EdgeInsets.symmetric(vertical: 4),
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
                                      content: Text('Deleted "${item.description}" from vault'),
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
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      // 40px Squircle Category Badge
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
                                              '${item.category} • ${isIncome ? "Inflow" : "Outlay"}',
                                              style: TextStyle(
                                                fontSize: 11,
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
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
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

  Color _getCategoryColor(String category, bool isDark) {
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
