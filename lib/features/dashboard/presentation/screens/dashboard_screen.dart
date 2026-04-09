import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/error_retry_widget.dart';
import '../../../transactions/presentation/transaction_providers.dart';
import '../../../accounts/presentation/account_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final now = DateTime.now();
    final monthlyTransactions = ref.watch(
      monthlyTransactionsProvider(year: now.year, month: now.month, limit: 5),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinanceApp'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            if (currentUser != null) ...[
              Text(
                'Привет, ${currentUser.userMetadata?['full_name'] ?? currentUser.email?.split('@')[0] ?? 'Пользователь'}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
            ],

            // Total Balance Card
            totalBalance.when(
              data: (balance) => _BalanceCard(balance: balance),
              loading: () => const _BalanceCardSkeleton(),
              error: (error, stack) => ErrorRetryWidget(
                error: error.toString(),
                compact: true,
                onRetry: () => ref.invalidate(totalBalanceProvider),
              ),
            ),
            const SizedBox(height: 32),

            // Recent Transactions
            Text(
              'Последние операции',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            monthlyTransactions.when(
              data: (transactions) => transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Нет операций',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : Column(
                      children: transactions.map((transaction) {
                        final categoryName = transaction.categories?['name'] as String? ?? 'Другое';
                        final categoryIcon = transaction.categories?['icon'] as String? ?? 'category';
                        final categoryColor = transaction.categories?['color'] as String? ?? '#1565C0';
                        final accountName = transaction.accounts?['name'] as String? ?? 'Счет';

                        return _TransactionCard(
                          categoryName: categoryName,
                          categoryIcon: categoryIcon,
                          categoryColor: categoryColor,
                          accountName: accountName,
                          amount: transaction.amount,
                          type: transaction.type,
                          date: transaction.date,
                        );
                      }).toList(),
                    ),
              loading: () => const _TransactionListSkeleton(),
              error: (error, stack) => ErrorRetryWidget(
                error: error.toString(),
                compact: true,
                onRetry: () => ref.invalidate(
                  monthlyTransactionsProvider(
                    year: now.year, month: now.month, limit: 5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Общий баланс',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              formatter.format(balance),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 200,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.accountName,
    required this.amount,
    required this.type,
    required this.date,
  });

  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String accountName;
  final double amount;
  final dynamic type;
  final DateTime date;

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                      '$accountName • ${DateFormat('dd MMM yyyy', 'ru').format(date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${isIncome ? '+' : '−'}${formatter.format(amount.abs())}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
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

class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
