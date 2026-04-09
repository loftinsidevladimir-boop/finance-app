import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../transaction_providers.dart';
import '../../data/transaction_repository_impl.dart';
import '../../../../core/router/app_router.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  late ScrollController _scrollController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(transactionListNotifierProvider.notifier);
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 500) {
      notifier.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionListAsync = ref.watch(transactionListNotifierProvider);
    final searchNotifier = ref.watch(transactionSearchNotifierProvider);

    final isLoading = transactionListAsync is AsyncLoading;
    final transactions = transactionListAsync.valueOrNull ?? [];
    final searchResults = searchNotifier.valueOrNull ?? [];
    final displayTransactions = _isSearching ? searchResults : transactions;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Поиск...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  ref.read(transactionSearchNotifierProvider.notifier).search(query);
                },
              )
            : const Text('История операций'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
        ],
      ),
      body: displayTransactions.isEmpty && !isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching ? 'Ничего не найдено' : 'Нет операций',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: displayTransactions.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == displayTransactions.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                final transaction = displayTransactions[index];
                final categoryName = transaction.categories?['name'] as String? ?? 'Другое';
                final categoryIcon = transaction.categories?['icon'] as String? ?? 'category';
                final categoryColor = transaction.categories?['color'] as String? ?? '#1565C0';
                final accountName = transaction.accounts?['name'] as String? ?? 'Счет';

                return Dismissible(
                  key: Key(transaction.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteTransaction(transaction.id);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Theme.of(context).colorScheme.error,
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => context.push(
                      Routes.editTransaction(transaction.id),
                      extra: transaction,
                    ),
                    child: _TransactionTile(
                      categoryName: categoryName,
                      categoryIcon: categoryIcon,
                      categoryColor: categoryColor,
                      accountName: accountName,
                      amount: transaction.amount,
                      type: transaction.type,
                      date: transaction.date,
                      note: transaction.note,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(id);
      ref.invalidate(transactionListNotifierProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Операция удалена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.accountName,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
  });

  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String accountName;
  final double amount;
  final dynamic type;
  final DateTime date;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );

    final isIncome = type.toString().contains('income');
    final amountColor = isIncome ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _colorFromHex(categoryColor).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForCategory(categoryIcon),
                      color: _colorFromHex(categoryColor),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category, account, date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          accountName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isIncome ? '+' : '−'}${formatter.format(amount.abs())}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: amountColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy', 'ru').format(date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Заметка: $note',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) {
      return Color(int.parse('FF$hexColor', radix: 16));
    }
    return const Color(0xFF1565C0);
  }

  IconData _getIconForCategory(String icon) {
    switch (icon) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'movie':
        return Icons.movie;
      case 'flight':
        return Icons.flight;
      case 'payments':
        return Icons.payments;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }
}