import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/providers.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

part 'category_repository_impl.g.dart';

@riverpod
CategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  return SupabaseCategoryRepository(ref.watch(supabaseClientProvider));
}

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'categories';

  @override
  Future<List<Category>> getCategories({bool? isIncome}) async {
    var query = _client.from(_table).select().eq('is_archived', false);
    if (isIncome != null) {
      query = query.eq('type', isIncome ? 'income' : 'expense');
    }
    final data = await query.order('sort_order').order('name');
    return data.map((e) => Category.fromJson(e)).toList();
  }

  @override
  Future<Category> createCategory(Category category) async {
    final json = category.toJson()
      ..remove('id')
      ..remove('is_system')    // клиент не управляет системными категориями
      ..remove('created_at')
      ..remove('updated_at');
    final data = await _client.from(_table).insert(json).select().single();
    return Category.fromJson(data);
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
    return Category.fromJson(data);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Stream<List<Category>> watchCategories() {
    return _client.from(_table).stream(primaryKey: ['id']).map(
      (data) => data.map((e) => Category.fromJson(e)).toList(),
    );
  }
}
