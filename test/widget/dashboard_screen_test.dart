import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:finance_app/features/accounts/presentation/account_providers.dart';
import 'package:finance_app/features/transactions/presentation/transaction_providers.dart';
import 'package:finance_app/core/di/providers.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _makeRouter({Widget home = const DashboardScreen()}) {
  return GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => home),
    GoRoute(path: '/transactions/add', builder: (_, __) => const Scaffold()),
  ]);
}

Transaction _makeTransaction({
  String id = 'tx1',
  TransactionType type = TransactionType.expense,
  double amount = 500.0,
}) =>
    Transaction(
      id: id,
      accountId: 'a1',
      type: type,
      amount: amount,
      date: DateTime(2026, 4, 1),
      categories: const {
        'name': 'Продукты',
        'icon': 'shopping_cart',
        'color': '#4CAF50',
      },
      accounts: const {'name': 'Карта'},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DashboardScreen', () {
    setUpAll(() async {
      await initializeDateFormatting('ru', null);
      await initializeDateFormatting('ru_RU', null);
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('показывает skeleton при загрузке баланса', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider
                .overrideWith((ref) => Future.delayed(const Duration(hours: 1))),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pump();

      // _BalanceCardSkeleton содержит два Container'а, проверяем через Card
      // Скелетон рендерит Card с двумя прямоугольными контейнерами, без текста баланса
      expect(find.text('Общий баланс'), findsNothing);
    });

    testWidgets('показывает баланс после загрузки', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider.overrideWith((ref) => Future.value(12345.0)),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Общий баланс'), findsOneWidget);
      // NumberFormat.currency отформатирует 12345.0 как '12 345,00 ₽'
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('показывает ошибку если totalBalance завершился ошибкой',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider
                .overrideWith((ref) => Future.error('network error')),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pumpAndSettle();

      // compact=true показывает текст ошибки и кнопку «Повторить»
      expect(find.text('Повторить'), findsWidgets);
    });

    testWidgets('показывает "Нет операций" если список пуст', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider.overrideWith((ref) => Future.value(0.0)),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Нет операций'), findsOneWidget);
    });

    testWidgets('показывает транзакции если список не пуст', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final transactions = [_makeTransaction()];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider.overrideWith((ref) => Future.value(1000.0)),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value(transactions)),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Нет операций'), findsNothing);
      // Имя категории отображается в _TransactionCard
      expect(find.text('Продукты'), findsOneWidget);
    });

    testWidgets('FAB присутствует на экране', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            totalBalanceProvider.overrideWith((ref) => Future.value(0.0)),
            monthlyTransactionsProvider(
              year: now.year,
              month: now.month,
              limit: 5,
            ).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp.router(routerConfig: _makeRouter()),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
