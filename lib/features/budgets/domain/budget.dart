import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'category_id') String? categoryId,
    required String name,
    required double amount,
    @Default('RUB') String currency,
    @Default('monthly') String period,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'is_recurring') @Default(true) bool isRecurring,
    @Default('#2196F3') String color,
    /// Spent amount — not stored in DB, calculated separately
    @Default(0.0) double spent,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // joined
    Map<String, dynamic>? categories,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);
}

extension BudgetX on Budget {
  double get remaining => amount - spent;
  double get progress => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  bool get isExceeded => spent > amount;
}
