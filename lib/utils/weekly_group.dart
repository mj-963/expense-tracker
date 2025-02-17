import 'package:expense_tracker/models/transaction.dart';

/// A helper class to store each week's data
class WeeklyGroup {
  final DateTime startDate; // e.g. Monday of that week
  final DateTime endDate; // startDate + 6 days
  final double totalExpense;
  final double totalIncome;
  final double net; // income - expense
  final List<TransactionModel> transactions;

  WeeklyGroup({
    required this.startDate,
    required this.endDate,
    required this.totalExpense,
    required this.totalIncome,
    required this.net,
    required this.transactions,
  });
}
