import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/transactions/domain/transaction_repository.dart';
import 'package:finance_app/features/transactions/data/transaction_repository_impl.dart';
import 'package:finance_app/features/transactions/presentation/transaction_providers.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

// Хелпер для создания тестовых транзакций
Transaction makeTransaction(String id) {
  return Transaction(
    id: id,
    accountId: 'acc1',
    type: TransactionType.expense,
    amount: 100.0,
    date: DateTime(2026, 1, 15),
  );
}

List<Transaction> makeTransactions(int count, {int startIndex = 0}) {
  return List.generate(
    count,
    (i) => makeTransaction('tx_${startIndex + i}'),
  );
}

void main() {
  late MockTransactionRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockTransactionRepository();
    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('TransactionListNotifier.build', () {
    test('вызывает getTransactions с limit=30 и offset=0 при инициализации',
        () async {
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => makeTransactions(10));

      await container.read(transactionListNotifierProvider.future);

      verify(
        () => mockRepo.getTransactions(limit: 30, offset: 0),
      ).called(1);
    });

    test('state содержит загруженные транзакции после build', () async {
      final expected = makeTransactions(5);
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => expected);

      final result =
          await container.read(transactionListNotifierProvider.future);

      expect(result, equals(expected));
    });
  });

  group('TransactionListNotifier.loadMore', () {
    test('список расширяется (append, не replace) после loadMore', () async {
      final firstPage = makeTransactions(30);
      final secondPage = makeTransactions(10, startIndex: 30);

      var callCount = 0;
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? firstPage : secondPage;
      });

      await container.read(transactionListNotifierProvider.future);

      final notifier =
          container.read(transactionListNotifierProvider.notifier);
      await notifier.loadMore();

      final state =
          container.read(transactionListNotifierProvider).valueOrNull;
      expect(state, isNotNull);
      expect(state!.length, equals(40));
      // Первый элемент из первой страницы на месте
      expect(state.first.id, equals(firstPage.first.id));
      // Последний элемент из второй страницы в конце
      expect(state.last.id, equals(secondPage.last.id));
    });

    test(
        'loadMore НЕ вызывает репозиторий если первая страница вернула < 30 элементов',
        () async {
      // Первая загрузка вернула 10 < 30, значит hasMore = false
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => makeTransactions(10));

      await container.read(transactionListNotifierProvider.future);

      final notifier =
          container.read(transactionListNotifierProvider.notifier);
      await notifier.loadMore();

      // Репозиторий должен быть вызван ровно один раз (только при build)
      verify(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    });

    test(
        'loadMore НЕ выставляет AsyncValue.loading() — state.valueOrNull остаётся не null',
        () async {
      final firstPage = makeTransactions(30);
      final secondPage = makeTransactions(5, startIndex: 30);

      // Контролируем момент когда второй вызов начинается
      var resolveSecond = Completer<List<Transaction>>();

      var callCount = 0;
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return firstPage;
        return resolveSecond.future;
      });

      await container.read(transactionListNotifierProvider.future);

      final notifier =
          container.read(transactionListNotifierProvider.notifier);

      // Запускаем loadMore не дожидаясь завершения
      final loadMoreFuture = notifier.loadMore();

      // Пока второй запрос не завершён — state.valueOrNull не должен быть null
      final stateWhileLoading =
          container.read(transactionListNotifierProvider).valueOrNull;
      expect(
        stateWhileLoading,
        isNotNull,
        reason:
            'loadMore не должен заменять state на AsyncLoading — список должен оставаться видимым',
      );

      // Разрешаем второй запрос
      resolveSecond.complete(secondPage);
      await loadMoreFuture;
    });
  });

  group('TransactionListNotifier.refresh', () {
    test('refresh сбрасывает offset и загружает данные заново', () async {
      final firstPage = makeTransactions(30);
      final refreshedPage = makeTransactions(15);

      var callCount = 0;
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? firstPage : refreshedPage;
      });

      // Первоначальная загрузка
      await container.read(transactionListNotifierProvider.future);

      final notifier =
          container.read(transactionListNotifierProvider.notifier);

      await notifier.refresh();

      final state =
          container.read(transactionListNotifierProvider).valueOrNull;
      expect(state, isNotNull);
      // После refresh список должен содержать только обновлённые данные
      expect(state!.length, equals(refreshedPage.length));
      expect(state.first.id, equals(refreshedPage.first.id));
    });

    test('refresh вызывает getTransactions с offset=0', () async {
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => makeTransactions(5));

      await container.read(transactionListNotifierProvider.future);

      final notifier =
          container.read(transactionListNotifierProvider.notifier);
      await notifier.refresh();

      // Оба вызова (build + refresh) должны использовать offset=0
      verify(
        () => mockRepo.getTransactions(limit: 30, offset: 0),
      ).called(2);
    });

    test('после refresh hasMore обновляется корректно', () async {
      // Первая загрузка: полная страница — hasMore = true
      var callCount = 0;
      when(
        () => mockRepo.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        // Первый вызов (build): 30 элементов
        // Второй вызов (refresh): 5 элементов
        return callCount == 1 ? makeTransactions(30) : makeTransactions(5);
      });

      await container.read(transactionListNotifierProvider.future);
      final notifier =
          container.read(transactionListNotifierProvider.notifier);
      expect(notifier.hasMore, isTrue);

      await notifier.refresh();
      expect(notifier.hasMore, isFalse);
    });
  });
}

