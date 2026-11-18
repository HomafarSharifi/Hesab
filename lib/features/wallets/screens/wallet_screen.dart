import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({required this.services, super.key});
  final HesabServices services;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _revision = 0;

  Future<void> _newWallet() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _WalletNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.services.catalog.createWallet(name);
      if (mounted) setState(() => _revision++);
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _transaction(WalletRecord wallet, String type) async {
    final amount = await showDialog<String>(
      context: context,
      builder: (_) => _WalletAmountDialog(walletName: wallet.name, type: type),
    );
    if (amount == null) return;
    try {
      final minor = AmountCodec.parseMoneyMinor(amount);
      if (type == 'deposit') {
        await widget.services.transactions.deposit(
          walletId: wallet.id,
          date: DateTime.now(),
          amountMinor: minor,
        );
      } else {
        await widget.services.transactions.withdrawal(
          walletId: wallet.id,
          date: DateTime.now(),
          amountMinor: minor,
        );
      }
      if (mounted) setState(() => _revision++);
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _archive(WalletRecord wallet) async {
    try {
      await widget.services.catalog.archiveWallet(wallet.id);
      if (mounted) setState(() => _revision++);
    } catch (error) {
      _message(error);
    }
  }

  void _message(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<List<WalletRecord>>(
      key: ValueKey(_revision),
      future: widget.services.catalog.wallets(),
      builder: (context, snapshot) => Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: _newWallet,
                  icon: const Icon(Icons.add),
                  label: const Text('کیف پول تازه'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                  ? Center(child: Text('بارگذاری انجام نشد: ${snapshot.error}'))
                  : snapshot.data!.isEmpty
                  ? const Center(
                      child: Text(
                        'کیف پولی ثبت نشده است. برای آغاز، کیف پول تازه بسازید.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final wallet = snapshot.data![index];
                        final narrow = MediaQuery.sizeOf(context).width < 560;
                        final details = Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.name,
                                    style: const TextStyle(
                                      fontSize: HesabTheme.fontSection,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'موجودی: ${AmountCodec.formatMoneyMinor(wallet.balanceMinor)} افغانی',
                                    style: const TextStyle(
                                      fontSize: HesabTheme.fontBody,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                        final actions = Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => _transaction(wallet, 'deposit'),
                              child: const Text('واریز'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _transaction(wallet, 'withdrawal'),
                              child: const Text('برداشت'),
                            ),
                            IconButton(
                              tooltip: 'بایگانی',
                              onPressed: () => _archive(wallet),
                              icon: const Icon(Icons.archive_outlined),
                            ),
                          ],
                        );
                        return Card(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              12,
                              10,
                              12,
                              10,
                            ),
                            child: narrow
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      details,
                                      const SizedBox(height: 8),
                                      actions,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: details),
                                      const SizedBox(width: 8),
                                      actions,
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WalletNameDialog extends StatefulWidget {
  const _WalletNameDialog();
  @override
  State<_WalletNameDialog> createState() => _WalletNameDialogState();
}

class _WalletNameDialogState extends State<_WalletNameDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('کیف پول تازه'),
    content: TextField(
      controller: _name,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'نام',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text),
        child: const Text('ثبت'),
      ),
    ],
  );
}

class _WalletAmountDialog extends StatefulWidget {
  const _WalletAmountDialog({required this.walletName, required this.type});
  final String walletName;
  final String type;
  @override
  State<_WalletAmountDialog> createState() => _WalletAmountDialogState();
}

class _WalletAmountDialogState extends State<_WalletAmountDialog> {
  final _amount = TextEditingController();
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.type == 'deposit'
          ? 'واریز به ${widget.walletName}'
          : 'برداشت از ${widget.walletName}',
    ),
    content: TextField(
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'مبلغ به افغانی',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _amount.text),
        child: const Text('ثبت'),
      ),
    ],
  );
}
