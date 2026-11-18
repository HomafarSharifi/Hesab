import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/financial_models.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    required this.services,
    required this.fromDate,
    required this.toDate,
    super.key,
  });
  final HesabServices services;
  final DateTime fromDate;
  final DateTime? toDate;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<ReportSummary>(
      future: services.reports.summary(fromDate: fromDate, toDate: toDate),
      builder: (context, snapshot) => Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        ),
        child: snapshot.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : snapshot.hasError
            ? Center(child: Text('گزارش آماده نشد: ${snapshot.error}'))
            : _ReportContent(summary: snapshot.data!),
      ),
    ),
  );
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.summary});
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categories = summary.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final months = summary.expensesByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              title: 'مجموع مصارف',
              value: AmountCodec.formatMoneyMinor(summary.totalExpenseMinor),
            ),
            _MetricCard(
              title: 'مجموع عواید',
              value: AmountCodec.formatMoneyMinor(summary.totalReceivedMinor),
            ),
            _MetricCard(
              title: 'تعداد خریدها',
              value: summary.purchaseCount.toString(),
            ),
            _MetricCard(
              title: 'بیشترین خرید',
              value: summary.highestPurchaseMinor == null
                  ? '—'
                  : AmountCodec.formatMoneyMinor(summary.highestPurchaseMinor!),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 680;
              final categoryList = _ReportList(
                title: 'مصارف بر اساس دسته‌بندی',
                empty: 'دسته‌بندی موجود نیست.',
                children: [
                  for (final entry in categories)
                    _ReportRow(
                      label: entry.key,
                      value: AmountCodec.formatMoneyMinor(entry.value),
                    ),
                ],
              );
              final monthList = _ReportList(
                title: 'مصارف ماهانه (تقویم جلالی)',
                empty: 'معلومات ماهانه موجود نیست.',
                children: [
                  for (final entry in months)
                    _ReportRow(
                      label: entry.key,
                      value: AmountCodec.formatMoneyMinor(entry.value),
                    ),
                ],
              );
              return narrow
                  ? Column(
                      children: [
                        Expanded(child: categoryList),
                        const SizedBox(height: 12),
                        Expanded(child: monthList),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: categoryList),
                        const SizedBox(width: 12),
                        Expanded(child: monthList),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'گزارش بر بنیاد تراکنش‌های ثبت‌شده ساخته شده است.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: HesabTheme.fontCaption,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600
        ? ((MediaQuery.sizeOf(context).width - 48) / 2).clamp(100.0, 210.0)
        : 210,
    height: 96,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: HesabTheme.fontBody)),
            const Spacer(),
            FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: HesabTheme.fontSection,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.title,
    required this.empty,
    required this.children,
  });
  final String title;
  final String empty;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: HesabTheme.fontSection,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: children.isEmpty
                ? Center(child: Text(empty))
                : ListView(children: children),
          ),
        ],
      ),
    ),
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label, style: const TextStyle(fontSize: HesabTheme.fontBody)),
    trailing: Text(
      value,
      style: const TextStyle(fontSize: HesabTheme.fontCaption),
    ),
  );
}
