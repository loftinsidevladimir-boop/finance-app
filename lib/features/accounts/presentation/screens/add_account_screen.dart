import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../data/account_repository_impl.dart';
import '../../domain/account.dart';
import '../account_providers.dart';

const _accountColors = [
  '#4CAF50', '#2196F3', '#FF9800', '#F44336',
  '#9C27B0', '#00BCD4', '#795548', '#607D8B',
  '#E91E63', '#FF5722', '#009688', '#3F51B5',
];

const _accountTypes = [
  ('card',    'Карта',            Icons.credit_card),
  ('cash',    'Наличные',         Icons.payments),
  ('bank',    'Банковский счёт',  Icons.account_balance),
  ('savings', 'Накопления',       Icons.savings),
];

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key, this.account});
  final Account? account; // null = создание, non-null = редактирование

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late String _selectedType;
  late String _selectedColor;
  late bool _isDefault;
  bool _isSaving = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _nameController    = TextEditingController(text: a?.name ?? '');
    _balanceController = TextEditingController(
      text: a != null ? a.balance.toStringAsFixed(2) : '',
    );
    _selectedType  = a?.type  ?? 'card';
    _selectedColor = a?.color ?? '#4CAF50';
    _isDefault     = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать счёт' : 'Новый счёт'),
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
                decoration: const InputDecoration(
                  labelText: 'Название счёта',
                  hintText: 'Например: Основная карта',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите название';
                  if (v.trim().length > 50) return 'Не более 50 символов';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Начальный баланс
              Text('Начальный баланс', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  suffix: Text('₽'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null; // необязательно
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null) return 'Введите число';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Тип счёта
              Text('Тип счёта', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accountTypes.map((t) {
                  final (type, label, icon) = t;
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Цвет
              Text('Цвет', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accountColors.map((hex) {
                  final color = _colorFromHex(hex);
                  final selected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // По умолчанию
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Счёт по умолчанию'),
                subtitle: const Text('Будет автоматически выбираться при добавлении операции'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 32),

              // Кнопка
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
                      : Text(_isEditing ? 'Сохранить' : 'Создать счёт'),
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
      final repo = ref.read(accountRepositoryProvider);
      final balance = double.tryParse(
        _balanceController.text.replaceAll(',', '.'),
      ) ?? 0.0;

      final account = Account(
        id: widget.account?.id ?? const Uuid().v4(),
        userId: '', // заполнится RLS на сервере
        name: _nameController.text.trim(),
        type: _selectedType,
        balance: balance,
        color: _selectedColor,
        isDefault: _isDefault,
        createdAt: widget.account?.createdAt,
      );

      if (_isEditing) {
        await repo.updateAccount(account);
      } else {
        await repo.createAccount(account);
      }

      ref.invalidate(accountsProvider);
      ref.invalidate(totalBalanceProvider);

      if (!mounted) return;
      context.pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Счёт обновлён' : 'Счёт создан'),
        ),
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

  Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
