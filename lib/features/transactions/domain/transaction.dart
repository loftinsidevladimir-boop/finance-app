import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType { income, expense, transfer }

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    @JsonKey(name: 'account_id') required String accountId,
    @JsonKey(name: 'category_id') String? categoryId,
    required TransactionType type,
    required double amount,
    String? note,
    required DateTime date,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // joined relations
    Map<String, dynamic>? categories,
    Map<String, dynamic>? accounts,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
