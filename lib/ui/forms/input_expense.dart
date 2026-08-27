import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';

class InputExpenseScreen extends ConsumerStatefulWidget {
  const InputExpenseScreen({super.key});

  @override
  ConsumerState<InputExpenseScreen> createState() => _InputExpenseScreenState();
}

class _InputExpenseScreenState extends ConsumerState<InputExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocusNode = FocusNode();

  bool _isIncome = false;

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

  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _onTypeChanged(bool isIncome) {
    if (_isIncome != isIncome) {
      setState(() {
        _isIncome = isIncome;
        _selectedCategory = isIncome ? _incomeCategories.first : _expenseCategories.first;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF00D2FF),
                    onPrimary: Color(0xFF131314),
                    surface: Color(0xFF1E222B),
                    onSurface: Color(0xFFE5E2E3),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF7C3AED),
                    onPrimary: Colors.white,
                    surface: Color(0xFFFFFFFF),
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
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

  /// Continuous Save Loop: Validates, commits to Hive, clears inputs, resets focus, and stays on page.
  Future<void> _handleContinuousSave() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final cleanAmountStr = _amountController.text.trim().replaceAll(',', '.');
      final amount = double.parse(cleanAmountStr);
      final description = _descriptionController.text.trim();
      final dateStr = _formatDate(_selectedDate);

      const uuid = Uuid();
      final newExpense = Expense(
        id: uuid.v4(),
        date: dateStr,
        amount: amount,
        category: _selectedCategory,
        description: description,
        isIncome: _isIncome,
      );

      final db = ref.read(hiveServiceProvider);
      await ref.read(expenseProvider.notifier).addExpense(db, newExpense);

      if (mounted) {
        // Trigger quick temporary confirmation snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved ${_isIncome ? "Income" : "Expense"} (KSh ${amount.toStringAsFixed(2)}) to Vault',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: _isIncome ? const Color(0xFF059669) : const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Immediately clear all text controllers and reset form
        _amountController.clear();
        _descriptionController.clear();
        _formKey.currentState?.reset();

        // Reset focus to the Amount field for the next entry
        _amountFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tokens derived from DESIGN.md
    final inputBg = isDark ? const Color(0xFF1B1B1D) : const Color(0xFFF8F9FA);
    final inputBorderColor = isDark ? const Color(0xFF45464C) : const Color(0xFFE2E8F0);
    final focusGlowColor = _isIncome
        ? (isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48));
    final activeColor = _isIncome
        ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48));
    final textPrimary = isDark ? const Color(0xFFE5E2E3) : const Color(0xFF1B1B1D);
    final textSecondary = isDark ? const Color(0xFFC6C6CC) : const Color(0xFF64748B);

    final categories = _isIncome ? _incomeCategories : _expenseCategories;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          _isIncome ? 'Log Income' : 'Log Expense',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Segmented Cashflow Selector (Expense vs Income)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: inputBorderColor),
                  ),
                  child: Row(
                    children: [
                      // Expense Choice
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onTypeChanged(false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isIncome
                                  ? (isDark ? const Color(0xFF3A000B) : const Color(0xFFFFF1F2))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isIncome
                                    ? (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48))
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: !_isIncome
                                      ? (isDark ? const Color(0xFFFFB2B7) : const Color(0xFFE11D48))
                                      : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Expense Outlay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: !_isIncome ? FontWeight.w700 : FontWeight.w500,
                                    color: !_isIncome
                                        ? (isDark ? const Color(0xFFFFB2B7) : const Color(0xFFE11D48))
                                        : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Income Choice
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onTypeChanged(true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isIncome
                                  ? (isDark ? const Color(0xFF003824) : const Color(0xFFECFDF5))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isIncome
                                    ? (isDark ? const Color(0xFF4EDEA3) : const Color(0xFF059669))
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: _isIncome
                                      ? (isDark ? const Color(0xFF6FFBBE) : const Color(0xFF059669))
                                      : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cashflow Inflow',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _isIncome ? FontWeight.w700 : FontWeight.w500,
                                    color: _isIncome
                                        ? (isDark ? const Color(0xFF6FFBBE) : const Color(0xFF059669))
                                        : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Amount Field (KSh)
                Text(
                  'AMOUNT (KSH)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.5),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'KSh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: activeColor,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: inputBorderColor, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: focusGlowColor, width: 1.8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an amount in KSh';
                    }
                    final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                    if (parsed == null) {
                      return 'Please enter a valid numeric value';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Description Field
                Text(
                  'DESCRIPTION / NOTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 15, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: _isIncome ? 'e.g. Monthly salary, Freelance client' : 'e.g. Naivas Supermarket, Shell Fuel',
                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                    prefixIcon: Icon(Icons.edit_note_rounded, color: textSecondary, size: 22),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: inputBorderColor, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: focusGlowColor, width: 1.8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a short description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Category Selection
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  dropdownColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
                  style: TextStyle(fontSize: 15, color: textPrimary, fontWeight: FontWeight.w500),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: inputBorderColor, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: focusGlowColor, width: 1.8),
                    ),
                  ),
                  items: categories.map((cat) {
                    final color = _getCategoryColor(cat, isDark);
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_getCategoryIcon(cat), size: 16, color: color),
                          ),
                          const SizedBox(width: 10),
                          Text(cat),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newCat) {
                    if (newCat != null) {
                      setState(() {
                        _selectedCategory = newCat;
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Date Picker Field
                Text(
                  'DATE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: inputBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 20, color: textSecondary),
                            const SizedBox(width: 12),
                            Text(
                              _formatDate(_selectedDate),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ONE prominent Save button centered at the bottom for continuous stream loop
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: _isIncome
                          ? (isDark
                              ? const [Color(0xFF10B981), Color(0xFF059669)]
                              : const [Color(0xFF059669), Color(0xFF047857)])
                          : (isDark
                              ? const [Color(0xFFF43F5E), Color(0xFFE11D48)]
                              : const [Color(0xFFE11D48), Color(0xFFBE123C)]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleContinuousSave,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Entry automatically logs to Vault. Tap Back (←) when finished.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
