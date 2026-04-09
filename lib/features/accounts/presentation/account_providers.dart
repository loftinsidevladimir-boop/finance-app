import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/di/providers.dart';
import '../domain/account.dart';

part 'account_providers.g.dart';

@riverpod
Future<List<Account>> accounts(AccountsRef ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('accounts')
    .select()
    .eq('is_archived', false)
    .order('is_default', ascending: false);
  return data.map((e) => Account.fromJson(e)).toList();
}

@riverpod
Future<double> totalBalance(TotalBalanceRef ref) async {
  final accountList = await ref.watch(accountsProvider.future);
  return accountList.fold<double>(0.0, (sum, a) => sum + a.balance);
}