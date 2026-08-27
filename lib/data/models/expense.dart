import 'package:flutter/foundation.dart';

@immutable
class Expense {
  final String id;
  final String date;
  final double amount;
  final String category;
  final String description;
  final bool isIncome;

  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
    this.isIncome = false,
  });

  Expense copyWith({
    String? id,
    String? date,
    double? amount,
    String? category,
    String? description,
    bool? isIncome,
  }) {
    return Expense(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      isIncome: isIncome ?? this.isIncome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'category': category,
      'description': description,
      'isIncome': isIncome,
    };
  }

  factory Expense.fromMap(Map<dynamic, dynamic> map) {
    return Expense(
      id: map['id'] as String? ?? '',
      date: map['date'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'General',
      description: map['description'] as String? ?? '',
      isIncome: map['isIncome'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          amount == other.amount &&
          category == other.category &&
          description == other.description &&
          isIncome == other.isIncome;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      amount.hashCode ^
      category.hashCode ^
      description.hashCode ^
      isIncome.hashCode;

  @override
  String toString() {
    return 'Expense(id: $id, date: $date, amount: $amount, category: $category, description: $description, isIncome: $isIncome)';
  }
}
