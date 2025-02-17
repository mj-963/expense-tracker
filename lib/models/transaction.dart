import 'package:cloud_firestore/cloud_firestore.dart';

/// A transaction can be an expense, income, or transfer.
/// Fields: category, paymentMethod, date, recurrence, note, imageUrl, amount.
class TransactionModel {
  final String id;
  final String type; // 'expense', 'income', or 'transfer'
  final String category;
  final String paymentMethod;
  final DateTime date;
  final String recurrence; // e.g. 'None', 'Every Day', etc.
  final String note;
  final double amount;
  final String? imageUrl; // optional field for attached image

  TransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.paymentMethod,
    required this.date,
    required this.recurrence,
    required this.note,
    required this.amount,
    this.imageUrl,
  });

  /// Create a TransactionModel from a Firestore document.
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      recurrence: data['recurrence'] ?? 'None',
      note: data['note'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
    );
  }

  /// Convert to a Map for saving to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'category': category,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'recurrence': recurrence,
      'note': note,
      'amount': amount,
      'imageUrl': imageUrl,
    };
  }
}
