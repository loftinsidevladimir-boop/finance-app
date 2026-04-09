# Changelog

## [Unreleased]

### 2026-04-09 — Обработка ошибок сети

**Новые файлы:**
- `lib/core/network/network_provider.dart` — `connectivityProvider`, `isOnlineProvider`
- `lib/core/widgets/error_retry_widget.dart` — виджет ошибки с кнопкой «Повторить» (compact/full)

**Изменено:**
- `app_shell.dart` — offline-баннер: анимированный slide-in при потере сети
- `dashboard_screen.dart`, `budgets_screen.dart`, `accounts_screen.dart`, `statistics_screen.dart` — retry через `ref.invalidate()`

---

### 2026-04-09 — Security Hardening

**SQL (миграция 004):**
- `prevent_direct_balance_change` — нельзя напрямую писать в `accounts.balance`
- `WITH CHECK` на `transactions` UPDATE — новая строка тоже проверяется по `user_id`
- `prevent_transaction_account_change` — нельзя менять `account_id` у транзакции
- `enforce_category_not_system` — `is_system=false` принудительно при INSERT

**Flutter:**
- Репозитории очищают payload: убраны `balance`, `user_id`, `is_system`, `created_at`, join-поля
- `debugLogDiagnostics: kDebugMode` (убрали логи в production)

---

### 2026-04-09 — Тесты (56/56)

- `test/unit/` — 36 тестов: BudgetX, AccountX, алгоритм spent, TransactionListNotifier
- `test/widget/` — 20 тестов: DashboardScreen, BudgetsScreen, AddTransactionScreen

---

### 2026-04-09 — Редактирование транзакций

- `add_transaction_screen.dart` — параметр `Transaction?`, предзаполнение, `updateTransaction`
- `app_router.dart` — `/transactions/edit/:id`, `Routes.editTransaction(id)`
- `transaction_list_screen.dart` — tap → edit screen

---

### 2026-04-09 — SQL-миграции применены в Supabase

- Все 4 миграции применены
- Комбо-файл: `supabase/finance_app_full_schema.sql`

---

### 2026-04-08 — UI счетов и бюджетов

- `AddAccountScreen`, `AddBudgetScreen` — новые экраны форм
- `AccountsScreen` — FAB + PopupMenu + confirm delete
- `BudgetsScreen` — FAB + swipe delete + tap→edit
- `budget_repository_impl.dart` — новый репозиторий
- Маршруты: `/accounts/add|edit/:id`, `/budgets/add|edit/:id`

---

### 2026-04-08 — Критические баги

- `budgetsProvider` — `spent` теперь реальный (из транзакций месяца)
- `add_transaction_screen.dart` — переводы как 2 транзакции, инвалидация провайдеров
- `transaction_providers.dart` — `loadMore` без мигания (`_isLoadingMore`)
- `account_repository_impl.dart` — был заглушкой, реализован
- `secure_local_storage.dart` — переписан под Supabase 2.5+
- `login_screen.dart` — `AuthApiException` вместо `AuthException`
- SQL-миграции 001–003 созданы
