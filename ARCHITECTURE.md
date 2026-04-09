# Архитектура FinanceApp

## Общий принцип

Clean Architecture + Feature-first организация. Каждая фича — изолированный модуль с тремя слоями.

```
feature/
├── domain/     # Entity, Repository (abstract interface)
├── data/       # RepositoryImpl (Supabase), @riverpod провайдер
└── presentation/
    ├── screens/         # ConsumerWidget / ConsumerStatefulWidget
    └── *_providers.dart # @riverpod провайдеры и нотифайеры
```

## Структура `lib/`

```
lib/
├── core/
│   ├── di/providers.dart           # supabaseClientProvider, authStateProvider,
│   │                               # currentUserProvider, themeModeProvider
│   ├── router/
│   │   ├── app_router.dart         # GoRouter + Routes (все маршруты)
│   │   └── app_shell.dart          # BottomNavigationBar (5 вкладок)
│   ├── storage/secure_local_storage.dart  # Supabase токены → Keychain/Keystore
│   └── theme/app_theme.dart        # Material3, seed #1565C0, dark/light
│
└── features/
    ├── auth/
    │   └── presentation/screens/login_screen.dart  # email+password, signIn/signUp
    ├── accounts/
    │   ├── domain/account.dart                     # @freezed Account + AccountX
    │   ├── domain/account_repository.dart          # abstract interface
    │   ├── data/account_repository_impl.dart       # SupabaseAccountRepository (@riverpod)
    │   └── presentation/
    │       ├── account_providers.dart              # accountsProvider, totalBalanceProvider
    │       └── screens/
    │           ├── accounts_screen.dart            # список счетов
    │           └── add_account_screen.dart         # создание/редактирование счёта
    ├── transactions/
    │   ├── domain/transaction.dart                 # @freezed Transaction, enum TransactionType
    │   ├── domain/transaction_repository.dart
    │   ├── data/transaction_repository_impl.dart   # SupabaseTransactionRepository (@riverpod)
    │   └── presentation/
    │       ├── transaction_providers.dart          # monthlyTransactionsProvider(year,month,limit)
    │       │                                       # TransactionListNotifier (пагинация, isLoadingMore)
    │       │                                       # TransactionSearchNotifier
    │       └── screens/
    │           ├── transaction_list_screen.dart    # бесконечный скролл, поиск, swipe-удаление
    │           └── add_transaction_screen.dart     # доход/расход/перевод
    ├── categories/
    │   ├── domain/category.dart
    │   ├── domain/category_repository.dart
    │   └── data/category_repository_impl.dart     # categoryRepositoryProvider (@riverpod)
    ├── budgets/
    │   ├── domain/budget.dart                     # @freezed Budget + BudgetX (remaining, progress, isExceeded)
    │   ├── domain/budget_repository.dart          # abstract interface
    │   ├── data/budget_repository_impl.dart       # SupabaseBudgetRepository (@riverpod)
    │   └── presentation/screens/
    │       ├── budgets_screen.dart                # список + budgetsProvider (с расчётом spent)
    │       └── add_budget_screen.dart             # создание/редактирование бюджета
    ├── dashboard/
    │   └── presentation/screens/dashboard_screen.dart  # баланс + 5 последних операций
    └── statistics/
        └── presentation/screens/statistics_screen.dart # доходы/расходы + breakdown по категориям
```

## Навигация

```
/login                  → LoginScreen
/                       → DashboardScreen        (вкладка 0)
/transactions           → TransactionListScreen  (вкладка 1)
/transactions/add       → AddTransactionScreen
/statistics             → StatisticsScreen       (вкладка 2)
/budgets                → BudgetsScreen          (вкладка 3)
/budgets/add            → AddBudgetScreen
/budgets/edit/:id       → AddBudgetScreen(budget: extra)
/accounts               → AccountsScreen         (вкладка 4)
/accounts/add           → AddAccountScreen
/accounts/edit/:id      → AddAccountScreen(account: extra)
```

Auth guard в `GoRouter.redirect`: неавторизованных → /login.

## State Management

Riverpod 2.x с code generation (`@riverpod`):

| Тип | Когда использовать | Примеры |
|-----|--------------------|---------|
| `@riverpod Future<T>` | Одноразовый async запрос | `accountsProvider`, `totalBalanceProvider`, `monthlyTransactionsProvider` |
| `@riverpod class extends AsyncNotifier` | Список с мутациями | `TransactionListNotifier` (пагинация) |
| `@riverpod class extends Notifier` | Синхронный state | `TransactionSearchNotifier` |
| `StreamProvider` | Realtime данные | `authStateProvider` |
| `StateProvider` | Простой state | `themeModeProvider` |

После мутации (create/update/delete) — `ref.invalidate(provider)` для обновления всех зависимых экранов.

## База данных (Supabase)

### Схема таблиц

```sql
accounts     (id, user_id, name, type, balance, currency, color, icon, is_default, is_archived)
transactions (id, account_id, category_id, type, amount, note, date)
categories   (id, user_id nullable, name, icon, color, type, sort_order, is_system, is_archived)
budgets      (id, user_id, category_id, name, amount, currency, period, start_date, end_date, is_recurring)
```

### Баланс счёта

Хранится в `accounts.balance`. Автоматически обновляется PostgreSQL-триггером `trg_update_account_balance` при любом изменении `transactions`:
- INSERT income → balance += amount
- INSERT expense → balance -= amount
- DELETE — откат
- UPDATE — откат старой + применение новой

### RLS

Все таблицы защищены RLS. Пользователь видит только свои данные:
- `accounts` — по `user_id = auth.uid()`
- `transactions` — по `account_id IN (SELECT id FROM accounts WHERE user_id = auth.uid())`
- `categories` — системные видны всем авторизованным, пользовательские — только создателю
- `budgets` — по `user_id = auth.uid()`

### Миграции

```
supabase/migrations/
├── 20260408000001_initial_schema.sql  # таблицы + RLS + индексы + системные категории
├── 20260408000002_balance_trigger.sql # триггер авто-обновления баланса
└── 20260408000003_security_fixes.sql  # SECURITY DEFINER, защита от смены owner
```

## Особенности реализации

### Transfer (перевод)
Создаёт две транзакции: `expense` на счёте-источнике + `income` на счёте-получателе. Оба счёта обновляются через тот же триггер.

### Budget spent
`budgetsProvider` загружает бюджеты + все expense-транзакции за текущий месяц одним запросом, группирует по `category_id`, проставляет `spent` в каждый бюджет на клиенте.

### loadMore
`TransactionListNotifier.loadMore()` не ставит `AsyncValue.loading()` — используется флаг `_isLoadingMore`, чтобы список не мигал при пагинации.

## Что НЕ реализовано

- **Офлайн**: Drift добавлен в pubspec, `lib/core/database/` пуста
- **Тесты**: `test/unit/` и `test/widget/` пусты, `mocktail` добавлен
- **CI/CD**: нет
- **Экспорт данных**: нет (CSV/PDF)
- **Push-уведомления**: нет
- **Импорт из банков**: нет
