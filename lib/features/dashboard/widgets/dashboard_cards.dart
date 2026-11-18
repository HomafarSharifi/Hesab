import 'package:material_ui/material_ui.dart';

import '../../../core/theme/hesab_theme.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../data/models/financial_models.dart';

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({
    required this.onAddFunds,
    required this.balanceMinor,
    required this.spentMinor,
    required this.receivedMinor,
    super.key,
  });

  final VoidCallback onAddFunds;
  final int? balanceMinor;
  final int? spentMinor;
  final int? receivedMinor;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      color: HesabTheme.summarySurface(context),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 20,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 150,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAddFunds,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('وارد کردن پول'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide.none,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        9,
                        15,
                        9,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'موجودی حساب:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: HesabTheme.fontSection,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  balanceMinor == null
                      ? '—'
                      : AmountCodec.formatMoneyMinor(balanceMinor!),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: MediaQuery.sizeOf(context).width < 600
                        ? 28
                        : HesabTheme.fontAmount,
                    height: 1,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(
                    child: _WalletMiniSummary(
                      icon: Icons.remove_red_eye_outlined,
                      title: 'مصرف شده',
                      amountMinor: spentMinor,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _WalletMiniSummary(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'دریافت شده',
                      amountMinor: receivedMinor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletMiniSummary extends StatelessWidget {
  const _WalletMiniSummary({
    required this.icon,
    required this.title,
    required this.amountMinor,
  });

  final IconData icon;
  final String title;
  final int? amountMinor;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground.withValues(alpha: 0.62)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 15, color: foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            amountMinor == null
                ? '—'
                : AmountCodec.formatMoneyMinor(amountMinor!),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({required this.summary, super.key});

  final ReportSummary? summary;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مجموع مصارف:',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: HesabTheme.fontSection),
          ),
          const SizedBox(height: 12),
          Text(
            summary == null
                ? '—'
                : AmountCodec.formatMoneyMinor(summary!.totalExpenseMinor),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 600
                  ? 28
                  : HesabTheme.fontAmount,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              Expanded(
                child: _ExpenseMetric(
                  value: summary?.highestPurchaseMinor == null
                      ? '—'
                      : AmountCodec.formatMoneyMinor(
                          summary!.highestPurchaseMinor!,
                        ),
                  label: 'گران‌ترین خرید',
                  detail: summary == null ? 'داده موجود نیست' : 'افغانی',
                ),
              ),
              Expanded(
                child: _ExpenseMetric(
                  value: summary?.mostPurchasedItem ?? '—',
                  label: 'پرمصرف‌ترین جنس',
                  detail: summary == null
                      ? 'داده موجود نیست'
                      : 'بر بنیاد تعداد خرید',
                ),
              ),
              Expanded(
                child: _ExpenseMetric(
                  value: summary?.purchaseCount.toString() ?? '—',
                  label: 'خرید ثبت شده',
                  detail: summary == null ? 'داده موجود نیست' : 'خرید',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseMetric extends StatelessWidget {
  const _ExpenseMetric({
    required this.value,
    required this.label,
    required this.detail,
  });

  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: HesabTheme.fontSection, color: secondary),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: HesabTheme.fontBody, color: secondary),
        ),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: HesabTheme.fontCaption,
            color: secondary.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 20),
    child: child,
  );
}
