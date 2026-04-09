import 'package:flutter_test/flutter_test.dart';

// Алгоритм группировки расходов по категориям — pure Dart функция,
// извлечённая из budgets_screen.dart для изолированного тестирования.
Map<String, double> groupSpentByCategory(List<Map<String, dynamic>> txData) {
  final spentByCategory = <String, double>{};
  for (final tx in txData) {
    final catId = tx['category_id'] as String?;
    if (catId != null) {
      spentByCategory[catId] =
          (spentByCategory[catId] ?? 0.0) + (tx['amount'] as num).toDouble();
    }
  }
  return spentByCategory;
}

// Вспомогательная функция: применяет spent к бюджету (представлен как Map).
// Воспроизводит логику b.copyWith(spent: ...) из budgets_screen.dart.
Map<String, dynamic> applySpent(
  Map<String, dynamic> budget,
  Map<String, double> spentByCategory,
) {
  final catId = budget['category_id'] as String?;
  return {
    ...budget,
    'spent': catId != null ? (spentByCategory[catId] ?? 0.0) : 0.0,
  };
}

void main() {
  group('groupSpentByCategory', () {
    test('несколько транзакций одной категории суммируются', () {
      final txData = [
        {'category_id': 'cat1', 'amount': 300.0},
        {'category_id': 'cat1', 'amount': 200.0},
        {'category_id': 'cat1', 'amount': 100.0},
      ];

      final result = groupSpentByCategory(txData);

      expect(result['cat1'], closeTo(600.0, 0.001));
    });

    test('транзакции разных категорий не смешиваются', () {
      final txData = [
        {'category_id': 'cat1', 'amount': 500.0},
        {'category_id': 'cat2', 'amount': 250.0},
        {'category_id': 'cat3', 'amount': 750.0},
      ];

      final result = groupSpentByCategory(txData);

      expect(result['cat1'], closeTo(500.0, 0.001));
      expect(result['cat2'], closeTo(250.0, 0.001));
      expect(result['cat3'], closeTo(750.0, 0.001));
      expect(result.length, equals(3));
    });

    test('транзакции без category_id (null) пропускаются', () {
      final txData = [
        {'category_id': null, 'amount': 999.0},
        {'category_id': null, 'amount': 123.0},
        {'category_id': 'cat1', 'amount': 100.0},
      ];

      final result = groupSpentByCategory(txData);

      expect(result.containsKey(null), isFalse);
      expect(result.length, equals(1));
      expect(result['cat1'], closeTo(100.0, 0.001));
    });

    test('пустой список транзакций возвращает пустую карту', () {
      final result = groupSpentByCategory([]);

      expect(result, isEmpty);
    });

    test('суммы корректны при смешанных null и non-null category_id', () {
      final txData = [
        {'category_id': 'cat1', 'amount': 100.0},
        {'category_id': null, 'amount': 500.0},
        {'category_id': 'cat1', 'amount': 200.0},
        {'category_id': null, 'amount': 300.0},
      ];

      final result = groupSpentByCategory(txData);

      expect(result['cat1'], closeTo(300.0, 0.001));
      expect(result.length, equals(1));
    });

    test('amount как int корректно конвертируется в double', () {
      final txData = [
        {'category_id': 'cat1', 'amount': 100},
        {'category_id': 'cat1', 'amount': 50},
      ];

      final result = groupSpentByCategory(txData);

      expect(result['cat1'], closeTo(150.0, 0.001));
    });
  });

  group('applySpent — проставление spent в бюджет', () {
    test('бюджет без categoryId получает spent = 0', () {
      final budget = <String, dynamic>{
        'id': 'b1',
        'category_id': null,
        'amount': 1000.0,
      };
      final spentByCategory = {'cat1': 500.0};

      final result = applySpent(budget, spentByCategory);

      expect(result['spent'], closeTo(0.0, 0.001));
    });

    test('бюджет с categoryId получает правильный spent', () {
      final budget = <String, dynamic>{
        'id': 'b1',
        'category_id': 'cat1',
        'amount': 1000.0,
      };
      final spentByCategory = {'cat1': 350.0, 'cat2': 200.0};

      final result = applySpent(budget, spentByCategory);

      expect(result['spent'], closeTo(350.0, 0.001));
    });

    test('бюджет с categoryId которой нет в spentByCategory получает spent = 0', () {
      final budget = <String, dynamic>{
        'id': 'b1',
        'category_id': 'cat_unknown',
        'amount': 1000.0,
      };
      final spentByCategory = {'cat1': 500.0};

      final result = applySpent(budget, spentByCategory);

      expect(result['spent'], closeTo(0.0, 0.001));
    });

    test('пустой список транзакций: все бюджеты получают spent = 0', () {
      final budgets = [
        {'id': 'b1', 'category_id': 'cat1', 'amount': 500.0},
        {'id': 'b2', 'category_id': 'cat2', 'amount': 1000.0},
        {'id': 'b3', 'category_id': null, 'amount': 300.0},
      ];
      final spentByCategory = groupSpentByCategory([]);

      final results = budgets
          .map((b) => applySpent(b, spentByCategory))
          .toList();

      for (final result in results) {
        expect(result['spent'], closeTo(0.0, 0.001));
      }
    });
  });
}
