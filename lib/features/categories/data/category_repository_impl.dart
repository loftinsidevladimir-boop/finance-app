import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

part 'category_repository_impl.g.dart';

@riverpod
CategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  return SupabaseCategoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
  );
}

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._client, this._db);
  final SupabaseClient _client;
  final AppDatabase _db;

  static const _table = 'categories';

  @override
  Future<List<Category>> getCategories({bool? isIncome}) async {
    try {
      var query = _client.from(_table).select().eq('is_archived', false);
      if (isIncome != null) {
        query = query.eq('type', isIncome ? 'income' : 'expense');
      }
      final data = await query.order('sort_order').order('name');
      final categories = data.map((e) => Category.fromJson(e)).toList();
      await _db.upsertCategories(categories.map(_toCompanion).toList());
      return categories;
    } catch (_) {
      final rows = await _db.getCachedCategories();
      final filtered = rows.where((r) {
        if (r.isArchived) return false;
        if (isIncome == null) return true;
        return isIncome ? r.type == 'income' : r.type == 'expense';
      });
      return filtered.map(_fromRow).toList();
    }
  }

  @override
  Future<Category> createCategory(Category category) async {
    final json = category.toJson()
      ..remove('id')
      ..remove('is_system')
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client.from(_table).insert(json).select().single();
    final created = Category.fromJson(data);
    await _db.upsertCategories([_toCompanion(created)]);
    return created;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    final json = category.toJson()
      ..remove('is_system')
      ..remove('user_id')
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client
        .from(_table)
        .update(json)
        .eq('id', category.id)
        .select()
        .single();
    final updated = Category.fromJson(data);
    await _db.upsertCategories([_toCompanion(updated)]);
    return updated;
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _client.from(_table).delete().eq('id', id);
    await (_db.delete(_db.categoriesTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<Category>> watchCategories() {
    return _client.from(_table).stream(primaryKey: ['id']).map(
      (data) => data.map((e) => Category.fromJson(e)).toList(),
    );
  }

  CategoriesTableCompanion _toCompanion(Category c) => CategoriesTableCompanion(
    id:         Value(c.id),
    name:       Value(c.name),
    icon:       Value(c.icon),
    color:      Value(c.color),
    type:       Value(c.type),
    sortOrder:  Value(c.sortOrder),
    isSystem:   Value(c.isSystem),
    isArchived: Value(c.isArchived),
    userId:     Value(c.userId),
    createdAt:  Value(c.createdAt),
  );

  Category _fromRow(CategoriesTableData r) => Category(
    id:         r.id,
    name:       r.name,
    icon:       r.icon,
    color:      r.color,
    type:       r.type,
    sortOrder:  r.sortOrder,
    isSystem:   r.isSystem,
    isArchived: r.isArchived,
    userId:     r.userId,
    createdAt:  r.createdAt,
  );
}
