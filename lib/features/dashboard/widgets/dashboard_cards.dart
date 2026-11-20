import 'package:material_ui/material_ui.dart';

import '../../../core/theme/hesab_theme.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../data/models/financial_models.dart';

class WalletSummaryCard extends StatefulWidget {
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
  State<WalletSummaryCard> createState() => _WalletSummaryCardState();
}

class _WalletSummaryCardState extends State<WalletSummaryCard> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primary = colors.primary;
    final primaryDark = Color.lerp(primary, Colors.black, .52)!;
    final accent = colors.tertiary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            primary,
            primaryDark,
            Color.lerp(primaryDark, Colors.black, .24)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              left: -45,
              top: -45,
              child: _WalletOrb(
                size: 170,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
            Positioned(
              left: 25,
              bottom: -70,
              child: _WalletOrb(
                size: 180,
                color: accent.withValues(alpha: .09),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      InkWell(
                        onTap: widget.onAddFunds,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 15, color: colors.onTertiary),
                              const SizedBox(width: 4),
                              Text(
                                'وارد کردن پول',
                                style: TextStyle(
                                  color: colors.onTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'کیف پول',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'شریفی',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 9),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'موجودی باقی‌مانده',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _hideBalance
                                ? '•••••• ؋'
                                : AmountCodec.formatMoneyMinor(
                                    widget.balanceMinor ?? 0,
                                  ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            setState(() => _hideBalance = !_hideBalance),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hideBalance
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: .9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      Expanded(
                        child: _WalletMiniSummary(
                          icon: Icons.south_west_rounded,
                          title: 'دریافتی',
                          amountMinor: widget.receivedMinor,
                          hideAmount: _hideBalance,
                          iconColor: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WalletMiniSummary(
                          icon: Icons.north_east_rounded,
                          title: 'مصرف شده',
                          amountMinor: widget.spentMinor,
                          hideAmount: _hideBalance,
                          iconColor: accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletOrb extends StatelessWidget {
  const _WalletOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _WalletMiniSummary extends StatelessWidget {
  const _WalletMiniSummary({
    required this.icon,
    required this.title,
    required this.amountMinor,
    required this.hideAmount,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final int? amountMinor;
  final bool hideAmount;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 9,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    hideAmount
                        ? '•••• ؋'
                        : (amountMinor == null
                              ? '—'
                              : AmountCodec.formatMoneyMinor(amountMinor!)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
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
    final colors = Theme.of(context).colorScheme;
    return _SummaryCard(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'خلاصه مصارف',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ExpenseMetric(
                  value: summary == null
                      ? '—'
                      : AmountCodec.formatMoneyMinor(
                          summary!.totalExpenseMinor,
                        ),
                  label: 'مجموع مصارف',
                ),
                Divider(height: 1, color: colors.outlineVariant),
                _ExpenseMetric(
                  value: summary?.mostPurchasedItem ?? '—',
                  label: 'پرمصرف‌ترین جنس',
                ),
                Divider(height: 1, color: colors.outlineVariant),
                _ExpenseMetric(
                  value: summary?.highestPurchaseMinor == null
                      ? '—'
                      : AmountCodec.formatMoneyMinor(
                          summary!.highestPurchaseMinor!,
                        ),
                  label: 'گران‌ترین خرید',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseMetric extends StatelessWidget {
  const _ExpenseMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: HesabTheme.fontBody,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: HesabTheme.fontSection,
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 20),
    child: child,
  );
}
