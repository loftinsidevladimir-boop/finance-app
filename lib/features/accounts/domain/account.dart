import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String name,
    @Default('card') String type,
    @Default(0.0) double balance,
    @Default('RUB') String currency,
    @Default('#4CAF50') String color,
    @Default('account_balance_wallet') String icon,
    @JsonKey(name: 'is_default') @Default(false) bool isDefault,
    @JsonKey(name: 'is_archived') @Default(false) bool isArchived,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

extension AccountX on Account {
  String get typeLabel {
    switch (type) {
      case 'cash':    return 'Наличные';
      case 'card':    return 'Карта';
      case 'bank':    return 'Банковский счёт';
      case 'savings': return 'Накопления';
      default:        return 'Другое';
    }
  }
}
