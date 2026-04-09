-- ============================================================
-- Миграция 1: Начальная схема БД для финансового приложения
-- Таблицы: accounts, categories, transactions, budgets
-- RLS политики, индексы, системные категории
-- ============================================================

-- Функция для авто-обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ТАБЛИЦА: accounts (счета пользователей)
-- ============================================================
CREATE TABLE IF NOT EXISTS accounts (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  type        text        NOT NULL DEFAULT 'card'
                          CHECK (type IN ('card', 'cash', 'bank', 'savings')),
  balance     numeric(15, 2) NOT NULL DEFAULT 0,
  currency    text        NOT NULL DEFAULT 'RUB',
  color       text        NOT NULL DEFAULT '#4CAF50',
  icon        text        NOT NULL DEFAULT 'account_balance_wallet',
  is_default  boolean     NOT NULL DEFAULT false,
  is_archived boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_is_archived ON accounts(is_archived);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "accounts_select_own" ON accounts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "accounts_insert_own" ON accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "accounts_update_own" ON accounts
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "accounts_delete_own" ON accounts
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- ТАБЛИЦА: categories (категории транзакций)
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  icon        text        NOT NULL DEFAULT 'category',
  color       text        NOT NULL DEFAULT '#607D8B',
  type        text        NOT NULL DEFAULT 'expense'
                          CHECK (type IN ('income', 'expense')),
  sort_order  integer     NOT NULL DEFAULT 0,
  is_system   boolean     NOT NULL DEFAULT false,
  is_archived boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);
CREATE INDEX IF NOT EXISTS idx_categories_is_system ON categories(is_system);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Системные категории (is_system = true, user_id = null) видны всем авторизованным
-- Пользовательские — только их создателю
CREATE POLICY "categories_select" ON categories
  FOR SELECT USING (
    is_system = true OR auth.uid() = user_id
  );

CREATE POLICY "categories_insert_own" ON categories
  FOR INSERT WITH CHECK (auth.uid() = user_id AND is_system = false);

CREATE POLICY "categories_update_own" ON categories
  FOR UPDATE USING (auth.uid() = user_id AND is_system = false)
  WITH CHECK (auth.uid() = user_id AND is_system = false);

CREATE POLICY "categories_delete_own" ON categories
  FOR DELETE USING (auth.uid() = user_id AND is_system = false);

-- ============================================================
-- ТАБЛИЦА: transactions (доходы и расходы)
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id  uuid        NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  category_id uuid        REFERENCES categories(id) ON DELETE SET NULL,
  type        text        NOT NULL
                          CHECK (type IN ('income', 'expense', 'transfer')),
  amount      numeric(15, 2) NOT NULL CHECK (amount > 0),
  note        text,
  date        timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
-- Составной индекс для фильтрации по аккаунту + дате (частый запрос)
CREATE INDEX IF NOT EXISTS idx_transactions_account_date ON transactions(account_id, date DESC);

-- Полнотекстовый поиск по заметкам
CREATE INDEX IF NOT EXISTS idx_transactions_note_fts
  ON transactions USING gin(to_tsvector('russian', coalesce(note, '')));

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Пользователь видит транзакции только по своим счетам
CREATE POLICY "transactions_select_own" ON transactions
  FOR SELECT USING (
    account_id IN (SELECT id FROM accounts WHERE user_id = auth.uid())
  );

CREATE POLICY "transactions_insert_own" ON transactions
  FOR INSERT WITH CHECK (
    account_id IN (SELECT id FROM accounts WHERE user_id = auth.uid())
  );

CREATE POLICY "transactions_update_own" ON transactions
  FOR UPDATE USING (
    account_id IN (SELECT id FROM accounts WHERE user_id = auth.uid())
  );

CREATE POLICY "transactions_delete_own" ON transactions
  FOR DELETE USING (
    account_id IN (SELECT id FROM accounts WHERE user_id = auth.uid())
  );

-- ============================================================
-- ТАБЛИЦА: budgets (бюджеты по категориям)
-- ============================================================
CREATE TABLE IF NOT EXISTS budgets (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id  uuid        REFERENCES categories(id) ON DELETE SET NULL,
  name         text        NOT NULL,
  amount       numeric(15, 2) NOT NULL CHECK (amount > 0),
  currency     text        NOT NULL DEFAULT 'RUB',
  period       text        NOT NULL DEFAULT 'monthly'
                           CHECK (period IN ('daily', 'weekly', 'monthly', 'yearly')),
  start_date   timestamptz NOT NULL DEFAULT now(),
  end_date     timestamptz,
  is_recurring boolean     NOT NULL DEFAULT true,
  color        text        NOT NULL DEFAULT '#2196F3',
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT budgets_date_check CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON budgets(user_id);
CREATE INDEX IF NOT EXISTS idx_budgets_category_id ON budgets(category_id);
CREATE INDEX IF NOT EXISTS idx_budgets_start_date ON budgets(start_date);

ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "budgets_select_own" ON budgets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "budgets_insert_own" ON budgets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budgets_update_own" ON budgets
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budgets_delete_own" ON budgets
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- СИСТЕМНЫЕ КАТЕГОРИИ (расходы)
-- ============================================================
INSERT INTO categories (id, name, icon, color, type, sort_order, is_system, user_id)
VALUES
  (gen_random_uuid(), 'Продукты',           'shopping_cart',     '#4CAF50', 'expense', 1,  true, null),
  (gen_random_uuid(), 'Кафе и рестораны',   'restaurant',        '#FF9800', 'expense', 2,  true, null),
  (gen_random_uuid(), 'Транспорт',          'local_gas_station', '#2196F3', 'expense', 3,  true, null),
  (gen_random_uuid(), 'Здоровье',           'health_and_safety', '#F44336', 'expense', 4,  true, null),
  (gen_random_uuid(), 'Развлечения',        'movie',             '#9C27B0', 'expense', 5,  true, null),
  (gen_random_uuid(), 'Путешествия',        'flight',            '#00BCD4', 'expense', 6,  true, null),
  (gen_random_uuid(), 'ЖКХ',               'home',              '#795548', 'expense', 7,  true, null),
  (gen_random_uuid(), 'Одежда',             'checkroom',         '#E91E63', 'expense', 8,  true, null),
  (gen_random_uuid(), 'Другое',             'category',          '#607D8B', 'expense', 99, true, null)
ON CONFLICT DO NOTHING;

-- ============================================================
-- СИСТЕМНЫЕ КАТЕГОРИИ (доходы)
-- ============================================================
INSERT INTO categories (id, name, icon, color, type, sort_order, is_system, user_id)
VALUES
  (gen_random_uuid(), 'Зарплата',   'payments',   '#4CAF50', 'income', 1,  true, null),
  (gen_random_uuid(), 'Фриланс',    'work',       '#2196F3', 'income', 2,  true, null),
  (gen_random_uuid(), 'Инвестиции', 'trending_up','#FF9800', 'income', 3,  true, null),
  (gen_random_uuid(), 'Подарки',    'card_giftcard','#E91E63','income',4,  true, null),
  (gen_random_uuid(), 'Другое',     'category',   '#607D8B', 'income', 99, true, null)
ON CONFLICT DO NOTHING;
