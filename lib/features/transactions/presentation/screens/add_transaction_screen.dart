import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../accounts/presentation/account_providers.dart';
import '../../../categories/domain/category.dart';
import '../transaction_providers.dart';
import '../../../categories/data/category_repository_impl.dart';
import '../../domain/transaction.dart';
import '../../data/transaction_repository_impl.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';

final _incomeCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).getCategories(isIncome: true);
});

final _expenseCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).getCategories(isIncome: false);
});

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});
  final Transaction? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedAccountId;
  String? _selectedToAccountId; // для transfer
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );
    _noteController = TextEditingController(text: tx?.note ?? '');
    if (tx != null) {
      _selectedType = tx.type;
      _selectedAccountId = tx.accountId;
      _selectedCategoryId = tx.categoryId;
      _selectedDate = tx.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_selectedAccountId == null) return false;
    if (_amountController.text.isEmpty) return false;
    if (_selectedType == TransactionType.transfer) {
      return _selectedToAccountId != null &&
          _selectedToAccountId != _selectedAccountId;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null ? 'Редактировать операцию' : 'Добавить операцию'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction type selector
            SegmentedButton<TransactionType>(
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text('Доход'),
                  icon: Icon(Icons.trending_up),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text('Расход'),
                  icon: Icon(Icons.trending_down),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.transfer,
                  label: Text('Перевод'),
                  icon: Icon(Icons.compare_arrows),
                ),
              ],
              selected: <TransactionType>{_selectedType},
              onSelectionChanged: widget.transaction != null
                  ? null
                  : (Set<TransactionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                        _selectedCategoryId = null;
                        _selectedToAccountId = null;
                      });
                    },
            ),
            const SizedBox(height: 24),

            // Amount
            Text(
              'Сумма',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '0.00',
                suffix: Text('₽'),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),

            // Account selection (откуда)
            Text(
              _selectedType == TransactionType.transfer ? 'Счёт (откуда)' : 'Счёт',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            accounts.when(
              data: (accountList) => _AccountSelector(
                accounts: accountList,
                selectedAccountId: _selectedAccountId,
                label: 'Выберите счёт',
                excludeAccountId: null,
                onAccountSelected: (accountId) {
                  setState(() => _selectedAccountId = accountId);
                },
              ),
              loading: () => const CircularProgressIndicator.adaptive(),
              error: (error, stack) => Text('Ошибка: $error'),
            ),

            // Счёт назначения (только для transfer)
            if (_selectedType == TransactionType.transfer) ...[
              const SizedBox(height: 24),
              Text(
                'Счёт назначения (куда)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              accounts.when(
                data: (accountList) => _AccountSelector(
                  accounts: accountList,
                  selectedAccountId: _selectedToAccountId,
                  label: 'Выберите счёт назначения',
                  excludeAccountId: _selectedAccountId,
                  onAccountSelected: (accountId) {
                    setState(() => _selectedToAccountId = accountId);
                  },
                ),
                loading: () => const CircularProgressIndicator.adaptive(),
                error: (error, stack) => Text('Ошибка: $error'),
              ),
            ],

            // Категория (не показываем для transfer)
            if (_selectedType != TransactionType.transfer) ...[
              const SizedBox(height: 24),
              Text(
                'Категория',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _CategorySelector(
                isIncome: _selectedType == TransactionType.income,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: (categoryId) {
                  setState(() => _selectedCategoryId = categoryId);
                },
              ),
            ],

            const SizedBox(height: 24),

            // Date picker
            Text(
              'Дата',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Note
            Text(
              'Заметка (необязательно)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Добавьте заметку...',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _saveTransaction : null,
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму больше нуля')),
      );
      return;
    }

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final note = _noteController.text.isEmpty ? null : _noteController.text;

      if (widget.transaction != null) {
        // Редактирование (переводы не редактируем — защита)
        if (widget.transaction!.type == TransactionType.transfer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Редактирование переводов не поддерживается')),
          );
          return;
        }
        await repo.updateTransaction(widget.transaction!.copyWith(
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          type: _selectedType,
          amount: amount,
          note: note,
          date: _selectedDate,
        ));
      } else if (_selectedType == TransactionType.transfer) {
        // Перевод: expense из источника + income в назначение
        await repo.createTransaction(Transaction(
          id: '',
          accountId: _selectedAccountId!,
          categoryId: null,
          type: TransactionType.expense,
          amount: amount,
          note: note ?? 'Перевод',
          date: _selectedDate,
        ));
        await repo.createTransaction(Transaction(
          id: '',
          accountId: _selectedToAccountId!,
          categoryId: null,
          type: TransactionType.income,
          amount: amount,
          note: note ?? 'Перевод',
          date: _selectedDate,
        ));
      } else {
        await repo.createTransaction(Transaction(
          id: '',
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          type: _selectedType,
          amount: amount,
          note: note,
          date: _selectedDate,
        ));
      }

      // Инвалидируем все зависимые провайдеры
      final now = DateTime.now();
      ref.invalidate(transactionListNotifierProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(monthlyTransactionsProvider(year: now.year, month: now.month));

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(widget.transaction != null ? 'Операция обновлена' : 'Операция сохранена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.accounts,
    required this.selectedAccountId,
    required this.label,
    required this.excludeAccountId,
    required this.onAccountSelected,
  });

  final List<dynamic> accounts;
  final String? selectedAccountId;
  final String label;
  final String? excludeAccountId;
  final Function(String) onAccountSelected;

  @override
  Widget build(BuildContext context) {
    final available = excludeAccountId != null
        ? accounts.where((a) => a.id != excludeAccountId).toList()
        : accounts;

    final selected = selectedAccountId != null
        ? available.where((a) => a.id == selectedAccountId).firstOrNull
        : null;

    return InkWell(
      onTap: () => _showAccountBottomSheet(context, available),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected?.name ?? label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountBottomSheet(BuildContext context, List<dynamic> available) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выберите счёт',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final account = available[index];
                  return ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(account.name),
                    trailing: account.id == selectedAccountId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      onAccountSelected(account.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySelector extends ConsumerWidget {
  const _CategorySelector({
    required this.isIncome,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final bool isIncome;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      isIncome ? _incomeCategoriesProvider : _expenseCategoriesProvider,
    );

    return categoriesAsync.when(
      data: (categoryList) => InkWell(
        onTap: () => _showCategoryBottomSheet(context, categoryList),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.category,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCategoryId == null
                        ? 'Выберите категорию'
                        : _getCategoryName(categoryList, selectedCategoryId),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Ошибка: $error',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }

  String _getCategoryName(List<Category> categories, String? id) {
    if (id == null) return 'Выберите категорию';
    try {
      return categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return 'Категория';
    }
  }

  void _showCategoryBottomSheet(
      BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Выберите категорию',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      leading: const Icon(Icons.category),
                      title: Text(category.name),
                      trailing: category.id == selectedCategoryId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        onCategorySelected(category.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
