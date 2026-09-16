import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/expense.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/sms_queue_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/sms_parser.dart';

class SmsApprovalQueueScreen extends ConsumerStatefulWidget {
  const SmsApprovalQueueScreen({super.key});

  @override
  ConsumerState<SmsApprovalQueueScreen> createState() =>
      _SmsApprovalQueueScreenState();
}

class _SmsApprovalQueueScreenState
    extends ConsumerState<SmsApprovalQueueScreen> {
  static const _uuid = Uuid();

  static const List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Fuel',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Miscellaneous',
  ];

  static const List<String> _incomeCategories = [
    'Salary',
    'Business',
    'Freelance',
    'Investments',
    'Gifts',
    'Miscellaneous',
  ];

  // Map category to icon for rich visual chips
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_bus_rounded;
      case 'Fuel':
        return Icons.local_gas_station_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      case 'Entertainment':
        return Icons.movie_creation_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Salary':
        return Icons.account_balance_wallet_rounded;
      case 'Business':
        return Icons.store_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Investments':
        return Icons.trending_up_rounded;
      case 'Gifts':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Future<void> _approveAndLogTransaction({
    required Map<String, dynamic> tx,
    required String selectedCategory,
  }) async {
    final db = ref.read(hiveServiceProvider);

    final id = 'exp_${_uuid.v4().substring(0, 8)}';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isIncome = tx['isIncome'] as bool? ?? false;
    final description = tx['description'] as String? ?? 'M-Pesa Transaction';
    final date = tx['date'] as String? ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    final newExpense = Expense(
      id: id,
      date: date,
      amount: amount,
      category: selectedCategory,
      description: description,
      isIncome: isIncome,
    );

    // 1. Commit to expenses database
    await ref.read(expenseProvider.notifier).addExpense(db, newExpense);

    // 2. Remove from pending queue
    final queueId = tx['id'] as String;
    await ref.read(smsQueueProvider.notifier).dismissPendingTx(db, queueId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Logged KSh ${amount.toStringAsFixed(2)} as $selectedCategory',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _dismissTransaction(String queueId) async {
    final db = ref.read(hiveServiceProvider);
    await ref.read(smsQueueProvider.notifier).dismissPendingTx(db, queueId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction skipped and removed from queue.'),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingQueue = ref.watch(smsQueueProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? const Color(0xFF131314) : const Color(0xFFFCF8FA);
    final cardBg = isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2E3A52) : const Color(0xFFE2E8F0);
    final textPrimary =
        isDark ? const Color(0xFFE5E2E3) : const Color(0xFF1B1B1D);
    final textSecondary =
        isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B);
    final primaryAccent =
        isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: cardBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'M-Pesa Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (pendingQueue.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${pendingQueue.length} Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryAccent,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Paste SMS Text',
            icon: Icon(Icons.paste_rounded, color: textSecondary),
            onPressed: _showManualPasteDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: pendingQueue.isEmpty
            ? _buildEmptyQueueView(
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryAccent: primaryAccent,
              )
            : _buildActiveQueueView(
                pendingQueue: pendingQueue,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryAccent: primaryAccent,
              ),
      ),
    );
  }

  void _showManualPasteDialog() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.paste_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Paste M-Pesa SMS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste any raw Safaricom M-Pesa confirmation SMS to test or manually add:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'e.g. QA45TY7890 Confirmed. Ksh1,200.00 sent to JANE DOE on 29/8/26...',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF131314)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final parsed = SmsParser.parseMpesaSms(text);
                  if (parsed != null) {
                    final db = ref.read(hiveServiceProvider);
                    await ref
                        .read(smsQueueProvider.notifier)
                        .addPendingTx(db, parsed);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Transaction successfully parsed and added to queue!'),
                          backgroundColor: Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Could not recognize text as a valid M-Pesa confirmation.'),
                          backgroundColor: Color(0xFFE11D48),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Parse & Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyQueueView({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryAccent,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF003824)
                    : const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 54,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All Caught Up!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have zero unlogged M-Pesa transactions waiting in your local vault queue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: const BorderSide(color: Color(0xFF94A3B8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.paste_rounded, size: 16),
              label: const Text(
                'Paste M-Pesa SMS',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _showManualPasteDialog,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text(
                'Return to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveQueueView({
    required List<Map<String, dynamic>> pendingQueue,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryAccent,
  }) {
    final currentTx = pendingQueue.first;
    final amount = (currentTx['amount'] as num?)?.toDouble() ?? 0.0;
    final isIncome = currentTx['isIncome'] as bool? ?? false;
    final description =
        currentTx['description'] as String? ?? 'M-Pesa Transaction';
    final date = currentTx['date'] as String? ?? '';
    final refCode = currentTx['referenceCode'] as String? ?? '';
    final rawMsg = currentTx['rawMessage'] as String? ?? '';
    final txId = currentTx['id'] as String;

    final categories = isIncome ? _incomeCategories : _expenseCategories;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Queue progress header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PENDING REVIEW (1 OF ${pendingQueue.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: primaryAccent,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Interactive Card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Container(
              key: ValueKey(txId),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Direction Pill & Ref Code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isIncome
                              ? (isDark
                                  ? const Color(0xFF003824)
                                  : const Color(0xFFECFDF5))
                              : (isDark
                                  ? const Color(0xFF3A000B)
                                  : const Color(0xFFFFF1F2)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isIncome
                                ? const Color(0xFF059669).withValues(alpha: 0.3)
                                : const Color(0xFFE11D48).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 14,
                              color: isIncome
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFE11D48),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isIncome ? 'INFLOW / RECEIVED' : 'OUTLAY / PAID',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: isIncome
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (refCode.isNotEmpty)
                        Text(
                          'Ref: $refCode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Display
                  Text(
                    'KSh ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: isIncome
                          ? const Color(0xFF059669)
                          : (isDark
                              ? const Color(0xFFF43F5E)
                              : const Color(0xFFE11D48)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Party / Recipient / Sender Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131314)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3A52)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIncome
                              ? Icons.person_outline_rounded
                              : Icons.storefront_rounded,
                          size: 18,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Raw message collapsible preview
                  if (rawMsg.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text(
                          'View Raw M-Pesa SMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF131314)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rawMsg,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                height: 1.4,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Prompt: Select category to commit
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 16, color: primaryAccent),
                      const SizedBox(width: 6),
                      Text(
                        'TAP CATEGORY TO LOG INSTANTLY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Action Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final icon = _getCategoryIcon(cat);
                      return ActionChip(
                        avatar: Icon(icon, size: 16, color: primaryAccent),
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF131314)
                            : const Color(0xFFF8FAFC),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF2E3A52)
                              : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onPressed: () => _approveAndLogTransaction(
                          tx: currentTx,
                          selectedCategory: cat,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Footer actions: Skip / Dismiss
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFE11D48)),
                        label: const Text(
                          'Skip / Discard',
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _dismissTransaction(txId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
