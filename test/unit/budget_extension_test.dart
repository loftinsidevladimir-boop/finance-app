import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/features/budgets/domain/budget.dart';

void main() {
  Budget makeBudget({double amount = 1000.0, double spent = 0.0}) {
    return Budget(
      id: 'b1',
      userId: 'u1',
      name: 'Тест бюджет',
      amount: amount,
      startDate: DateTime(2026, 1, 1),
      spent: spent,
    );
  }

  group('BudgetX.remaining', () {
    test('возвращает amount - spent', () {
      final budget = makeBudget(amount: 1000.0, spent: 300.0);
      expect(budget.remaining, closeTo(700.0, 0.001));
    });

    test('возвращает 0 когда spent == amount', () {
      final budget = makeBudget(amount: 500.0, spent: 500.0);
      expect(budget.remaining, closeTo(0.0, 0.001));
    });

    test('возвращает отрицательное значение когда spent > amount', () {
      final budget = makeBudget(amount: 500.0, spent: 700.0);
      expect(budget.remaining, closeTo(-200.0, 0.001));
    });
  });

  group('BudgetX.progress', () {
    test('возвращает spent/amount когда spent < amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 400.0);
      expect(budget.progress, closeTo(0.4, 0.001));
    });

    test('возвращает 1.0 когда spent == amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 1000.0);
      expect(budget.progress, closeTo(1.0, 0.001));
    });

    test('зажато до 1.0 когда spent > amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 1500.0);
      expect(budget.progress, closeTo(1.0, 0.001));
    });

    test('возвращает 0.0 когда amount == 0', () {
      final budget = makeBudget(amount: 0.0, spent: 0.0);
      expect(budget.progress, closeTo(0.0, 0.001));
    });

    test('возвращает 0.0 когда amount == 0 и spent > 0', () {
      final budget = makeBudget(amount: 0.0, spent: 100.0);
      expect(budget.progress, closeTo(0.0, 0.001));
    });
  });

  group('BudgetX.isExceeded', () {
    test('возвращает true когда spent > amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 1001.0);
      expect(budget.isExceeded, isTrue);
    });

    test('возвращает false когда spent == amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 1000.0);
      expect(budget.isExceeded, isFalse);
    });

    test('возвращает false когда spent < amount', () {
      final budget = makeBudget(amount: 1000.0, spent: 500.0);
      expect(budget.isExceeded, isFalse);
    });

    test('возвращает false когда spent == 0', () {
      final budget = makeBudget(amount: 1000.0, spent: 0.0);
      expect(budget.isExceeded, isFalse);
    });
  });
}
