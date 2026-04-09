import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_retry_widget.dart';
import '../../data/budget_repository_impl.dart';
import '../../domain/budget.dart';

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd   = DateTime(now.year, now.month + 1, 1);

  // 1. Загружаем бюджеты
  final data = await client.from('budgets')
      .select('*, categories(id, name, icon, color)')
      .lte('start_date', monthEnd.toIso8601String())
      .or('end_date.is.null,end_date.gte.${monthStart.toIso8601String()}')
      .order('created_at', ascending: false);

  final budgets = data.map((e) => Budget.fromJson(e)).toList();

  // 2. Загружаем расходы за текущий месяц одним запросом
  final txData = await client
      .from('transactions')
      .select('category_id, amount')
      .eq('type', 'expense')
      .gte('date', monthStart.toIso8601String())
      .lt('date', monthEnd.toIso8601String());

  // 3. Группируем spent по categoryId
  final spentByCategory = <String, double>{};
  for (final tx in txData) {
    final catId = tx['category_id'] as String?;
    if (catId != null) {
      spentByCategory[catId] =
          (spentByCategory[catId] ?? 0.0) + (tx['amount'] as num).toDouble();
    }
  }

  // 4. Проставляем spent в каждый бюджет
  return budgets.map((b) => b.copyWith(
    spent: b.categoryId != null ? (spentByCategory[b.categoryId!] ?? 0.0) : 0.0,
  )).toList();
});

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджеты'),
      ),
      body: budgetsAsync.when(
        data: (budgets) => budgets.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет бюджетов',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: budgets.length,
                itemBuilder: (context, index) {
                  final budget = budgets[index];
                  return Dismissible(
                    key: ValueKey(budget.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Удалить бюджет?'),
                        content: Text('Бюджет "${budget.name}" будет удалён.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) async {
                      try {
                        await ref.read(budgetRepositoryProvider).deleteBudget(budget.id);
                        ref.invalidate(budgetsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                        }
                      }
                    },
                    child: _BudgetCard(
                      budget: budget,
                      onTap: () => context.push(Routes.editBudget(budget.id), extra: budget),
                    ),
                  );
                },
              ),
        loading: () => const _BudgetsListSkeleton(),
        error: (error, stack) => ErrorRetryWidget(
          error: error.toString(),
          onRetry: () => ref.invalidate(budgetsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.addBudget),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, this.onTap});
  final Budget budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );

    final categoryName = budget.categories?['name'] as String? ?? 'Категория';
    final categoryColor = budget.categories?['color'] as String? ?? '#1565C0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.category,
                      color: _colorFromHex(categoryColor),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category name and progress
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
                          '${formatter.format(budget.spent)} / ${formatter.format(budget.amount)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Status
                  if (budget.isExceeded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Превышено',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: budget.progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    budget.isExceeded
                        ? Colors.red
                        : _colorFromHex(categoryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Color _colorFromHex(String hexColor) {
    String hex = hexColor.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF1565C0);
  }
}

class _BudgetsListSkeleton extends StatelessWidget {
  const _BudgetsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
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
