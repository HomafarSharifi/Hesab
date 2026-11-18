import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/text/name_normalizer.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../../shared/widgets/jalali_date_picker_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.services,
    required this.fromDate,
    required this.toDate,
    super.key,
  });

  final HesabServices services;
  final DateTime fromDate;
  final DateTime? toDate;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  int? _walletFilter;
  String? _categoryFilter;
  int _revision = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _newPurchase() async {
    try {
      final wallets = await widget.services.catalog.wallets();
      final results = await Future.wait<Object>([
        widget.services.catalog.items(),
        widget.services.catalog.categories(),
        widget.services.catalog.units(),
      ]);
      if (!mounted) return;
      if (wallets.isEmpty) {
        _message('برای ثبت خرید، نخست از بخش کیف پول یک کیف پول بسازید.');
        return;
      }
      final input = await showDialog<_PurchaseInput>(
        context: context,
        builder: (_) => _PurchaseDialog(
          wallets: wallets,
          items: results[0] as List<ItemRecord>,
          categories: results[1] as List<CategoryRecord>,
          units: results[2] as List<UnitRecord>,
        ),
      );
      if (input == null) return;
      await widget.services.transactions.purchaseWithNewProduct(
        walletId: input.walletId,
        productName: input.productName,
        categoryId: input.categoryId,
        newCategoryName: input.newCategoryName,
        unitId: input.unitId,
        newUnitName: input.newUnitName,
        date: input.date,
        quantityCenti: AmountCodec.parseQuantityCenti(input.quantity),
        unitPriceMinor: AmountCodec.parseMoneyMinor(input.unitPrice),
        note: input.note,
      );
      if (mounted) setState(() => _revision++);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<List<ExpenseRecord>> _loadExpenses() =>
      widget.services.transactions.expenses(
        normalizedSearch: _search,
        walletId: _walletFilter,
        categoryName: _categoryFilter,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

  Future<void> _showFilters() async {
    try {
      final data = await Future.wait<Object>([
        widget.services.catalog.categories(),
        widget.services.catalog.wallets(),
      ]);
      if (!mounted) return;
      final result = await showDialog<_ExpenseFilters>(
        context: context,
        builder: (context) => _ExpenseFilterDialog(
          categories: data[0] as List<CategoryRecord>,
          wallets: data[1] as List<WalletRecord>,
          initialCategory: _categoryFilter,
          initialWallet: _walletFilter,
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _categoryFilter = result.categoryName;
        _walletFilter = result.walletId;
      });
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _reverse(ExpenseRecord expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('برگشت خرید'),
        content: Text(
          'مبلغ خرید «${expense.itemName}» به کیف پول برگردانده شود؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('برگشت مبلغ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.services.transactions.reverse(
        transactionId: expense.transactionId,
        date: DateTime.now(),
        note: 'برگشت خرید ${expense.itemName}',
      );
      if (mounted) setState(() => _revision++);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(ExpenseRecord expense) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense.itemName),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailLine('تاریخ', _dateLabel(expense.date)),
              _DetailLine('دسته‌بندی', expense.categoryName),
              _DetailLine('کیف پول', expense.walletName),
              _DetailLine(
                'مقدار',
                '${AmountCodec.formatQuantityCenti(expense.quantityCenti)} ${expense.unitName}',
              ),
              _DetailLine(
                'قیمت هر واحد',
                AmountCodec.formatMoneyMinor(expense.unitPriceMinor),
              ),
              _DetailLine(
                'مجموع',
                AmountCodec.formatMoneyMinor(expense.amountMinor),
              ),
              if (expense.note != null && expense.note!.trim().isNotEmpty)
                _DetailLine('یادداشت', expense.note!),
              if (expense.isReversed) const _DetailLine('وضعیت', 'برگشت‌شده'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  String _dateLabel(String date) =>
      JalaliDate.fromGregorian(DateTime.parse(date)).fullDate;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        16,
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: HesabTheme.controlHeight,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'فلتر دسته‌بندی و کیف پول',
                        onPressed: _showFilters,
                        color: _categoryFilter != null || _walletFilter != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        icon: const Icon(Icons.filter_list_rounded),
                      ),
                      hintText: 'جستجوی جنس…',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _newPurchase,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('ثبت خرید'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<ExpenseRecord>>(
              key: ValueKey(
                '$_revision-$_search-$_categoryFilter-$_walletFilter-'
                '${widget.fromDate}-${widget.toDate}',
              ),
              future: _loadExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'بارگذاری معلومات انجام نشد: ${snapshot.error}',
                    ),
                  );
                }
                final expenses = snapshot.data ?? const <ExpenseRecord>[];
                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _search.isEmpty &&
                                  _categoryFilter == null &&
                                  _walletFilter == null
                              ? 'در این دوره خریدی ثبت نشده است.'
                              : 'نتیجه‌ای برای جستجو پیدا نشد.',
                          style: TextStyle(
                            fontSize: HesabTheme.fontBody,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _ExpensesTable(
                  expenses: expenses,
                  dateLabel: _dateLabel,
                  onDetails: _showDetails,
                  onReverse: _reverse,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExpenseFilters {
  const _ExpenseFilters({this.categoryName, this.walletId});

  final String? categoryName;
  final int? walletId;
}

class _ExpenseFilterDialog extends StatefulWidget {
  const _ExpenseFilterDialog({
    required this.categories,
    required this.wallets,
    required this.initialCategory,
    required this.initialWallet,
  });

  final List<CategoryRecord> categories;
  final List<WalletRecord> wallets;
  final String? initialCategory;
  final int? initialWallet;

  @override
  State<_ExpenseFilterDialog> createState() => _ExpenseFilterDialogState();
}

class _ExpenseFilterDialogState extends State<_ExpenseFilterDialog> {
  late String _categoryName = widget.initialCategory ?? '';
  late int _walletId = widget.initialWallet ?? 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('فلتر مصارف'),
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _categoryName,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'دسته‌بندی'),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('همه دسته‌بندی‌ها'),
              ),
              for (final category in widget.categories)
                DropdownMenuItem<String>(
                  value: category.name,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryName = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _walletId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'کیف پول'),
            items: [
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('همه کیف پول‌ها'),
              ),
              for (final wallet in widget.wallets)
                DropdownMenuItem<int>(
                  value: wallet.id,
                  child: Text(wallet.name),
                ),
            ],
            onChanged: (value) => setState(() => _walletId = value ?? 0),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, const _ExpenseFilters()),
        child: const Text('پاک‌کردن فلتر'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _ExpenseFilters(
            categoryName: _categoryName.isEmpty ? null : _categoryName,
            walletId: _walletId == 0 ? null : _walletId,
          ),
        ),
        child: const Text('تطبیق'),
      ),
    ],
  );
}

class _ExpensesTable extends StatelessWidget {
  const _ExpensesTable({
    required this.expenses,
    required this.dateLabel,
    required this.onDetails,
    required this.onReverse,
  });

  final List<ExpenseRecord> expenses;
  final String Function(String date) dateLabel;
  final ValueChanged<ExpenseRecord> onDetails;
  final ValueChanged<ExpenseRecord> onReverse;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          color: HesabTheme.selectionSurface(context),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
          child: const Row(
            children: [
              Expanded(flex: 12, child: Text('تاریخ')),
              Expanded(flex: 18, child: Text('جنس')),
              Expanded(flex: 16, child: Text('دسته‌بندی')),
              Expanded(flex: 14, child: Text('کیف پول')),
              Expanded(flex: 14, child: Text('مقدار')),
              Expanded(flex: 17, child: Text('مجموع')),
              SizedBox(width: 72, child: Text('عملیات')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: expenses.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 14, 5),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 12,
                        child: _CellText(dateLabel(expense.date)),
                      ),
                      Expanded(
                        flex: 18,
                        child: _CellText(expense.itemName, strong: true),
                      ),
                      Expanded(
                        flex: 16,
                        child: _CellText(expense.categoryName),
                      ),
                      Expanded(flex: 14, child: _CellText(expense.walletName)),
                      Expanded(
                        flex: 14,
                        child: _CellText(
                          '${AmountCodec.formatQuantityCenti(expense.quantityCenti)} ${expense.unitName}',
                        ),
                      ),
                      Expanded(
                        flex: 17,
                        child: _CellText(
                          AmountCodec.formatMoneyMinor(expense.amountMinor),
                          strong: true,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'جزئیات',
                              visualDensity: VisualDensity.compact,
                              iconSize: 17,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              onPressed: () => onDetails(expense),
                              icon: const Icon(Icons.info_outline_rounded),
                            ),
                            if (expense.isReversed)
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 17,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                            else
                              IconButton(
                                tooltip: 'برگشت خرید',
                                visualDensity: VisualDensity.compact,
                                iconSize: 17,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                onPressed: () => onReverse(expense),
                                icon: const Icon(Icons.undo_rounded),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _CellText extends StatelessWidget {
  const _CellText(this.value, {this.strong = false});
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: HesabTheme.fontCaption,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}

class _PurchaseInput {
  const _PurchaseInput({
    required this.walletId,
    required this.productName,
    required this.categoryId,
    required this.newCategoryName,
    required this.unitId,
    required this.newUnitName,
    required this.date,
    required this.quantity,
    required this.unitPrice,
    required this.note,
  });

  final int walletId;
  final String productName;
  final int? categoryId;
  final String? newCategoryName;
  final int? unitId;
  final String? newUnitName;
  final DateTime date;
  final String quantity;
  final String unitPrice;
  final String? note;
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({
    required this.wallets,
    required this.items,
    required this.categories,
    required this.units,
  });

  final List<WalletRecord> wallets;
  final List<ItemRecord> items;
  final List<CategoryRecord> categories;
  final List<UnitRecord> units;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _note = TextEditingController();
  int? _walletId;
  int? _categoryChoice;
  int? _unitChoice;
  ItemRecord? _selectedItem;
  String? _newCategoryName;
  String? _newUnitName;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _totalMinor {
    try {
      return AmountCodec.calculatePurchaseTotalMinor(
        quantityCenti: AmountCodec.parseQuantityCenti(_quantity.text),
        unitPriceMinor: AmountCodec.parseMoneyMinor(_price.text),
      );
    } on Object {
      return null;
    }
  }

  List<ItemRecord> get _suggestions {
    if (_selectedItem != null || _name.text.trim().isEmpty) return const [];
    final names = NameNormalizer.suggestions(
      _name.text,
      widget.items.map((item) => item.name),
      limit: 4,
    ).map(NameNormalizer.normalize).toSet();
    return widget.items
        .where((item) => names.contains(NameNormalizer.normalize(item.name)))
        .take(4)
        .toList();
  }

  Future<void> _chooseDate() async {
    final selected = await showJalaliDatePicker(context, initialDate: _date);
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _chooseNewCategory() async {
    final name = await _askForName('دسته‌بندی تازه');
    if (name != null && mounted) {
      setState(() {
        _categoryChoice = -1;
        _newCategoryName = name;
      });
    }
  }

  Future<void> _chooseNewUnit() async {
    final name = await _askForName('واحد تازه');
    if (name != null && mounted) {
      setState(() {
        _unitChoice = -1;
        _newUnitName = name;
      });
    }
  }

  Future<String?> _askForName(String title) => showDialog<String>(
    context: context,
    builder: (_) => _InlineNameDialog(title: title),
  );

  void _useExistingItem(ItemRecord item) {
    setState(() {
      _selectedItem = item;
      _name.text = item.name;
      _categoryChoice = item.categoryId;
      _unitChoice = item.unitId;
      _newCategoryName = null;
      _newUnitName = null;
    });
  }

  void _submit() {
    final productName = _name.text.trim();
    if (_walletId == null || productName.isEmpty) return;
    if (_categoryChoice == null || _unitChoice == null) return;
    Navigator.pop(
      context,
      _PurchaseInput(
        walletId: _walletId!,
        productName: productName,
        categoryId: _categoryChoice == -1 ? null : _categoryChoice,
        newCategoryName: _newCategoryName,
        unitId: _unitChoice == -1 ? null : _unitChoice,
        newUnitName: _newUnitName,
        date: _date,
        quantity: _quantity.text,
        unitPrice: _price.text,
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 540;
    final suggestions = _suggestions;
    final total = _totalMinor;
    final selectedProduct = _selectedItem != null;
    final canSave =
        _walletId != null &&
        _name.text.trim().isNotEmpty &&
        _categoryChoice != null &&
        _unitChoice != null &&
        total != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('ثبت خرید'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width < 560
              ? MediaQuery.sizeOf(context).width - 80
              : 490,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 640),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _responsivePair(
                    _dateButton(),
                    _walletDropdown(),
                    narrow: narrow,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    onChanged: (value) {
                      if (_selectedItem != null &&
                          NameNormalizer.normalize(value) !=
                              NameNormalizer.normalize(_selectedItem!.name)) {
                        setState(() => _selectedItem = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'نام جنس',
                      hintText: 'نام جنس را وارد یا جستجو کنید',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final item in suggestions)
                            ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.categoryName} • ${item.unitName}',
                              ),
                              onTap: () => _useExistingItem(item),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  _responsivePair(
                    _categoryDropdown(enabled: !selectedProduct),
                    _unitDropdown(enabled: !selectedProduct),
                    narrow: narrow,
                  ),
                  const SizedBox(height: 10),
                  _responsivePair(
                    TextField(
                      controller: _quantity,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'مقدار',
                        hintText: 'تا دو رقم اعشار',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextField(
                      controller: _price,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'قیمت هر واحد',
                        suffixText: '؋',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    narrow: narrow,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: HesabTheme.selectionSurface(context)
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'مجموع خرید',
                          style: TextStyle(fontSize: HesabTheme.fontBody),
                        ),
                        const Spacer(),
                        Text(
                          total == null
                              ? '—'
                              : AmountCodec.formatMoneyMinor(total),
                          style: const TextStyle(
                            fontSize: HesabTheme.fontControl,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'یادداشت (اختیاری)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: canSave ? _submit : null,
            child: const Text('ثبت خرید'),
          ),
        ],
      ),
    );
  }

  Widget _responsivePair(Widget first, Widget second, {required bool narrow}) =>
      narrow
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        )
      : Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );

  Widget _dateButton() => OutlinedButton.icon(
    onPressed: _chooseDate,
    icon: const Icon(Icons.calendar_month_rounded, size: 18),
    label: Text(
      JalaliDate.fromGregorian(_date).fullDate,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _walletDropdown() => DropdownButtonFormField<int>(
    initialValue: _walletId,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'کیف پول',
      border: OutlineInputBorder(),
    ),
    items: widget.wallets
        .map(
          (wallet) => DropdownMenuItem(
            value: wallet.id,
            child: Text(wallet.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (value) => setState(() => _walletId = value),
  );

  Widget _categoryDropdown({required bool enabled}) =>
      DropdownButtonFormField<int>(
        initialValue: _categoryChoice,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'دسته‌بندی',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final category in widget.categories)
            DropdownMenuItem(value: category.id, child: Text(category.name)),
          DropdownMenuItem(
            value: -1,
            child: Text(
              _newCategoryName == null
                  ? 'دسته‌بندی تازه…'
                  : 'تازه: $_newCategoryName',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: !enabled
            ? null
            : (value) async {
                if (value == -1) {
                  await _chooseNewCategory();
                } else {
                  setState(() {
                    _categoryChoice = value;
                    _newCategoryName = null;
                  });
                }
              },
      );

  Widget _unitDropdown({required bool enabled}) => DropdownButtonFormField<int>(
    initialValue: _unitChoice,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'واحد',
      border: OutlineInputBorder(),
    ),
    items: [
      for (final unit in widget.units)
        DropdownMenuItem(value: unit.id, child: Text(unit.name)),
      DropdownMenuItem(
        value: -1,
        child: Text(
          _newUnitName == null ? 'واحد تازه…' : 'تازه: $_newUnitName',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
    onChanged: !enabled
        ? null
        : (value) async {
            if (value == -1) {
              await _chooseNewUnit();
            } else {
              setState(() {
                _unitChoice = value;
                _newUnitName = null;
              });
            }
          },
  );
}

class _InlineNameDialog extends StatefulWidget {
  const _InlineNameDialog({required this.title});
  final String title;

  @override
  State<_InlineNameDialog> createState() => _InlineNameDialogState();
}

class _InlineNameDialogState extends State<_InlineNameDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
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
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('افزودن'),
      ),
    ],
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text('$label:', style: const TextStyle(fontSize: HesabTheme.fontBody)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: HesabTheme.fontBody),
          ),
        ),
      ],
    ),
  );
}
