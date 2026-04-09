import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../transactions/presentation/transaction_providers.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../../core/widgets/error_retry_widget.dart';

// ─────────────────────────────────────────────
// Enum: StatsPeriod
// ─────────────────────────────────────────────

enum StatsPeriod {
  week,
  month,
  quarter,
  year;

  String get label {
    switch (this) {
      case StatsPeriod.week:    return 'Неделя';
      case StatsPeriod.month:   return 'Месяц';
      case StatsPeriod.quarter: return 'Квартал';
      case StatsPeriod.year:    return 'Год';
    }
  }

  DateTimeRange range(DateTime anchor) {
    switch (this) {
      case StatsPeriod.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case StatsPeriod.month:
        return DateTimeRange(
          start: DateTime(anchor.year, anchor.month, 1),
          end: DateTime(anchor.year, anchor.month + 1, 1),
        );
      case StatsPeriod.quarter:
        final q = ((anchor.month - 1) ~/ 3);
        final startMonth = q * 3 + 1;
        return DateTimeRange(
          start: DateTime(anchor.year, startMonth, 1),
          end: DateTime(anchor.year, startMonth + 3, 1),
        );
      case StatsPeriod.year:
        return DateTimeRange(
          start: DateTime(anchor.year, 1, 1),
          end: DateTime(anchor.year + 1, 1, 1),
        );
    }
  }

  DateTime next(DateTime anchor) {
    switch (this) {
      case StatsPeriod.week:    return anchor.add(const Duration(days: 7));
      case StatsPeriod.month:   return DateTime(anchor.year, anchor.month + 1, 1);
      case StatsPeriod.quarter: return DateTime(anchor.year, anchor.month + 3, 1);
      case StatsPeriod.year:    return DateTime(anchor.year + 1, 1, 1);
    }
  }

  DateTime previous(DateTime anchor) {
    switch (this) {
      case StatsPeriod.week:    return anchor.subtract(const Duration(days: 7));
      case StatsPeriod.month:   return DateTime(anchor.year, anchor.month - 1, 1);
      case StatsPeriod.quarter: return DateTime(anchor.year, anchor.month - 3, 1);
      case StatsPeriod.year:    return DateTime(anchor.year - 1, 1, 1);
    }
  }

  String formatAnchor(DateTime anchor) {
    switch (this) {
      case StatsPeriod.week:
        final r = range(anchor);
        final start = r.start;
        final end = r.end.subtract(const Duration(days: 1));
        final dayFmt = DateFormat('d', 'ru');
        final monthFmt = DateFormat('MMM', 'ru');
        if (start.month == end.month) {
          return '${dayFmt.format(start)}–${dayFmt.format(end)} ${monthFmt.format(start)}';
        }
        return '${dayFmt.format(start)} ${monthFmt.format(start)} – '
            '${dayFmt.format(end)} ${monthFmt.format(end)}';
      case StatsPeriod.month:
        return DateFormat('MMMM yyyy', 'ru').format(anchor);
      case StatsPeriod.quarter:
        final q = ((anchor.month - 1) ~/ 3) + 1;
        return 'Q$q ${anchor.year}';
      case StatsPeriod.year:
        return '${anchor.year}';
    }
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatsPeriod _period = StatsPeriod.month;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
  }

  bool get _isLatest {
    final nextStart = _period.next(_anchor);
    return !nextStart.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final r = _period.range(_anchor);
    final transactionsAsync = ref.watch(
      dateRangeTransactionsProvider(startDate: r.start, endDate: r.end),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PeriodSelector(
              selectedPeriod: _period,
              anchor: _anchor,
              isLatest: _isLatest,
              onPeriodChanged: (p) => setState(() {
                _period = p;
                _anchor = DateTime.now();
              }),
              onAnchorChanged: (a) => setState(() => _anchor = a),
            ),
            const SizedBox(height: 24),

            // Summary cards
            transactionsAsync.when(
              data: (transactions) => _StatisticsSummary(transactions: transactions),
              loading: () => const _StatisticsSummarySkeleton(),
              error: (error, stack) => ErrorRetryWidget(
                error: error.toString(),
                onRetry: () => ref.invalidate(
                  dateRangeTransactionsProvider(startDate: r.start, endDate: r.end),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bar chart
            Text('Доходы и расходы', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            transactionsAsync.when(
              data: (transactions) => _IncomeExpenseChart(
                transactions: transactions,
                period: _period,
                anchor: _anchor,
              ),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(height: 200),
            ),
            const SizedBox(height: 32),

            // Categories breakdown
            Text('Расходы по категориям', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) {
                final expenses = transactions
                    .where((t) => t.type == TransactionType.expense)
                    .toList();

                if (expenses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Нет расходов', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }

                final categoriesMap = <String, double>{};
                for (final t in expenses) {
                  final name = t.categories?['name'] as String? ?? 'Другое';
                  categoriesMap[name] = (categoriesMap[name] ?? 0) + t.amount;
                }

                final totalExpense = categoriesMap.values.fold(0.0, (a, b) => a + b);
                final sorted = categoriesMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  children: sorted.map((entry) => _CategoryBreakdownItem(
                    categoryName: entry.key,
                    amount: entry.value,
                    totalAmount: totalExpense,
                  )).toList(),
                );
              },
              loading: () => const _CategoriesBreakdownSkeleton(),
              error: (error, stack) => ErrorRetryWidget(
                error: error.toString(),
                compact: true,
                onRetry: () => ref.invalidate(
                  dateRangeTransactionsProvider(startDate: r.start, endDate: r.end),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _PeriodSelector
// ─────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.anchor,
    required this.isLatest,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  final StatsPeriod selectedPeriod;
  final DateTime anchor;
  final bool isLatest;
  final ValueChanged<StatsPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<StatsPeriod>(
          segments: StatsPeriod.values.map((p) => ButtonSegment<StatsPeriod>(
            value: p,
            label: Text(p.label),
          )).toList(),
          selected: {selectedPeriod},
          onSelectionChanged: (s) { if (s.isNotEmpty) onPeriodChanged(s.first); },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onAnchorChanged(selectedPeriod.previous(anchor)),
                ),
                Expanded(
                  child: Text(
                    selectedPeriod.formatAnchor(anchor),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isLatest ? null : () => onAnchorChanged(selectedPeriod.next(anchor)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// _IncomeExpenseChart
// ─────────────────────────────────────────────

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({
    required this.transactions,
    required this.period,
    required this.anchor,
  });

  final List<Transaction> transactions;
  final StatsPeriod period;
  final DateTime anchor;

  static const _incomeColor = Color(0xFF4CAF50);
  static const _expenseColor = Color(0xFFF44336);

  int _bucketIndex(DateTime date, DateTimeRange r) {
    switch (period) {
      case StatsPeriod.week:
        final diff = date.difference(r.start).inDays;
        return (diff < 0 || diff > 6) ? -1 : diff;
      case StatsPeriod.month:
        if (date.isBefore(r.start) || !date.isBefore(r.end)) return -1;
        return ((date.day - 1) ~/ 7).clamp(0, 4);
      case StatsPeriod.quarter:
        if (date.isBefore(r.start) || !date.isBefore(r.end)) return -1;
        return (date.month - r.start.month).clamp(0, 2);
      case StatsPeriod.year:
        if (date.year != r.start.year) return -1;
        return date.month - 1;
    }
  }

  int get _bucketCount {
    switch (period) {
      case StatsPeriod.week:    return 7;
      case StatsPeriod.month:
        final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
        return ((daysInMonth - 1) ~/ 7) + 1;
      case StatsPeriod.quarter: return 3;
      case StatsPeriod.year:    return 12;
    }
  }

  String _label(int i) {
    const days   = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];
    const months = ['Янв','Фев','Мар','Апр','Май','Июн','Июл','Авг','Сен','Окт','Ноя','Дек'];
    switch (period) {
      case StatsPeriod.week:    return days[i];
      case StatsPeriod.month:   return '${i + 1}н';
      case StatsPeriod.quarter:
        final start = ((anchor.month - 1) ~/ 3) * 3;
        return months[(start + i) % 12];
      case StatsPeriod.year:    return months[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = period.range(anchor);
    final count = _bucketCount;

    final income  = List<double>.filled(count, 0);
    final expense = List<double>.filled(count, 0);

    for (final t in transactions) {
      final idx = _bucketIndex(t.date, r);
      if (idx < 0 || idx >= count) continue;
      if (t.type == TransactionType.income)  income[idx]  += t.amount;
      if (t.type == TransactionType.expense) expense[idx] += t.amount;
    }

    final groups = List<BarChartGroupData>.generate(count, (i) => BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: income[i],
          color: _incomeColor,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        BarChartRodData(
          toY: expense[i],
          color: _expenseColor,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
      barsSpace: 3,
    ));

    final maxVal = [...income, ...expense].fold<double>(0, (p, v) => v > p ? v : p);
    final maxY   = maxVal > 0 ? maxVal * 1.25 : 1000.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 4,
                getTitlesWidget: (value, _) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _compact(value),
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= count) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _label(i),
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colorScheme.inverseSurface,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                '${rodIndex == 0 ? "Доход" : "Расход"}\n',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: _compact(rod.toY),
                    style: TextStyle(
                      color: rodIndex == 0 ? _incomeColor : _expenseColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}М';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}К';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────
// _StatisticsSummary
// ─────────────────────────────────────────────

class _StatisticsSummary extends StatelessWidget {
  const _StatisticsSummary({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
    final income   = transactions.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final expenses = transactions.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Доходы', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green)),
                  const SizedBox(height: 8),
                  Text(formatter.format(income), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.green)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Расходы', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red)),
                  const SizedBox(height: 8),
                  Text(formatter.format(expenses), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// _StatisticsSummarySkeleton
// ─────────────────────────────────────────────

class _StatisticsSummarySkeleton extends StatelessWidget {
  const _StatisticsSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget card() => Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 60, height: 14, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(width: 100, height: 20, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
    return Row(children: [card(), const SizedBox(width: 12), card()]);
  }
}

// ─────────────────────────────────────────────
// _CategoryBreakdownItem
// ─────────────────────────────────────────────

class _CategoryBreakdownItem extends StatelessWidget {
  const _CategoryBreakdownItem({
    required this.categoryName,
    required this.amount,
    required this.totalAmount,
  });

  final String categoryName;
  final double amount;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
    final progress  = totalAmount > 0 ? (amount / totalAmount).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(categoryName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
              Text(formatter.format(amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _CategoriesBreakdownSkeleton
// ─────────────────────────────────────────────

class _CategoriesBreakdownSkeleton extends StatelessWidget {
  const _CategoriesBreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(3, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 120, height: 16, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
                Container(width: 100, height: 16, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 8, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      )),
    );
  }
}
