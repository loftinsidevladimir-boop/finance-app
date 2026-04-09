import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../di/providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transaction_list_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/budgets/presentation/screens/add_budget_screen.dart';
import '../../features/budgets/domain/budget.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/add_account_screen.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/transactions/domain/transaction.dart';
import 'app_shell.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: Routes.dashboard,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final isOnLogin  = state.matchedLocation == Routes.login;
      if (!isLoggedIn && !isOnLogin) return Routes.login;
      if (isLoggedIn  &&  isOnLogin) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => AppShell(shell: shell),
        branches: [
          // Главная
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.dashboard,
              builder: (ctx, state) => const DashboardScreen(),
            ),
          ]),

          // Операции
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.transactions,
              builder: (ctx, state) => const TransactionListScreen(),
              routes: [
                GoRoute(
                  path: Routes.addTransaction,
                  builder: (ctx, state) => const AddTransactionScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (ctx, state) {
                    final transaction = state.extra as Transaction?;
                    return AddTransactionScreen(transaction: transaction);
                  },
                ),
              ],
            ),
          ]),

          // Статистика
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.statistics,
              builder: (ctx, state) => const StatisticsScreen(),
            ),
          ]),

          // Бюджеты
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.budgets,
              builder: (ctx, state) => const BudgetsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (ctx, state) => const AddBudgetScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (ctx, state) {
                    final budget = state.extra as Budget?;
                    return AddBudgetScreen(budget: budget);
                  },
                ),
              ],
            ),
          ]),

          // Счета
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.accounts,
              builder: (ctx, state) => const AccountsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (ctx, state) => const AddAccountScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  builder: (ctx, state) {
                    final account = state.extra as Account?;
                    return AddAccountScreen(account: account);
                  },
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}

abstract class Routes {
  static const login           = '/login';
  static const dashboard       = '/';
  static const transactions    = '/transactions';
  static const addTransaction  = 'add';
  static const statistics      = '/statistics';
  static const budgets         = '/budgets';
  static const accounts        = '/accounts';

  // Вложенные маршруты транзакций
  static String editTransaction(String id) => '/transactions/edit/$id';

  // Вложенные маршруты счетов
  static const addAccount      = '/accounts/add';
  static String editAccount(String id) => '/accounts/edit/$id';

  // Вложенные маршруты бюджетов
  static const addBudget       = '/budgets/add';
  static String editBudget(String id) => '/budgets/edit/$id';
}
