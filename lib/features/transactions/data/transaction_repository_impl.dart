import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

part 'transaction_repository_impl.g.dart';

@riverpod
TransactionRepository transactionRepository(TransactionRepositoryRef ref) {
  return SupabaseTransactionRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
  );
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client, this._db);
  final SupabaseClient _client;
  final AppDatabase _db;

  static const _table = 'transactions';

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? from, DateTime? to, String? accountId,
    String? categoryId, TransactionType? type,
    int limit = 50, int offset = 0,
  }) async {
    try {
      var query = _client.from(_table).select(
        '*, categories(id, name, icon, color), accounts(id, name, color)',
      );
      if (from != null)       query = query.gte('date', from.toIso8601String());
      if (to != null)         query = query.lt('date', to.toIso8601String());
      if (accountId != null)  query = query.eq('account_id', accountId);
      if (categoryId != null) query = query.eq('category_id', categoryId);
      if (type != null)       query = query.eq('type', type.name);
      final data = await query
          .order('date', ascending: false)
          .range(offset, offset + limit - 1);
      final transactions = data.map((e) => Transaction.fromJson(e)).toList();
      await _db.upsertTransactions(transactions.map(_toCompanion).toList());
      return transactions;
    } catch (_) {
      final rows = await _db.getCachedTransactions(
        from: from, to: to,
        accountId: accountId,
        categoryId: categoryId,
        type: type?.name,
        limit: limit,
        offset: offset,
      );
      return rows.map(_fromRow).toList();
    }
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
      ..remove('categories')
      ..remove('accounts');
    final data = await _client.from(_table).insert(json).select().single();
    final created = Transaction.fromJson(data);
    await _db.upsertTransactions([_toCompanion(created)]);
    return created;
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final json = transaction.toJson()
      ..remove('id')
      ..remove('account_id')
      ..remove('user_id')
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
    final updated = Transaction.fromJson(data);
    await _db.upsertTransactions([_toCompanion(updated)]);
    return updated;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _client.from(_table).delete().eq('id', id);
    await (_db.delete(_db.transactionsTable)
      ..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<Transaction>> watchTransactions({DateTime? from, DateTime? to}) {
    return _client.from(_table).stream(primaryKey: ['id']).map(
      (data) => data.map((e) => Transaction.fromJson(e)).toList(),
    );
  }

  // ── Helpers ───────────────────────────────

  TransactionsTableCompanion _toCompanion(Transaction t) {
    final cat = t.categories;
    final acc = t.accounts;
    return TransactionsTableCompanion(
      id:            Value(t.id),
      accountId:     Value(t.accountId),
      categoryId:    Value(t.categoryId),
      type:          Value(t.type.name),
      amount:        Value(t.amount),
      note:          Value(t.note),
      date:          Value(t.date),
      createdAt:     Value(t.createdAt),
      categoryName:  Value(cat?['name'] as String?),
      categoryIcon:  Value(cat?['icon'] as String?),
      categoryColor: Value(cat?['color'] as String?),
      accountName:   Value(acc?['name'] as String?),
    );
  }

  Transaction _fromRow(TransactionsTableData r) {
    return Transaction(
      id:         r.id,
      accountId:  r.accountId,
      categoryId: r.categoryId,
      type:       TransactionType.values.byName(r.type),
      amount:     r.amount,
      note:       r.note,
      date:       r.date,
      createdAt:  r.createdAt,
      categories: r.categoryName != null
          ? {'name': r.categoryName, 'icon': r.categoryIcon, 'color': r.categoryColor}
          : null,
      accounts: r.accountName != null
          ? {'name': r.accountName}
          : null,
    );
  }
}
