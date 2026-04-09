import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../categories/data/category_repository_impl.dart';
import '../../../categories/domain/category.dart';
import '../../data/budget_repository_impl.dart';
import '../../domain/budget.dart';
import 'budgets_screen.dart';

class AddBudgetScreen extends ConsumerStatefulWidget {
  const AddBudgetScreen({super.key, this.budget});
  final Budget? budget;

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  String? _selectedCategoryId;
  String _selectedPeriod = 'monthly';
  bool _isSaving = false;

  bool get _isEditing => widget.budget != null;

  static const _periods = [
    ('daily',   'Ежедневно'),
    ('weekly',  'Еженедельно'),
    ('monthly', 'Ежемесячно'),
    ('yearly',  'Ежегодно'),
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameController   = TextEditingController(text: b?.name ?? '');
    _amountController = TextEditingController(
      text: b != null ? b.amount.toStringAsFixed(2) : '',
    );
    _selectedCategoryId = b?.categoryId;
    _selectedPeriod     = b?.period ?? 'monthly';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      // только expense категории для бюджетов
      FutureProvider((r) => r.watch(categoryRepositoryProvider).getCategories(isIncome: false)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать бюджет' : 'Новый бюджет'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Название
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название бюджета',
                  hintText: 'Например: Продукты на месяц',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите название';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Лимит
              Text('Лимит', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  suffix: Text('₽'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите сумму';
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Введите положительное число';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Категория
              Text('Категория (необязательно)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (cats) => _CategoryPicker(
                  categories: cats,
                  selectedId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
              ),
              const SizedBox(height: 24),

              // Период
              Text('Период', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _periods.map((p) {
                  final (value, label) = p;
                  return ChoiceChip(
                    label: Text(label),
                    selected: _selectedPeriod == value,
                    onSelected: (_) => setState(() => _selectedPeriod = value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Сохранить' : 'Создать бюджет'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo   = ref.read(budgetRepositoryProvider);
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final now    = DateTime.now();

      final budget = Budget(
        id:         widget.budget?.id ?? const Uuid().v4(),
        userId:     '',
        name:       _nameController.text.trim(),
        amount:     amount,
        categoryId: _selectedCategoryId,
        period:     _selectedPeriod,
        startDate:  widget.budget?.startDate ?? DateTime(now.year, now.month, 1),
        isRecurring: true,
      );

      if (_isEditing) {
        await repo.updateBudget(budget);
      } else {
        await repo.createBudget(budget);
      }

      ref.invalidate(budgetsProvider);

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Бюджет обновлён' : 'Бюджет создан')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(8),
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
                  selectedId == null
                      ? 'Без категории'
                      : categories
                              .where((c) => c.id == selectedId)
                              .firstOrNull
                              ?.name ??
                          'Категория',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (selectedId != null)
                GestureDetector(
                  onTap: () => onSelected(null),
                  child: Icon(Icons.clear,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              else
                Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Категория', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Без категории'),
                trailing: selectedId == null ? const Icon(Icons.check) : null,
                onTap: () {
                  onSelected(null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    return ListTile(
                      leading: const Icon(Icons.label),
                      title: Text(cat.name),
                      trailing: cat.id == selectedId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        onSelected(cat.id);
                        Navigator.pop(ctx);
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
