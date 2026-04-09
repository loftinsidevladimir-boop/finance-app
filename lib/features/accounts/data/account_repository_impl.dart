import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

part 'account_repository_impl.g.dart';

@riverpod
AccountRepository accountRepository(AccountRepositoryRef ref) {
  return SupabaseAccountRepository(ref.watch(supabaseClientProvider));
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'accounts';

  @override
  Future<List<Account>> getAccounts() async {
    final data = await _client
        .from(_table)
        .select()
        .eq('is_archived', false)
        .order('is_default', ascending: false);
    return data.map((e) => Account.fromJson(e)).toList();
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
    return Account.fromJson(data);
  }

  @override
  Future<Account> updateAccount(Account account) async {
    final json = account.toJson()
      ..remove('balance')      // баланс меняется только через транзакции
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('user_id');     // owner не должен передаваться клиентом
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', account.id)
        .select()
        .single();
    return Account.fromJson(data);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _client.from(_table).update({'is_archived': true}).eq('id', id);
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
}
