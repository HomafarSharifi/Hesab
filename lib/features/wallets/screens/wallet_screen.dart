import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/finance/grouped_amount_input_formatter.dart';
import '../../../core/calendar/jalali_date.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/jalali_date_picker_dialog.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({required this.services, super.key});
  final HesabServices services;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _revision = 0;
  WalletRecord? _selected;
  bool _history = false;

  void _refresh() {
    if (mounted) setState(() => _revision++);
  }

  void _message(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
  );

  Future<void> _create() async {
    final input = await showDialog<_WalletInput>(
      context: context,
      builder: (_) =>
          const _WalletForm(title: 'کیف پول تازه', allowAmount: true),
    );
    if (input == null) return;
    try {
      final amount = input.amount.trim().isEmpty
          ? 0
          : AmountCodec.parseMoneyMinor(input.amount);
      await widget.services.transactions.createWalletWithInitialDeposit(
        walletName: input.name,
        amountMinor: amount,
        description: input.description,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('کیف پول ثبت شد.')));
      }
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _addMoney(WalletRecord wallet) async {
    final input = await showDialog<_WalletInput>(
      context: context,
      builder: (_) => const _WalletForm(
        title: 'افزودن پول',
        allowAmount: true,
        amountRequired: true,
      ),
    );
    if (input == null) return;
    try {
      final amount = AmountCodec.parseMoneyMinor(input.amount);
      await widget.services.transactions.deposit(
        walletId: wallet.id,
        date: input.date,
        amountMinor: amount,
        note: input.description,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('پول به کیف اضافه شد.')));
      }
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _withdraw(WalletRecord wallet) async {
    final input = await showDialog<_WalletInput>(
      context: context,
      builder: (_) => const _WalletForm(
        title: 'برداشت پول',
        allowAmount: true,
        amountRequired: true,
      ),
    );
    if (input == null) return;
    try {
      await widget.services.transactions.withdrawal(
        walletId: wallet.id,
        date: input.date,
        amountMinor: AmountCodec.parseMoneyMinor(input.amount),
        note: input.description,
      );
      _refresh();
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _edit(WalletRecord wallet) async {
    final input = await showDialog<_WalletInput>(
      context: context,
      builder: (_) => _WalletForm(
        title: 'ویرایش کیف پول',
        name: wallet.name,
        description: wallet.description,
      ),
    );
    if (input == null) return;
    try {
      await widget.services.transactions.updateWalletProfile(
        walletId: wallet.id,
        name: input.name,
        description: input.description,
      );
      _refresh();
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _archive(WalletRecord wallet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بایگانی کیف پول'),
        content: Text(
          '«${wallet.name}» بایگانی شود؟ سابقه و موجودی حفظ می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بایگانی'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.services.catalog.archiveWallet(wallet.id);
      setState(() {
        _selected = null;
        _history = false;
        _revision++;
      });
    } catch (error) {
      _message(error);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<List<WalletRecord>>(
      key: ValueKey(_revision),
      future: widget.services.catalog.wallets(),
      builder: (context, snapshot) {
        final wallets = snapshot.data ?? const <WalletRecord>[];
        final current = wallets.where((w) => w.id == _selected?.id).firstOrNull;
        if (_selected != null && current != null) _selected = current;
        if (_history && current != null) return _activityPage(current);
        if (current != null) return _details(current);
        return _walletList(snapshot, wallets);
      },
    ),
  );

  Widget _walletList(
    AsyncSnapshot<List<WalletRecord>> snapshot,
    List<WalletRecord> wallets,
  ) => Padding(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    child: snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            wallets.isEmpty
        ? AppEmptyState(
            illustration: 'wallets-empty',
            message: 'هنوز کیف پولی نساخته‌اید.',
            actionLabel: 'ساخت کیف پول',
            onAction: _create,
          )
        : Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'کیف پول‌ها',
                    style: TextStyle(
                      fontSize: HesabTheme.fontPageTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('کیف پول تازه'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                  ? Center(child: Text('بارگذاری انجام نشد: ${snapshot.error}'))
                  : ListView.separated(
                      itemCount: wallets.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final wallet = wallets[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 8,
                          ),
                          leading: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            wallet.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('ایجاد: ${_date(wallet.createdAt)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AmountCodec.formatMoneyMinor(
                                  wallet.balanceMinor,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => setState(() {
                            _selected = wallet;
                            _history = false;
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _details(
    WalletRecord wallet,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('detail-${wallet.id}-$_revision'),
    future: widget.services.transactions.walletActivities(wallet.id, limit: 3),
    builder: (context, snapshot) => _contentFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backHeader(
            'جزئیات کیف پول',
            onBack: () => setState(() {
              _selected = null;
              _history = false;
            }),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit(wallet);
                if (v == 'archive') _archive(wallet);
                if (v == 'withdraw') _withdraw(wallet);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('ویرایش کیف پول')),
                PopupMenuItem(value: 'withdraw', child: Text('برداشت پول')),
                PopupMenuItem(value: 'archive', child: Text('بایگانی کیف پول')),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            wallet.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'موجودی فعلی: ${AmountCodec.formatMoneyMinor(wallet.balanceMinor)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            'ایجاد: ${_date(wallet.createdAt)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _addMoney(wallet),
              icon: const Icon(Icons.add),
              label: const Text('افزودن پول'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'فعالیت‌های تازه',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _history = true),
                child: const Text('نمایش همه'),
              ),
            ],
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator()
          else if (snapshot.hasError)
            Text('بارگذاری انجام نشد: ${snapshot.error}')
          else if ((snapshot.data ?? []).isEmpty)
            const Text('هنوز فعالیتی ثبت نشده است.')
          else
            ...(snapshot.data ?? []).map((a) => _activityTile(a)),
        ],
      ),
    ),
  );

  Widget _activityPage(
    WalletRecord wallet,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('history-${wallet.id}-$_revision'),
    future: widget.services.transactions.walletActivities(wallet.id),
    builder: (context, snapshot) => _contentFrame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backHeader(
            'سابقه فعالیت',
            onBack: () => setState(() => _history = false),
          ),
          const SizedBox(height: 12),
          Text(
            wallet.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : snapshot.hasError
                ? Center(child: Text('بارگذاری انجام نشد: ${snapshot.error}'))
                : (snapshot.data ?? []).isEmpty
                ? const Center(child: Text('هنوز فعالیتی ثبت نشده است.'))
                : ListView.separated(
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _activityTile(snapshot.data![i]),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _activityTile(Map<String, Object?> a) {
    final type = a['event_type'] as String? ?? '';
    final label = switch (type) {
      'created' => 'کیف پول ایجاد شد',
      'deposit' =>
        (a['details'] == 'موجودی'
            ? 'پول آغازین افزوده شد'
            : 'پول افزوده شد'),
      'updated' => 'کیف پول ویرایش شد',
      'purchase' => 'خرید',
      'withdrawal' => 'برداشت پول',
      'reversal' => 'برگشت تراکنش',
      _ => 'فعالیت',
    };
    final amount = a['amount_minor'] as int?;
    final date =
        a['transaction_date'] as String? ?? a['occurred_at'] as String?;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        type == 'deposit'
            ? Icons.south_west
            : type == 'created'
            ? Icons.add_circle_outline
            : Icons.edit_outlined,
      ),
      title: Text(label),
      subtitle: Text(
        '${_date(date)}${(a['details'] as String?)?.isNotEmpty == true ? ' · ${a['details']}' : ''}',
      ),
      trailing: amount == null
          ? null
          : Text(
              '${type == 'deposit'
                  ? '+'
                  : type == 'purchase' || type == 'withdrawal'
                  ? '−'
                  : ''}${AmountCodec.formatMoneyMinor(amount)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(label),
          content: Text(
            [
              'تاریخ: ${_date(date)}',
              if (amount != null)
                'مبلغ: ${type == 'deposit'
                    ? '+'
                    : type == 'purchase' || type == 'withdrawal'
                    ? '−'
                    : ''}${AmountCodec.formatMoneyMinor(amount)}',
              if ((a['note'] as String?)?.isNotEmpty == true)
                'توضیحات: ${a['note']}',
              if ((a['details'] as String?)?.isNotEmpty == true)
                'جزئیات: ${a['details']}',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentFrame(Widget child) => Padding(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: child,
      ),
    ),
  );
  Widget _backHeader(
    String title, {
    required VoidCallback onBack,
    Widget? trailing,
  }) => Row(
    children: [
      IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_forward)),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      ?trailing,
    ],
  );
  String _date(String? value) {
    if (value == null || value.isEmpty) return '—';
    final d = DateTime.tryParse(value);
    return d == null ? value : JalaliDate.fromGregorian(d).fullDate;
  }
}

class _WalletInput {
  const _WalletInput(this.name, this.amount, this.description, this.date);
  final String name, amount;
  final String? description;
  final DateTime date;
}

class _WalletForm extends StatefulWidget {
  const _WalletForm({
    required this.title,
    this.name = '',
    this.description,
    this.allowAmount = false,
    this.amountRequired = false,
  });
  final String title, name;
  final String? description;
  final bool allowAmount, amountRequired;
  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _amount = TextEditingController();
  late final _description = TextEditingController(text: widget.description);
  DateTime _date = DateTime.now();
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final value = await showJalaliDatePicker(context, initialDate: _date);
    if (value != null && mounted) setState(() => _date = value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 390,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.amountRequired)
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 45,
                decoration: const InputDecoration(
                  labelText: 'نام کیف پول',
                  border: OutlineInputBorder(),
                ),
              ),
            if (widget.allowAmount) ...[
              if (!widget.amountRequired) const SizedBox(height: 10),
              TextField(
                controller: _amount,
                inputFormatters: const [GroupedAmountInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.amountRequired
                      ? 'مبلغ *'
                      : 'موجودی (اختیاری)',
                  suffixText: '؋',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (widget.amountRequired)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('تاریخ: ${_dateLabel(_date)}'),
                ),
              ),
            if (!widget.amountRequired) const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'توضیحات (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () {
                if (widget.amountRequired && _amount.text.trim().isEmpty) {
                  return;
                }
                if (!widget.amountRequired && _name.text.trim().isEmpty) {
                  return;
                }
                setState(() => _saving = true);
                Navigator.pop(
                  context,
                  _WalletInput(
                    _name.text.trim(),
                    _amount.text.trim(),
                    _description.text.trim().isEmpty
                        ? null
                        : _description.text.trim(),
                    _date,
                  ),
                );
              },
        child: const Text('ثبت'),
      ),
    ],
  );
  String _dateLabel(DateTime d) => JalaliDate.fromGregorian(d).fullDate;
}
