import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:finance_app/features/accounts/presentation/account_providers.dart';
import 'package:finance_app/features/accounts/domain/account.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/categories/data/category_repository_impl.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/features/categories/domain/category_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCategoryRepository extends Mock implements CategoryRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Account makeAccount({String id = 'a1', String name = 'Карта'}) => Account(
      id: id,
      userId: 'u1',
      name: name,
    );

Transaction makeTransaction() => Transaction(
      id: 'tx1',
      accountId: 'a1',
      type: TransactionType.expense,
      amount: 500.0,
      date: DateTime(2026, 4, 1),
      note: 'Тест',
    );

Widget _buildApp({Transaction? transaction, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: AddTransactionScreen(transaction: transaction),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockCategoryRepository mockCategoryRepo;

  setUpAll(() async {
    await initializeDateFormatting('ru', null);
    await initializeDateFormatting('ru_RU', null);
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockCategoryRepo = MockCategoryRepository();

    when(() => mockCategoryRepo.getCategories(isIncome: any(named: 'isIncome')))
        .thenAnswer((_) async => <Category>[]);
  });

  group('AddTransactionScreen — создание', () {
    testWidgets('кнопка Сохранить заблокирована если нет суммы и счёта',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value([makeAccount()])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('заголовок AppBar — "Добавить операцию"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value([])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Добавить операцию'), findsOneWidget);
    });

    testWidgets('SegmentedButton содержит 3 сегмента (Доход/Расход/Перевод)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value([])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(SegmentedButton<TransactionType>), findsOneWidget);
      expect(find.text('Доход'), findsOneWidget);
      expect(find.text('Расход'), findsOneWidget);
      expect(find.text('Перевод'), findsOneWidget);
    });
  });

  group('AddTransactionScreen — режим редактирования', () {
    testWidgets('заголовок AppBar — "Редактировать операцию"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tx = makeTransaction();
      await tester.pumpWidget(
        _buildApp(
          transaction: tx,
          overrides: [
            accountsProvider
                .overrideWith((ref) => Future.value([makeAccount()])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Редактировать операцию'), findsOneWidget);
    });

    testWidgets('поле суммы предзаполнено', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tx = makeTransaction(); // amount = 500.0
      await tester.pumpWidget(
        _buildApp(
          transaction: tx,
          overrides: [
            accountsProvider
                .overrideWith((ref) => Future.value([makeAccount()])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('500.0'), findsOneWidget);
    });

    testWidgets('поле заметки предзаполнено', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tx = makeTransaction(); // note = 'Тест'
      await tester.pumpWidget(
        _buildApp(
          transaction: tx,
          overrides: [
            accountsProvider
                .overrideWith((ref) => Future.value([makeAccount()])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Тест'), findsOneWidget);
    });

    testWidgets('SegmentedButton заблокирован при редактировании', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tx = makeTransaction();
      await tester.pumpWidget(
        _buildApp(
          transaction: tx,
          overrides: [
            accountsProvider
                .overrideWith((ref) => Future.value([makeAccount()])),
            categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
          ],
        ),
      );
      await tester.pump();

      // При редактировании onSelectionChanged == null (передан null в экране)
      final segmented = tester
          .widget<SegmentedButton<TransactionType>>(
              find.byType(SegmentedButton<TransactionType>));
      expect(segmented.onSelectionChanged, isNull);
    });
  });
}
