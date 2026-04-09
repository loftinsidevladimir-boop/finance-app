import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────
// Tables
// ─────────────────────────────────────────────

class AccountsTable extends Table {
  TextColumn get id         => text()();
  TextColumn get userId     => text()();
  TextColumn get name       => text()();
  TextColumn get type       => text().withDefault(const Constant('card'))();
  RealColumn get balance    => real().withDefault(const Constant(0.0))();
  TextColumn get currency   => text().withDefault(const Constant('RUB'))();
  TextColumn get color      => text().withDefault(const Constant('#4CAF50'))();
  TextColumn get icon       => text().withDefault(const Constant('account_balance_wallet'))();
  BoolColumn get isDefault  => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  TextColumn get id         => text()();
  TextColumn get name       => text()();
  TextColumn get icon       => text()();
  TextColumn get color      => text()();
  TextColumn get type       => text().withDefault(const Constant('expense'))();
  IntColumn  get sortOrder  => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem   => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get userId     => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionsTable extends Table {
  TextColumn get id           => text()();
  TextColumn get accountId    => text()();
  TextColumn get categoryId   => text().nullable()();
  TextColumn get type         => text()();
  RealColumn get amount       => real()();
  TextColumn get note         => text().nullable()();
  DateTimeColumn get date     => dateTime()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  // Denormalized join data
  TextColumn get categoryName  => text().nullable()();
  TextColumn get categoryIcon  => text().nullable()();
  TextColumn get categoryColor => text().nullable()();
  TextColumn get accountName   => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class BudgetsTable extends Table {
  TextColumn get id          => text()();
  TextColumn get userId      => text()();
  TextColumn get categoryId  => text().nullable()();
  TextColumn get name        => text()();
  RealColumn get amount      => real()();
  TextColumn get currency    => text().withDefault(const Constant('RUB'))();
  TextColumn get period      => text().withDefault(const Constant('monthly'))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate   => dateTime().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(true))();
  TextColumn get color       => text().withDefault(const Constant('#2196F3'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  TextColumn get categoryName  => text().nullable()();
  TextColumn get categoryIcon  => text().nullable()();
  TextColumn get categoryColor => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────
// Database
// ─────────────────────────────────────────────

@DriftDatabase(tables: [AccountsTable, CategoriesTable, TransactionsTable, BudgetsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'finance_app_cache');
  }

  // ── Accounts ──────────────────────────────

  Future<List<AccountsTableData>> getCachedAccounts() =>
      select(accountsTable).get();

  Future<void> upsertAccounts(List<AccountsTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(accountsTable, rows));

  // ── Categories ────────────────────────────

  Future<List<CategoriesTableData>> getCachedCategories() =>
      select(categoriesTable).get();

  Future<void> upsertCategories(List<CategoriesTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categoriesTable, rows));

  // ── Transactions ──────────────────────────

  Future<List<TransactionsTableData>> getCachedTransactions({
    DateTime? from,
    DateTime? to,
    String? accountId,
    String? categoryId,
    String? type,
    int limit = 50,
    int offset = 0,
  }) {
    final q = select(transactionsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(limit, offset: offset);

    q.where((t) {
      Expression<bool> expr = const Constant(true);
      if (from != null)       expr = expr & t.date.isBiggerOrEqualValue(from);
      if (to != null)         expr = expr & t.date.isSmallerOrEqualValue(to);
      if (accountId != null)  expr = expr & t.accountId.equals(accountId);
      if (categoryId != null) expr = expr & t.categoryId.equals(categoryId);
      if (type != null)       expr = expr & t.type.equals(type);
      return expr;
    });

    return q.get();
  }

  Future<void> upsertTransactions(List<TransactionsTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(transactionsTable, rows));

  // ── Budgets ───────────────────────────────

  Future<List<BudgetsTableData>> getCachedBudgets() =>
      select(budgetsTable).get();

  Future<void> upsertBudgets(List<BudgetsTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(budgetsTable, rows));
}
