# MEMORY — Договорённости и правила проекта

Этот файл читается в начале каждой сессии. Здесь — всё что нельзя забывать.

---

## Окружение

- **Проект:** `c:\Моб. Приложения\finance_app\`
- **Flutter:** 3.41.6 stable
- **Запуск build_runner:** `flutter pub run build_runner build --delete-conflicting-outputs`
  - НЕ `dart run build_runner` — падает из-за кириллицы в пути
- **Кириллический путь** (`c:\Моб. Приложения`) вызывает проблемы в PowerShell и `dart run`
- **Переименование папки** в `MobProject` запланировано, но требует закрыть Claude Code и сделать вручную

---

## Правила кода

### Всегда после изменений в Dart-файлах с `@riverpod`, `@freezed`, `part`:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
```

### После любой мутации данных — инвалидировать ВСЕ зависимые провайдеры:
```dart
ref.invalidate(transactionListNotifierProvider);
ref.invalidate(accountsProvider);
ref.invalidate(totalBalanceProvider);
ref.invalidate(budgetsProvider);
ref.invalidate(monthlyTransactionsProvider(year: now.year, month: now.month));
```
Забыть один → дашборд/бюджеты покажут устаревшие данные.

### Transfer = 2 транзакции:
Перевод создаёт две записи: `expense` на счёте-источнике + `income` на счёте-получателе. Баланс обновляется автоматически через триггер в Supabase.

### Budget spent НЕ хранится в БД:
Поле `spent` в модели `Budget` — вычисляемое. Считается в `budgetsProvider` на клиенте из транзакций за текущий месяц.

### Баланс счёта обновляется через PostgreSQL-триггер:
Триггер `trg_update_account_balance` в `20260408000002_balance_trigger.sql` делает всё автоматически. Клиент НЕ должен вручную изменять `accounts.balance`.

---

## Архитектурные правила

- **Бизнес-логика** — только в Notifier/провайдерах, никогда в виджетах
- **Навигация** — только через `context.go()`, `context.push()`, никаких `Navigator.push`
- **DI** — только через Riverpod, никаких синглтонов
- **Модели** — иммутабельные через `freezed`, изменение через `.copyWith()`
- **Репозитории** — через `@riverpod`-провайдер, не напрямую `Supabase.instance.client`

---

## Supabase

- Credentials передаются через `--dart-define`, НЕ хардкодятся в коде
- Все 3 миграции из `supabase/migrations/` должны быть применены перед запуском
- RLS включён на всех таблицах — без применения миграций данные не читаются
- `LocalStorage` в Supabase 2.5+ — abstract class с override методами (не конструктор с named params)
- Исключения: `AuthApiException` (не `AuthException`)

---

## Что НЕ делать

- НЕ трогать `.freezed.dart` и `.g.dart` файлы руками — они генерируются
- НЕ добавлять бизнес-логику в виджеты
- НЕ использовать `withOpacity()` — deprecated, заменить на `.withValues(alpha: ...)`
- НЕ использовать `surfaceVariant` — deprecated, заменить на `surfaceContainerHighest`
- НЕ вызывать `state = AsyncValue.loading()` в `loadMore` — мигает весь список

---

## Агенты Claude Code (`.claude/agents/`)

| Агент | Специализация |
|-------|--------------|
| `mobile-developer` | Flutter: архитектура, провайдеры, навигация, API |
| `ui-designer` | Виджеты, экраны, Material 3, анимации |
| `backend-developer` | Supabase: SQL, RLS, Edge Functions |
| `qa-engineer` | Тесты, CI/CD, публикация |
| `security-auditor` | Аудит безопасности |
| `jarvis` | Координатор |

**Важно:** `subagent_type` в Agent tool использует старые имена: `flutter-architect`, `supabase-engineer`, а не `mobile-developer`, `backend-developer`.

---

## Текущее состояние (обновлять при изменениях)

- `flutter analyze`: **0 ошибок**, ~46 предупреждений (стиль)
- Последний `build_runner`: 88 сгенерированных файлов
- Готовность к production: **~55%**
- Блокер: нет тестов, SQL-миграции не применены (применяются вручную в Supabase Dashboard)
