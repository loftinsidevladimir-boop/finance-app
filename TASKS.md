# Задачи FinanceApp

## ✅ Сделано

- [x] Критические баги финансовой логики (spent, transfer, balance)
- [x] SQL-миграции 001–004: схема, RLS, триггеры, security hardening
- [x] Account CRUD: AddAccountScreen + редактирование + удаление
- [x] Budget CRUD: AddBudgetScreen + редактирование + swipe-удаление
- [x] Редактирование транзакций: tap → edit screen
- [x] Unit-тесты: 36/36 passed
- [x] Widget-тесты: 20/20 passed
- [x] Security audit + исправления payload в репозиториях
- [x] Offline-баннер + retry-кнопки на всех экранах
- [x] debugLogDiagnostics: kDebugMode (только в debug)
- [x] flutter analyze: 0 ошибок
- [x] Deprecation warnings: withOpacity → withValues, _ErrorWidget удалён, use_build_context_synchronously исправлен
- [x] CI/CD: GitHub Actions — analyze + test + build Android/iOS (зелёный)

---

## 🟢 Улучшения (хорошо иметь)

- [ ] **Офлайн-режим** через Drift
  - `lib/core/database/` пуста — нужна схема, DAOs
  - Стратегия: local-first, sync при подключении
  - Сложность: высокая

- [x] **Статистика по периодам** — переключатель + bar chart (доходы/расходы)

- [ ] **Экспорт данных** в CSV

- [ ] **Push-уведомления** при превышении бюджета

- [ ] **Импорт транзакций** из CSV / банковских выписок
