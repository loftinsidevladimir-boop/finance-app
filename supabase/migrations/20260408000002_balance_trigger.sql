-- ============================================================
-- Миграция 2: Триггер авто-обновления баланса счёта
-- При каждом INSERT/UPDATE/DELETE в transactions автоматически
-- обновляется поле balance в таблице accounts.
-- ============================================================

CREATE OR REPLACE FUNCTION update_account_balance_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Новая транзакция: income увеличивает баланс, expense уменьшает
    IF NEW.type = 'income' THEN
      UPDATE accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
    ELSIF NEW.type = 'expense' THEN
      UPDATE accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
    -- transfer: обрабатывается двумя отдельными транзакциями (expense + income)
    -- поэтому здесь ничего дополнительного не нужно
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    -- Удаление: откатываем эффект старой транзакции
    IF OLD.type = 'income' THEN
      UPDATE accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
    ELSIF OLD.type = 'expense' THEN
      UPDATE accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Обновление: сначала откатываем старую, затем применяем новую

    -- Откат старой транзакции
    IF OLD.type = 'income' THEN
      UPDATE accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
    ELSIF OLD.type = 'expense' THEN
      UPDATE accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
    END IF;

    -- Если изменился счёт — откатить со старого, применить к новому
    -- (если счёт не изменился, обе операции идут к одному счёту — корректно)
    IF NEW.type = 'income' THEN
      UPDATE accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
    ELSIF NEW.type = 'expense' THEN
      UPDATE accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public;

-- Запрет прямого вызова функции из внешнего кода
REVOKE ALL ON FUNCTION update_account_balance_on_transaction() FROM PUBLIC;

-- Триггер навешивается на таблицу transactions
DROP TRIGGER IF EXISTS trg_update_account_balance ON transactions;
CREATE TRIGGER trg_update_account_balance
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_account_balance_on_transaction();
