import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import 'analysis/analysis_hub_view.dart';
import 'dashboard/dashboard_view.dart';
import 'forms/input_expense.dart';
import 'ledger/expense_ledger_view.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  static const List<Widget> _screens = [
    DashboardView(),
    AnalysisHubView(),
    ExpenseLedgerView(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final navBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
    final selectedColor = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
    final unselectedColor = isDark ? const Color(0xFF909096) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0);
    final primaryAccent = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF8B5CF6), Color(0xFF7C3AED)]
                : const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryAccent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          tooltip: 'Add Transaction',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const InputExpenseScreen(),
              ),
            );
          },
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: navBg,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 64,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tab 0: Vault
              _buildNavItem(
                ref: ref,
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Vault',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              // Tab 1: Analysis
              _buildNavItem(
                ref: ref,
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights_rounded,
                label: 'Analysis',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              // Center spacing for docked FAB
              const SizedBox(width: 48),
              // Tab 2: Ledger
              _buildNavItem(
                ref: ref,
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Ledger',
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final isSelected = index == currentIndex;
    return InkWell(
      onTap: () {
        ref.read(navigationIndexProvider.notifier).state = index;
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
