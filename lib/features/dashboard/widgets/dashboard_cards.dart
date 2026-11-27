import 'package:material_ui/material_ui.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';

class WalletSummaryCard extends StatefulWidget {
  const WalletSummaryCard({
    required this.onAddFunds,
    required this.wallets,
    required this.walletPeriodTotals,
    required this.preferredWalletId,
    required this.walletSelectionKey,
    super.key,
  });

  final VoidCallback onAddFunds;
  final List<WalletRecord> wallets;
  final Map<int, ({int receivedMinor, int spentMinor, int activityMinor})>
  walletPeriodTotals;
  final int? preferredWalletId;
  final String walletSelectionKey;

  @override
  State<WalletSummaryCard> createState() => _WalletSummaryCardState();
}

class _WalletSummaryCardState extends State<WalletSummaryCard> {
  bool _hideBalance = false;
  int? _selectedWalletId;

  @override
  void didUpdateWidget(covariant WalletSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.preferredWalletId != oldWidget.preferredWalletId ||
            widget.walletSelectionKey != oldWidget.walletSelectionKey) &&
        widget.preferredWalletId != null) {
      _selectedWalletId = widget.preferredWalletId;
    }
  }

  @override
  Widget build(BuildContext context) {
    WalletRecord? selectedWallet;
    for (final wallet in widget.wallets) {
      if (wallet.id == _selectedWalletId) selectedWallet = wallet;
    }
    selectedWallet ??= widget.wallets.isEmpty ? null : widget.wallets.first;
    final walletTotals = selectedWallet == null
        ? (receivedMinor: 0, spentMinor: 0, activityMinor: 0)
        : widget.walletPeriodTotals[selectedWallet.id] ??
              (receivedMinor: 0, spentMinor: 0, activityMinor: 0);
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onSurface;
    final mutedForeground = colors.onSurfaceVariant;
    final surface = HesabTheme.summarySurface(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            PositionedDirectional(
              start: -12,
              bottom: -18,
              child: IgnorePointer(
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 150,
                  color: colors.primary.withValues(alpha: .055),
                ),
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
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 15,
                                color: colors.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'وارد کردن پول',
                                style: TextStyle(
                                  color: colors.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 108,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'کیف پول',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(
                              height: 28,
                              width: double.infinity,
                              child: selectedWallet == null
                                  ? Text(
                                      'کیف پولی موجود نیست',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: mutedForeground,
                                        fontSize: 10,
                                      ),
                                    )
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: selectedWallet.id,
                                        isDense: true,
                                        menuWidth: 128,
                                        alignment: AlignmentDirectional.centerEnd,
                                        style: TextStyle(
                                          color: mutedForeground,
                                          fontSize: 10,
                                        ),
                                        items: [
                                          for (final wallet in widget.wallets)
                                            DropdownMenuItem(
                                              value: wallet.id,
                                              child: Text(
                                                wallet.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (walletId) {
                                          if (walletId != null) {
                                            setState(
                                              () => _selectedWalletId = walletId,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'موجودی باقی‌مانده',
                    style: TextStyle(
                      color: mutedForeground,
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
                                    selectedWallet?.balanceMinor ?? 0,
                                  ),
                            style: TextStyle(
                              color: foreground,
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
                            color: colors.primary.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hideBalance
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 16,
                            color: colors.primary,
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
                          amountMinor: walletTotals.receivedMinor,
                          hideAmount: _hideBalance,
                          iconColor: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WalletMiniSummary(
                          icon: Icons.north_east_rounded,
                          title: 'مصرف شده',
                          amountMinor: walletTotals.spentMinor,
                          hideAmount: _hideBalance,
                          iconColor: colors.primary,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .72),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .1),
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
                    color: colors.onSurfaceVariant,
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
                    style: TextStyle(
                      color: colors.onSurface,
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
