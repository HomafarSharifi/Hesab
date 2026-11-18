import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
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
    return _DashboardData(
      balanceMinor: wallets.fold<int>(
        0,
        (sum, wallet) => sum + wallet.balanceMinor,
      ),
      spentMinor: report.totalExpenseMinor,
      receivedMinor: report.totalReceivedMinor,
      report: report,
    );
  }

  Widget _buildWithData(BuildContext context, _DashboardData? data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final horizontalPadding = (constraints.maxWidth * 0.035)
            .clamp(12.0, 48.0)
            .toDouble();
        final summaryHeight = (constraints.maxHeight * 0.285)
            .clamp(220.0, 370.0)
            .toDouble();
        final chartHeight = (constraints.maxHeight * 0.36)
            .clamp(270.0, 470.0)
            .toDouble();
        final contentWidth = constraints.maxWidth - horizontalPadding * 2;
        final sideBySideSummary = contentWidth >= 850;
        final sideBySideCharts = contentWidth >= 1000;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              compact ? 14 : 20,
              horizontalPadding,
              compact ? 20 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: compact ? 10 : 18),
                if (sideBySideSummary)
                  SizedBox(
                    height: summaryHeight,
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        Expanded(
                          flex: 44,
                          child: WalletSummaryCard(
                            onAddFunds: widget.onAddFunds,
                            balanceMinor: data?.balanceMinor,
                            spentMinor: data?.spentMinor,
                            receivedMinor: data?.receivedMinor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 56,
                          child: ExpenseSummaryCard(summary: data?.report),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    height: summaryHeight,
                    child: WalletSummaryCard(
                      onAddFunds: widget.onAddFunds,
                      balanceMinor: data?.balanceMinor,
                      spentMinor: data?.spentMinor,
                      receivedMinor: data?.receivedMinor,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: summaryHeight,
                    child: ExpenseSummaryCard(summary: data?.report),
                  ),
                ],
                SizedBox(height: compact ? 18 : 24),
                if (sideBySideCharts)
                  SizedBox(
                    height: chartHeight,
                    child: Row(
                      textDirection: TextDirection.ltr,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 68,
                          child: ExpenseTrendCard(
                            monthlyExpenses:
                                data?.report.expensesByMonth ?? const {},
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 32,
                          child: CategoryBreakdownCard(
                            categories:
                                data?.report.expenseByCategory ?? const {},
                            totalMinor: data?.report.totalExpenseMinor ?? 0,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    height: chartHeight,
                    child: ExpenseTrendCard(
                      monthlyExpenses: data?.report.expensesByMonth ?? const {},
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: chartHeight,
                    child: CategoryBreakdownCard(
                      categories: data?.report.expenseByCategory ?? const {},
                      totalMinor: data?.report.totalExpenseMinor ?? 0,
                    ),
                  ),
                ],
              ],
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
  });

  final int balanceMinor;
  final int spentMinor;
  final int receivedMinor;
  final ReportSummary report;
}
