import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_app/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:finance_app/features/budgets/domain/budget.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Budget makeBudget({
  String id = 'b1',
  String name = 'Тест',
  double amount = 1000,
  double spent = 0,
  String? categoryId,
}) =>
    Budget(
      id: id,
      userId: 'u1',
      name: name,
      amount: amount,
      spent: spent,
      startDate: DateTime(2026, 1, 1),
      categoryId: categoryId,
      categories: categoryId != null
          ? {
              'name': 'Продукты',
              'icon': 'shopping_cart',
              'color': '#4CAF50',
            }
          : null,
    );

GoRouter _makeRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const BudgetsScreen()),
      GoRoute(path: '/budgets/add', builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/budgets/edit/:id', builder: (_, __) => const Scaffold()),
    ],
  );
}

Widget _buildApp(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: _makeRouter()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BudgetsScreen', () {
    setUpAll(() async {
      await initializeDateFormatting('ru', null);
      await initializeDateFormatting('ru_RU', null);
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('показывает skeleton при загрузке', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Используем Completer, чтобы Future никогда не завершился в рамках теста
      final completer = Completer<List<Budget>>();
      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => completer.future),
        ]),
      );
      // Один кадр — провайдер ещё в loading
      await tester.pump();

      // В состоянии loading отображается _BudgetsListSkeleton
      // Skeleton содержит Card'ы, но не содержит текста ни "Нет бюджетов", ни "Ошибка"
      expect(find.text('Нет бюджетов'), findsNothing);
      expect(find.text('Ошибка загрузки'), findsNothing);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('показывает "Нет бюджетов" если список пуст', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => Future.value([])),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Нет бюджетов'), findsOneWidget);
    });

    testWidgets('показывает бюджет с названием категории', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = makeBudget(categoryId: 'cat1', spent: 200);

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => Future.value([budget])),
        ]),
      );
      await tester.pumpAndSettle();

      // Категория отображается как categoryName из categories['name']
      expect(find.text('Продукты'), findsOneWidget);
    });

    testWidgets('показывает метку "Превышено" если spent > amount',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final exceeded = makeBudget(
        categoryId: 'cat1',
        amount: 500,
        spent: 1200,
      );

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => Future.value([exceeded])),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Превышено'), findsOneWidget);
    });

    testWidgets('не показывает "Превышено" если spent < amount', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final normal = makeBudget(
        categoryId: 'cat1',
        amount: 1000,
        spent: 300,
      );

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => Future.value([normal])),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Превышено'), findsNothing);
    });

    testWidgets('FAB присутствует', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider.overrideWith((ref) => Future.value([])),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('показывает ошибку если провайдер вернул error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp([
          budgetsProvider
              .overrideWith((ref) => Future.error('db connection failed')),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
    });
  });
}
