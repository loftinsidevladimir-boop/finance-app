// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$monthlyTransactionsHash() =>
    r'8355a211a9f34faef6026a9f1fab0c2642624f73';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [monthlyTransactions].
@ProviderFor(monthlyTransactions)
const monthlyTransactionsProvider = MonthlyTransactionsFamily();

/// See also [monthlyTransactions].
class MonthlyTransactionsFamily extends Family<AsyncValue<List<Transaction>>> {
  /// See also [monthlyTransactions].
  const MonthlyTransactionsFamily();

  /// See also [monthlyTransactions].
  MonthlyTransactionsProvider call({
    required int year,
    required int month,
    int limit = 50,
  }) {
    return MonthlyTransactionsProvider(
      year: year,
      month: month,
      limit: limit,
    );
  }

  @override
  MonthlyTransactionsProvider getProviderOverride(
    covariant MonthlyTransactionsProvider provider,
  ) {
    return call(
      year: provider.year,
      month: provider.month,
      limit: provider.limit,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'monthlyTransactionsProvider';
}

/// See also [monthlyTransactions].
class MonthlyTransactionsProvider
    extends AutoDisposeFutureProvider<List<Transaction>> {
  /// See also [monthlyTransactions].
  MonthlyTransactionsProvider({
    required int year,
    required int month,
    int limit = 50,
  }) : this._internal(
          (ref) => monthlyTransactions(
            ref as MonthlyTransactionsRef,
            year: year,
            month: month,
            limit: limit,
          ),
          from: monthlyTransactionsProvider,
          name: r'monthlyTransactionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$monthlyTransactionsHash,
          dependencies: MonthlyTransactionsFamily._dependencies,
          allTransitiveDependencies:
              MonthlyTransactionsFamily._allTransitiveDependencies,
          year: year,
          month: month,
          limit: limit,
        );

  MonthlyTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
    required this.month,
    required this.limit,
  }) : super.internal();

  final int year;
  final int month;
  final int limit;

  @override
  Override overrideWith(
    FutureOr<List<Transaction>> Function(MonthlyTransactionsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MonthlyTransactionsProvider._internal(
        (ref) => create(ref as MonthlyTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
        month: month,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Transaction>> createElement() {
    return _MonthlyTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyTransactionsProvider &&
        other.year == year &&
        other.month == month &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);
    hash = _SystemHash.combine(hash, month.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MonthlyTransactionsRef
    on AutoDisposeFutureProviderRef<List<Transaction>> {
  /// The parameter `year` of this provider.
  int get year;

  /// The parameter `month` of this provider.
  int get month;

  /// The parameter `limit` of this provider.
  int get limit;
}

class _MonthlyTransactionsProviderElement
    extends AutoDisposeFutureProviderElement<List<Transaction>>
    with MonthlyTransactionsRef {
  _MonthlyTransactionsProviderElement(super.provider);

  @override
  int get year => (origin as MonthlyTransactionsProvider).year;
  @override
  int get month => (origin as MonthlyTransactionsProvider).month;
  @override
  int get limit => (origin as MonthlyTransactionsProvider).limit;
}

String _$transactionListNotifierHash() =>
    r'e06f66ea4e192be6cbafe4cd199be05736cd845a';

/// See also [TransactionListNotifier].
@ProviderFor(TransactionListNotifier)
final transactionListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TransactionListNotifier, List<Transaction>>.internal(
  TransactionListNotifier.new,
  name: r'transactionListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transactionListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransactionListNotifier = AutoDisposeAsyncNotifier<List<Transaction>>;
String _$transactionSearchNotifierHash() =>
    r'59ece4dea988219f2692de3ad22d3b57e15c3e78';

/// See also [TransactionSearchNotifier].
@ProviderFor(TransactionSearchNotifier)
final transactionSearchNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TransactionSearchNotifier, List<Transaction>>.internal(
  TransactionSearchNotifier.new,
  name: r'transactionSearchNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transactionSearchNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransactionSearchNotifier
    = AutoDisposeAsyncNotifier<List<Transaction>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
