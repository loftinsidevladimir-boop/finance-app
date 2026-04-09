import 'category.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> getCategories({bool? isIncome});
  Future<Category> createCategory(Category category);
  Future<Category> updateCategory(Category category);
  Future<void> deleteCategory(String id);
  Stream<List<Category>> watchCategories();
}
