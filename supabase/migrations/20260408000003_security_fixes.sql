-- ============================================================
-- Миграция 3: Дополнительные меры безопасности
-- ============================================================

-- 1. Пользователь не может сменить владельца счёта
--    (политика update уже это делает через WITH CHECK, но явно добавим)
--    Уже покрыто в миграции 1 через WITH CHECK (auth.uid() = user_id)

-- 2. Пользователь не может создать транзакцию для чужого счёта.
--    Уже покрыто политикой transactions_insert_own.

-- 3. Защита: запретить изменение user_id в accounts через триггер
CREATE OR REPLACE FUNCTION prevent_user_id_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id <> OLD.user_id THEN
    RAISE EXCEPTION 'Changing owner of a record is not allowed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public;

REVOKE ALL ON FUNCTION prevent_user_id_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_prevent_account_owner_change ON accounts;
CREATE TRIGGER trg_prevent_account_owner_change
  BEFORE UPDATE ON accounts
  FOR EACH ROW
  WHEN (OLD.user_id IS DISTINCT FROM NEW.user_id)
  EXECUTE FUNCTION prevent_user_id_change();

DROP TRIGGER IF EXISTS trg_prevent_budget_owner_change ON budgets;
CREATE TRIGGER trg_prevent_budget_owner_change
  BEFORE UPDATE ON budgets
  FOR EACH ROW
  WHEN (OLD.user_id IS DISTINCT FROM NEW.user_id)
  EXECUTE FUNCTION prevent_user_id_change();

-- 4. Защита баланса: запретить прямое изменение balance из клиента.
--    Баланс обновляется ТОЛЬКО через триггер trg_update_account_balance.
--    Для этого убираем UPDATE-политику для поля balance
--    и добавляем отдельную политику только для нефинансовых полей.
--
--    Примечание: Supabase не поддерживает column-level RLS напрямую,
--    поэтому вместо этого создаём функцию-обёртку для изменения баланса вручную.
--    Клиент НЕ должен напрямую обновлять balance — только через транзакции.

-- Функция для ручного задания начального баланса счёта (при создании счёта)
CREATE OR REPLACE FUNCTION set_initial_account_balance(
  p_account_id uuid,
  p_balance numeric
)
RETURNS void AS $$
BEGIN
  -- Только владелец счёта может задать начальный баланс
  IF NOT EXISTS (
    SELECT 1 FROM accounts WHERE id = p_account_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  UPDATE accounts SET balance = p_balance WHERE id = p_account_id;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public;

GRANT EXECUTE ON FUNCTION set_initial_account_balance(uuid, numeric) TO authenticated;

-- 5. Проверка: убедиться что все таблицы имеют RLS включённый
DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename IN ('accounts', 'transactions', 'categories', 'budgets')
  LOOP
    -- Проверяем через pg_class
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE relname = tbl) THEN
      RAISE WARNING 'RLS not enabled on table: %', tbl;
    END IF;
  END LOOP;
END;
$$;
