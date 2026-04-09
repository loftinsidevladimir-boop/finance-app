import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

part 'budget_repository_impl.g.dart';

@riverpod
BudgetRepository budgetRepository(BudgetRepositoryRef ref) {
  return SupabaseBudgetRepository(ref.watch(supabaseClientProvider));
}

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'budgets';

  @override
  Future<List<Budget>> getBudgets({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client
        .from(_table)
        .select('*, categories(id, name, icon, color)')
        .lte('start_date', to.toIso8601String())
        .or('end_date.is.null,end_date.gte.${from.toIso8601String()}')
        .order('created_at', ascending: false);
    return data.map((e) => Budget.fromJson(e)).toList();
  }

  @override
  Future<Budget> createBudget(Budget budget) async {
    final json = budget.toJson()
      ..remove('id')
      ..remove('spent')
      ..remove('categories')
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client.from(_table).insert(json).select().single();
    return Budget.fromJson(data);
  }

  @override
  Future<Budget> updateBudget(Budget budget) async {
    final json = budget.toJson()
      ..remove('spent')
      ..remove('categories')
      ..remove('user_id')      // owner не должен передаваться клиентом
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', budget.id)
        .select()
        .single();
    return Budget.fromJson(data);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Stream<List<Budget>> watchBudgets({
    required DateTime from,
    required DateTime to,
  }) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .map((data) => data.map((e) => Budget.fromJson(e)).toList());
  }
}
