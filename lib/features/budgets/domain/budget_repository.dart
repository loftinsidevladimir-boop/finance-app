import 'budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> getBudgets({required DateTime from, required DateTime to});
  Future<Budget> createBudget(Budget budget);
  Future<Budget> updateBudget(Budget budget);
  Future<void> deleteBudget(String id);
  Stream<List<Budget>> watchBudgets({required DateTime from, required DateTime to});
}
