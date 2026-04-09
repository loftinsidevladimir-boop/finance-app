import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/transaction_repository_impl.dart';
import '../domain/transaction.dart';

part 'transaction_providers.g.dart';

// Список транзакций за месяц (limit опционален — на дашборде передаём 5)
@riverpod
Future<List<Transaction>> monthlyTransactions(
  MonthlyTransactionsRef ref, {
  required int year,
  required int month,
  int limit = 50,
}) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final from = DateTime(year, month, 1);
  final to   = DateTime(year, month + 1, 1);
  return repo.getTransactions(from: from, to: to, limit: limit);
}

// Провайдер для пагинированной истории
@riverpod
class TransactionListNotifier extends _$TransactionListNotifier {
  @override
  Future<List<Transaction>> build() async {
    return _load(reset: true);
  }

  static const _pageSize = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<List<Transaction>> _load({bool reset = false}) async {
    final repo = ref.read(transactionRepositoryProvider);
    if (reset) _offset = 0;
    final result = await repo.getTransactions(
      limit: _pageSize,
      offset: _offset,
    );
    _hasMore = result.length == _pageSize;
    _offset += result.length;
    return result;
  }

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final current = state.valueOrNull ?? [];
    _isLoadingMore = true;
    try {
      final more = await _load();
      state = AsyncValue.data([...current, ...more]);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _load(reset: true));
  }
}

// Поиск транзакций
@riverpod
class TransactionSearchNotifier extends _$TransactionSearchNotifier {
  @override
  Future<List<Transaction>> build() async => [];

  Future<void> search(String query) async {
    if (query.isEmpty) { state = const AsyncValue.data([]); return; }
    state = const AsyncValue.loading();
    final repo = ref.read(transactionRepositoryProvider);
    state = AsyncValue.data(await repo.searchTransactions(query));
  }
}