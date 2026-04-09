import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/features/accounts/domain/account.dart';

void main() {
  Account makeAccount({required String type}) {
    return Account(
      id: 'a1',
      userId: 'u1',
      name: 'Тест счёт',
      type: type,
    );
  }

  group('AccountX.typeLabel', () {
    test('cash возвращает Наличные', () {
      expect(makeAccount(type: 'cash').typeLabel, equals('Наличные'));
    });

    test('card возвращает Карта', () {
      expect(makeAccount(type: 'card').typeLabel, equals('Карта'));
    });

    test('bank возвращает Банковский счёт', () {
      expect(makeAccount(type: 'bank').typeLabel, equals('Банковский счёт'));
    });

    test('savings возвращает Накопления', () {
      expect(makeAccount(type: 'savings').typeLabel, equals('Накопления'));
    });

    test('неизвестный тип возвращает Другое', () {
      expect(makeAccount(type: 'crypto').typeLabel, equals('Другое'));
    });

    test('пустая строка возвращает Другое', () {
      expect(makeAccount(type: '').typeLabel, equals('Другое'));
    });
  });
}
