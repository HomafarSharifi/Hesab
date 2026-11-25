import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_charts.dart';
import '../../shared/widgets/app_empty_state.dart';

class DashboardScreen extends StatefulWidget {
  static const pageInset = 10.0;

  const DashboardScreen({
    required this.services,
    required this.onAddFunds,
    required this.onCreateWallet,
    required this.onCreatePurchase,
    required this.fromDate,
    required this.toDate,
    required this.selectedPeriod,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onAddFunds;
  final VoidCallback onCreateWallet;
  final VoidCallback onCreatePurchase;
  final DateTime fromDate;
  final DateTime? toDate;
  final int selectedPeriod;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      key: ValueKey('${widget.fromDate}-${widget.toDate}'),
      future: _loadData(),
      builder: (context, snapshot) => _buildWithData(context, snapshot.data),
    );
  }

  Future<_DashboardData> _loadData() async {
    final wallets = await widget.services.catalog.wallets();
    final walletPeriodTotals = await widget.services.reports.walletPeriodTotals(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
    final report = await widget.services.reports.summary(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
    final items = await widget.services.catalog.items();
    final dailyExpenses = await widget.services.reports.expensesByDate(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
    int? preferredWalletId;
    if (widget.selectedPeriod == 2) {
      var highestActivityMinor = 0;
      for (final wallet in wallets) {
        final totals = walletPeriodTotals[wallet.id];
        final activityMinor = totals?.activityMinor ?? 0;
        if (activityMinor > highestActivityMinor) {
          highestActivityMinor = activityMinor;
          preferredWalletId = wallet.id;
        }
      }
    }
    return _DashboardData(
      hasWallets: wallets.isNotEmpty,
      wallets: wallets,
      walletPeriodTotals: walletPeriodTotals,
      preferredWalletId: preferredWalletId,
      report: report,
      items: items,
      dailyExpenses: dailyExpenses,
    );
  }

  Widget _buildWithData(BuildContext context, _DashboardData? data) {
    if (data != null &&
        (!data.hasWallets || data.report.purchaseCount == 0)) {
      final hasWallets = data.hasWallets;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AppEmptyState(
          illustration: hasWallets ? 'dashboard-empty' : 'wallets-empty',
          message: hasWallets
              ? 'هنوز خریدی ثبت نشده است.'
              : 'هنوز کیف پولی نساخته‌اید.',
          actionLabel: hasWallets ? 'ثبت خرید' : 'ساخت کیف پول',
          onAction: hasWallets
              ? widget.onCreatePurchase
              : widget.onCreateWallet,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const minimumStageWidth = 1040.0;
        const minimumStageHeight = 560.0;
        final stageWidth = math.max(constraints.maxWidth, minimumStageWidth);
        final widthScale = (constraints.maxWidth / stageWidth)
            .clamp(0.0, 1.0)
            .toDouble();
        final stageHeight = math.max(
          minimumStageHeight,
          widthScale > 0
              ? constraints.maxHeight / widthScale
              : minimumStageHeight,
        );

        return Directionality(
          textDirection: TextDirection.rtl,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: stageWidth,
                height: stageHeight,
                child: Padding(
                  padding: const EdgeInsets.all(DashboardScreen.pageInset),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 48,
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 28,
                              child: WalletSummaryCard(
                                onAddFunds: widget.onAddFunds,
                                wallets: data?.wallets ?? const [],
                                walletPeriodTotals:
                                    data?.walletPeriodTotals ?? const {},
                                preferredWalletId: data?.preferredWalletId,
                                walletSelectionKey:
                                    '${widget.selectedPeriod}-${widget.fromDate}-${widget.toDate}',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 32,
                              child: ReferenceCategoryBreakdownCard(
                                categories:
                                    data?.report.expenseByCategory ?? const {},
                                purchaseCounts:
                                    data?.report.purchaseCountByCategory ??
                                    const {},
                                totalMinor: data?.report.totalExpenseMinor ?? 0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 40,
                              child: ExpenseTrendCard(
                                monthlyExpenses:
                                    data?.report.expensesByMonth ?? const {},
                                dailyExpenses: data?.dailyExpenses ?? const {},
                                fromDate: widget.fromDate,
                                toDate: widget.toDate,
                                selectedPeriod: widget.selectedPeriod,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        flex: 52,
                        child: Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 32,
                              child: ExpenseSummaryCard(summary: data?.report),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 68,
                              child: ItemExpenseTrendCard(
                                items: data?.items ?? const [],
                                loadYearlyExpenses:
                                    widget.services.reports.itemExpensesByYear,
                                fromDate: widget.fromDate,
                                selectedPeriod: widget.selectedPeriod,
                                loadMonthlyExpenses:
                                    widget.services.reports.itemExpensesByMonth,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.hasWallets,
    required this.wallets,
    required this.walletPeriodTotals,
    required this.preferredWalletId,
    required this.report,
    required this.items,
    required this.dailyExpenses,
  });

  final bool hasWallets;
  final List<WalletRecord> wallets;
  final Map<int, ({int receivedMinor, int spentMinor, int activityMinor})>
  walletPeriodTotals;
  final int? preferredWalletId;
  final ReportSummary report;
  final List<ItemRecord> items;
  final Map<String, int> dailyExpenses;
}
