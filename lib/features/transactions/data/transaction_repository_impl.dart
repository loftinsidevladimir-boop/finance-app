import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

part 'transaction_repository_impl.g.dart';

@riverpod
TransactionRepository transactionRepository(TransactionRepositoryRef ref) {
  return SupabaseTransactionRepository(ref.watch(supabaseClientProvider));
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'transactions';

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? from, DateTime? to, String? accountId,
    String? categoryId, TransactionType? type,
    int limit = 50, int offset = 0,
  }) async {
    var query = _client.from(_table).select(
      '*, categories(id, name, icon, color), accounts(id, name, color)'
    );
    if (from != null)       query = query.gte('date', from.toIso8601String());
    if (to != null)         query = query.lte('date', to.toIso8601String());
    if (accountId != null)  query = query.eq('account_id', accountId);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (type != null)       query = query.eq('type', type.name);
    final data = await query
      .order('date', ascending: false)
      .range(offset, offset + limit - 1);
    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  @override
  Future<List<Transaction>> searchTransactions(String query) async {
    final data = await _client.from(_table).select()
      .textSearch('note', query)
      .order('date', ascending: false)
      .limit(50);
    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    final json = transaction.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('categories')   // join-данные, не столбцы таблицы
      ..remove('accounts');
    final data = await _client.from(_table).insert(json).select().single();
    return Transaction.fromJson(data);
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final json = transaction.toJson()
      ..remove('id')
      ..remove('account_id')   // смена счёта у транзакции запрещена триггером
      ..remove('user_id')      // owner не должен передаваться клиентом
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('categories')
      ..remove('accounts');
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', transaction.id)
        .select()
        .single();
    return Transaction.fromJson(data);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Stream<List<Transaction>> watchTransactions({DateTime? from, DateTime? to}) {
    return _client.from(_table).stream(primaryKey: ['id']).map(
      (data) => data.map((e) => Transaction.fromJson(e)).toList(),
    );
  }
}