-- ============================================================
-- Миграция 4: Усиление безопасности (по результатам аудита)
-- ============================================================

-- 1. Запретить прямое изменение balance в таблице accounts.
--    Баланс должен обновляться ТОЛЬКО через триггер trg_update_account_balance.
CREATE OR REPLACE FUNCTION public.prevent_direct_balance_change()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.balance IS DISTINCT FROM OLD.balance THEN
    RAISE EXCEPTION 'Direct balance modification is not allowed. Use transactions instead.';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_direct_balance_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_prevent_balance_change ON public.accounts;
CREATE TRIGGER trg_prevent_balance_change
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW
  WHEN (OLD.balance IS DISTINCT FROM NEW.balance)
  EXECUTE FUNCTION public.prevent_direct_balance_change();

-- 2. Добавить WITH CHECK к политике обновления транзакций.
--    USING проверяет старую строку, WITH CHECK — новую.
--    Без WITH CHECK можно было изменить account_id на чужой.
DROP POLICY IF EXISTS transactions_update ON public.transactions;
CREATE POLICY transactions_update ON public.transactions
  FOR UPDATE
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 3. Запретить смену account_id у транзакции.
--    account_id определяет к какому счёту относится транзакция —
--    его смена может привести к некорректному балансу.
CREATE OR REPLACE FUNCTION public.prevent_transaction_account_change()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.account_id IS DISTINCT FROM OLD.account_id THEN
    RAISE EXCEPTION 'Changing account_id of a transaction is not allowed';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_transaction_account_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_prevent_transaction_account_change ON public.transactions;
CREATE TRIGGER trg_prevent_transaction_account_change
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW
  WHEN (OLD.account_id IS DISTINCT FROM NEW.account_id)
  EXECUTE FUNCTION public.prevent_transaction_account_change();

-- 4. Принудительно сбрасывать is_system=false при пользовательском INSERT категории.
--    RLS-политика это уже запрещает, но триггер — дополнительный слой защиты.
CREATE OR REPLACE FUNCTION public.enforce_category_not_system()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
BEGIN
  NEW.is_system := false;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_category_not_system() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_category_force_not_system ON public.categories;
CREATE TRIGGER trg_category_force_not_system
  BEFORE INSERT ON public.categories
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_category_not_system();
