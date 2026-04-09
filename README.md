# Finance App

Мобильное приложение для учёта личных финансов на Flutter + Supabase.

## Стек

| Слой | Технология |
|------|-----------|
| UI | Flutter 3.41.6, Material 3 |
| State | Riverpod 2.x + code generation (`@riverpod`) |
| Навигация | go_router 14.x (StatefulShellRoute, 5 вкладок) |
| Модели | Freezed + json_serializable |
| Backend | Supabase (PostgreSQL, Auth, RLS, Realtime) |
| Офлайн | Drift (в pubspec, не реализован) |
| Графики | fl_chart |
| Безопасность | flutter_secure_storage (токены) |

## Функциональность

- Учёт доходов и расходов по категориям
- Несколько счетов (карта, наличные, банк, сбережения)
- Переводы между счетами (2 транзакции под капотом)
- Бюджеты с отслеживанием прогресса по категориям
- Статистика: расходы/доходы по месяцам + breakdown по категориям
- Поиск и бесконечный скролл по истории транзакций
- Dark / Light тема (Material 3, seed color #1565C0)
- Аутентификация через Supabase Auth (email + password)

## Структура проекта

```
lib/
├── core/
│   ├── di/providers.dart         # supabaseClientProvider, authStateProvider
│   ├── router/                   # GoRouter + AppShell (bottom nav)
│   ├── storage/                  # SecureLocalStorage (Supabase токены)
│   └── theme/app_theme.dart
└── features/
    ├── auth/          # LoginScreen (signIn / signUp)
    ├── accounts/      # AccountsScreen, AddAccountScreen, SupabaseAccountRepository
    ├── transactions/  # TransactionListScreen, AddTransactionScreen, пагинация
    ├── categories/    # CategoryRepository (системные + пользовательские)
    ├── budgets/       # BudgetsScreen, AddBudgetScreen, SupabaseBudgetRepository
    ├── dashboard/     # DashboardScreen (баланс + последние 5 операций)
    └── statistics/    # StatisticsScreen (графики fl_chart)

supabase/migrations/
├── 20260408000001_initial_schema.sql   # схема + RLS + индексы + категории
├── 20260408000002_balance_trigger.sql  # триггер авто-обновления баланса
└── 20260408000003_security_fixes.sql   # защита от смены owner
```

## Запуск

### 1. Supabase

Создайте проект на [supabase.com](https://supabase.com), примените миграции в SQL Editor:
```
supabase/migrations/20260408000001_initial_schema.sql
supabase/migrations/20260408000002_balance_trigger.sql
supabase/migrations/20260408000003_security_fixes.sql
```

### 2. Flutter

```bash
flutter pub get

# Code generation (Freezed, Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Запуск (подставьте свои ключи)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

> **Важно:** `dart run build_runner` падает из-за кириллицы в пути.
> Используйте только `flutter pub run build_runner`.

### 3. Анализ кода

```bash
flutter analyze
```

Текущее состояние: 0 ошибок, ~46 предупреждений (deprecated API, стиль).

## Архитектура

Clean Architecture + Feature-first. Подробнее: [ARCHITECTURE.md](ARCHITECTURE.md).

## Текущее состояние

| Компонент | Статус |
|-----------|--------|
| Аутентификация | ✅ Готово |
| Счета (CRUD) | ✅ Готово |
| Транзакции (список, добавление, удаление, перевод) | ✅ Готово |
| Бюджеты (CRUD + прогресс) | ✅ Готово |
| Дашборд | ✅ Готово |
| Статистика | ✅ Готово (базовая) |
| Баланс (авто через триггер) | ✅ Готово |
| SQL-миграции (файлы) | ✅ Созданы |
| SQL-миграции (применены) | ❌ Нужно вручную |
| Редактирование транзакций | ❌ Нет |
| Unit-тесты | ❌ Нет |
| Widget-тесты | ❌ Нет |
| Офлайн-режим | ❌ Нет (Drift не настроен) |
| CI/CD | ❌ Нет |

Готовность к production: **~55%**. Блокеры: нет тестов, миграции не применены.

## Задачи

Полный список приоритетов: [TASKS.md](TASKS.md).
