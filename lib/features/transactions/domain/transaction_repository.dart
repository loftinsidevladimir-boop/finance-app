import 'transaction.dart';

abstract interface class TransactionRepository {
  Future<List<Transaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? accountId,
    String? categoryId,
    TransactionType? type,
    int limit,
    int offset,
  });

  Future<List<Transaction>> searchTransactions(String query);

  Future<Transaction> createTransaction(Transaction transaction);

  Future<Transaction> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String id);

  Stream<List<Transaction>> watchTransactions({DateTime? from, DateTime? to});
}
