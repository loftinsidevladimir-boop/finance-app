import 'account.dart';

abstract interface class AccountRepository {
  Future<List<Account>> getAccounts();
  Future<Account> getAccount(String id);
  Future<Account> createAccount(Account account);
  Future<Account> updateAccount(Account account);
  Future<void> deleteAccount(String id);
  Stream<List<Account>> watchAccounts();
}
