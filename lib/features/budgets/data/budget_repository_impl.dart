import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

part 'budget_repository_impl.g.dart';

@riverpod
BudgetRepository budgetRepository(BudgetRepositoryRef ref) {
  return SupabaseBudgetRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
  );
}

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client, this._db);
  final SupabaseClient _client;
  final AppDatabase _db;

  static const _table = 'budgets';

  @override
  Future<List<Budget>> getBudgets({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from(_table)
          .select('*, categories(id, name, icon, color)')
          .lte('start_date', to.toIso8601String())
          .or('end_date.is.null,end_date.gte.${from.toIso8601String()}')
          .order('created_at', ascending: false);
      final budgets = data.map((e) => Budget.fromJson(e)).toList();
      await _db.upsertBudgets(budgets.map(_toCompanion).toList());
      return budgets;
    } catch (_) {
      final rows = await _db.getCachedBudgets();
      return rows.map(_fromRow).toList();
    }
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
    final created = Budget.fromJson(data);
    await _db.upsertBudgets([_toCompanion(created)]);
    return created;
  }

  @override
  Future<Budget> updateBudget(Budget budget) async {
    final json = budget.toJson()
      ..remove('spent')
      ..remove('categories')
      ..remove('user_id')
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', budget.id)
        .select()
        .single();
    final updated = Budget.fromJson(data);
    await _db.upsertBudgets([_toCompanion(updated)]);
    return updated;
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _client.from(_table).delete().eq('id', id);
    await (_db.delete(_db.budgetsTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<Budget>> watchBudgets({
    required DateTime from,
    required DateTime to,
  }) {
    return _client.from(_table).stream(primaryKey: ['id']).map(
      (data) => data.map((e) => Budget.fromJson(e)).toList(),
    );
  }

  BudgetsTableCompanion _toCompanion(Budget b) {
    final cat = b.categories;
    return BudgetsTableCompanion(
      id:            Value(b.id),
      userId:        Value(b.userId),
      categoryId:    Value(b.categoryId),
      name:          Value(b.name),
      amount:        Value(b.amount),
      currency:      Value(b.currency),
      period:        Value(b.period),
      startDate:     Value(b.startDate),
      endDate:       Value(b.endDate),
      isRecurring:   Value(b.isRecurring),
      color:         Value(b.color),
      createdAt:     Value(b.createdAt),
      categoryName:  Value(cat?['name'] as String?),
      categoryIcon:  Value(cat?['icon'] as String?),
      categoryColor: Value(cat?['color'] as String?),
    );
  }

  Budget _fromRow(BudgetsTableData r) => Budget(
    id:          r.id,
    userId:      r.userId,
    categoryId:  r.categoryId,
    name:        r.name,
    amount:      r.amount,
    currency:    r.currency,
    period:      r.period,
    startDate:   r.startDate,
    endDate:     r.endDate,
    isRecurring: r.isRecurring,
    color:       r.color,
    createdAt:   r.createdAt,
    categories: r.categoryName != null
        ? {'name': r.categoryName, 'icon': r.categoryIcon, 'color': r.categoryColor}
        : null,
  );
}
