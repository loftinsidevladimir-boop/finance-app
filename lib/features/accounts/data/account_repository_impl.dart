import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

part 'account_repository_impl.g.dart';

@riverpod
AccountRepository accountRepository(AccountRepositoryRef ref) {
  return SupabaseAccountRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
  );
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client, this._db);
  final SupabaseClient _client;
  final AppDatabase _db;

  static const _table = 'accounts';

  @override
  Future<List<Account>> getAccounts() async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('is_archived', false)
          .order('is_default', ascending: false);
      final accounts = data.map((e) => Account.fromJson(e)).toList();
      await _db.upsertAccounts(accounts.map(_toCompanion).toList());
      return accounts;
    } catch (_) {
      final rows = await _db.getCachedAccounts();
      return rows.where((r) => !r.isArchived).map(_fromRow).toList();
    }
  }

  @override
  Future<Account> getAccount(String id) async {
    final data = await _client.from(_table).select().eq('id', id).single();
    return Account.fromJson(data);
  }

  @override
  Future<Account> createAccount(Account account) async {
    final json = account.toJson()
      ..remove('id')
      ..remove('balance')
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client.from(_table).insert(json).select().single();
    final created = Account.fromJson(data);
    await _db.upsertAccounts([_toCompanion(created)]);
    return created;
  }

  @override
  Future<Account> updateAccount(Account account) async {
    final json = account.toJson()
      ..remove('balance')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('user_id');
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', account.id)
        .select()
        .single();
    final updated = Account.fromJson(data);
    await _db.upsertAccounts([_toCompanion(updated)]);
    return updated;
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _client.from(_table).update({'is_archived': true}).eq('id', id);
    await (_db.delete(_db.accountsTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<Account>> watchAccounts() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('is_archived', false)
        .order('is_default', ascending: false)
        .map((data) => data.map((e) => Account.fromJson(e)).toList());
  }

  AccountsTableCompanion _toCompanion(Account a) => AccountsTableCompanion(
    id:         Value(a.id),
    userId:     Value(a.userId),
    name:       Value(a.name),
    type:       Value(a.type),
    balance:    Value(a.balance),
    currency:   Value(a.currency),
    color:      Value(a.color),
    icon:       Value(a.icon),
    isDefault:  Value(a.isDefault),
    isArchived: Value(a.isArchived),
    createdAt:  Value(a.createdAt),
  );

  Account _fromRow(AccountsTableData r) => Account(
    id:         r.id,
    userId:     r.userId,
    name:       r.name,
    type:       r.type,
    balance:    r.balance,
    currency:   r.currency,
    color:      r.color,
    icon:       r.icon,
    isDefault:  r.isDefault,
    isArchived: r.isArchived,
    createdAt:  r.createdAt,
  );
}
