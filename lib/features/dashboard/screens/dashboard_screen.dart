import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_charts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.services,
    required this.onAddFunds,
    required this.fromDate,
    required this.toDate,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onAddFunds;
  final DateTime fromDate;
  final DateTime? toDate;

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
    final report = await widget.services.reports.summary(
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
    final items = await widget.services.catalog.items();
    return _DashboardData(
      balanceMinor: wallets.fold<int>(
        0,
        (sum, wallet) => sum + wallet.balanceMinor,
      ),
      spentMinor: report.totalExpenseMinor,
      receivedMinor: report.totalReceivedMinor,
      report: report,
      items: items,
    );
  }

  Widget _buildWithData(BuildContext context, _DashboardData? data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The design canvas preserves the reference proportions. FittedBox
        // scales that canvas to the shell's available window without scrolling.
        final stageWidth = math.max(constraints.maxWidth, 1040.0);
        final stageHeight = math.max(constraints.maxHeight, 560.0);

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
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 48,
                        child: Row(
                          textDirection: TextDirection.ltr,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 37,
                              child: WalletSummaryCard(
                                onAddFunds: widget.onAddFunds,
                                balanceMinor: data?.balanceMinor,
                                spentMinor: data?.spentMinor,
                                receivedMinor: data?.receivedMinor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 63,
                              child: ItemExpenseTrendCard(
                                items: data?.items ?? const [],
                                loadMonthlyExpenses:
                                    widget.services.reports.itemExpensesByMonth,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        flex: 52,
                        child: Row(
                          textDirection: TextDirection.ltr,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 40,
                              child: ExpenseTrendCard(
                                monthlyExpenses:
                                    data?.report.expensesByMonth ?? const {},
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
                              flex: 28,
                              child: ExpenseSummaryCard(summary: data?.report),
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
    required this.balanceMinor,
    required this.spentMinor,
    required this.receivedMinor,
    required this.report,
    required this.items,
  });

  final int balanceMinor;
  final int spentMinor;
  final int receivedMinor;
  final ReportSummary report;
  final List<ItemRecord> items;
}
