import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/text/name_normalizer.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../models/expense_export_models.dart';
import '../services/expense_csv_exporter.dart';
import '../services/expense_excel_exporter.dart';
import '../services/expense_export_file_saver.dart';
import '../widgets/expense_export_dialog.dart';
import '../../shared/widgets/jalali_date_picker_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.services,
    required this.fromDate,
    required this.toDate,
    this.newPurchaseRequest = 0,
    super.key,
  });

  final HesabServices services;
  final DateTime fromDate;
  final DateTime? toDate;
  final int newPurchaseRequest;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  int? _walletFilter;
  String? _walletFilterLabel;
  String? _categoryFilter;
  int _revision = 0;
  int _pageIndex = 0;
  final _excelExporter = ExpenseExcelExporter();
  final _csvExporter = ExpenseCsvExporter();
  final _exportFileSaver = ExpenseExportFileSaver();

  @override
  void initState() {
    super.initState();
    if (widget.newPurchaseRequest > 0) _scheduleNewPurchase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromDate != widget.fromDate ||
        oldWidget.toDate != widget.toDate) {
      _pageIndex = 0;
    }
    if (oldWidget.newPurchaseRequest != widget.newPurchaseRequest) {
      _scheduleNewPurchase();
    }
  }

  void _scheduleNewPurchase() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newPurchase();
    });
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
        walletIds: input.walletIds,
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

  Future<void> _editPurchase(ExpenseRecord expense) async {
    if (expense.isReversed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اصلاح خرید'),
        content: Text(
          'با ادامه، خرید «${expense.itemName}» با ثبت برگشت خرید اصلی و '
          'یک خرید جایگزین اصلاح می‌شود. سابقهٔ اصلی حفظ می‌گردد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ادامه و ویرایش'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final data = await Future.wait<Object>([
        widget.services.catalog.wallets(),
        widget.services.catalog.items(),
        widget.services.catalog.categories(),
        widget.services.catalog.units(),
      ]);
      if (!mounted) return;
      final input = await showDialog<_PurchaseInput>(
        context: context,
        builder: (_) => _PurchaseDialog(
          wallets: data[0] as List<WalletRecord>,
          items: data[1] as List<ItemRecord>,
          categories: data[2] as List<CategoryRecord>,
          units: data[3] as List<UnitRecord>,
          initialExpense: expense,
        ),
      );
      if (input == null) return;

      await widget.services.transactions.correctPurchaseWithNewProduct(
        originalTransactionId: expense.transactionId,
        walletId: input.walletId,
        productName: input.productName,
        categoryId: input.categoryId,
        newCategoryName: input.newCategoryName,
        unitId: input.unitId,
        newUnitName: input.newUnitName,
        correctionDate: DateTime.now(),
        purchaseDate: input.date,
        quantityCenti: AmountCodec.parseQuantityCenti(input.quantity),
        unitPriceMinor: AmountCodec.parseMoneyMinor(input.unitPrice),
        note: input.note,
      );
      if (mounted) {
        setState(() => _revision++);
        _message('خرید با حفظ سابقه اصلاح شد.');
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<ExpensePageResult> _loadExpenses() =>
      widget.services.transactions.expensesPage(
        normalizedSearch: _search,
        walletId: _walletFilter,
        categoryName: _categoryFilter,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        pageIndex: _pageIndex,
      );

  Future<int> _countFilteredExpenses() =>
      widget.services.transactions.countExpenses(
        normalizedSearch: _search,
        walletId: _walletFilter,
        categoryName: _categoryFilter,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

  String _exportFilterSummary() {
    final filters = <String>[
      'تاریخ: ${JalaliDate.fromGregorian(widget.fromDate).fullDate}'
          '${widget.toDate == null ? ' به بعد' : ' تا ${JalaliDate.fromGregorian(widget.toDate!).fullDate}'}',
      if (_search.trim().isNotEmpty) 'جستجو: ${_search.trim()}',
      'دسته‌بندی: ${_categoryFilter ?? 'همه'}',
      'کیف پول: ${_walletFilterLabel ?? 'همه'}',
    ];
    return filters.join('؛ ');
  }

  Future<void> _showExportDialog() async {
    try {
      final totalCount = await _countFilteredExpenses();
      if (!mounted) return;
      final selection = await showDialog<ExpenseExportSelection>(
        context: context,
        builder: (_) => ExpenseExportDialog(
          totalCount: totalCount,
          pageSize: ExpensePageResult.defaultPageSize,
          filterSummary: _exportFilterSummary(),
          search: _search.trim().isEmpty ? null : _search,
          categoryName: _categoryFilter,
          walletId: _walletFilter,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
          refreshTotalCount: _countFilteredExpenses,
        ),
      );
      if (selection == null || !mounted) return;

      final recordsByPage = <int, List<ExpenseRecord>>{};
      for (final pageIndex in selection.pageIndexes) {
        final page = await widget.services.transactions.expensesPage(
          normalizedSearch: selection.search,
          walletId: selection.walletId,
          categoryName: selection.categoryName,
          fromDate: selection.fromDate,
          toDate: selection.toDate,
          pageIndex: pageIndex,
          pageSize: selection.pageSize,
        );
        if (page.totalCount != selection.expectedTotalCount) {
          throw StateError('معلومات مصارف تغییر کرده است؛ دوباره تلاش کنید.');
        }
        recordsByPage[pageIndex] = page.records;
      }

      final bundle = switch (selection.format) {
        ExpenseExportFormat.excel => ExpenseExportBundle(
          fileName: 'hesab_expenses.xlsx',
          bytes: _excelExporter.buildWorkbook(
            selection: selection,
            recordsByPage: recordsByPage,
          ),
        ),
        ExpenseExportFormat.csv => _csvExporter.build(
          selection: selection,
          recordsByPage: recordsByPage,
        ),
      };
      if (!mounted) return;
      final saved = await _exportFileSaver.save(bundle);
      if (saved && mounted) _message('فایل خروجی ذخیره شد.');
    } catch (error) {
      _message(
        error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', ''),
      );
    }
  }

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
        _walletFilterLabel = result.walletName;
        _pageIndex = 0;
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
                    onChanged: (value) => setState(() {
                      _search = value;
                      _pageIndex = 0;
                    }),
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('خروجی گرفتن'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<ExpensePageResult>(
              key: ValueKey(
                '$_revision-$_search-$_categoryFilter-$_walletFilter-'
                '${widget.fromDate}-${widget.toDate}-$_pageIndex',
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
                final page = snapshot.data!;
                final lastPageIndex = page.pageCount == 0
                    ? 0
                    : page.pageCount - 1;
                if (_pageIndex > lastPageIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _pageIndex <= lastPageIndex) return;
                    setState(() => _pageIndex = lastPageIndex);
                  });
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = page.records;
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
                  pageIndex: page.pageIndex,
                  pageSize: page.pageSize,
                  pageCount: page.pageCount,
                  dateLabel: _dateLabel,
                  onEdit: _editPurchase,
                  onDetails: _showDetails,
                  onReverse: _reverse,
                  onPreviousPage: () => setState(() => _pageIndex--),
                  onNextPage: () => setState(() => _pageIndex++),
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
  const _ExpenseFilters({this.categoryName, this.walletId, this.walletName});

  final String? categoryName;
  final int? walletId;
  final String? walletName;
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
            walletName: _walletId == 0
                ? null
                : widget.wallets
                      .firstWhere((wallet) => wallet.id == _walletId)
                      .name,
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
    required this.pageIndex,
    required this.pageSize,
    required this.pageCount,
    required this.dateLabel,
    required this.onEdit,
    required this.onDetails,
    required this.onReverse,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<ExpenseRecord> expenses;
  final int pageIndex;
  final int pageSize;
  final int pageCount;
  final String Function(String date) dateLabel;
  final ValueChanged<ExpenseRecord> onEdit;
  final ValueChanged<ExpenseRecord> onDetails;
  final ValueChanged<ExpenseRecord> onReverse;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const outerHorizontalPadding = 12.0;
        const indexWidth = 28.0;
        const actionsWidth = 108.0;
        const columnFlexes = <double>[12, 18, 12, 11, 11, 11];
        final availableWidth =
            (constraints.maxWidth -
                    outerHorizontalPadding * 2 -
                    indexWidth -
                    actionsWidth)
                .clamp(0.0, double.infinity);
        final totalFlex = columnFlexes.fold<double>(
          0,
          (sum, flex) => sum + flex,
        );
        final columnWidths = columnFlexes
            .map((flex) => availableWidth * flex / totalFlex)
            .toList(growable: false);
        final rulePositions = <double>[
          constraints.maxWidth - outerHorizontalPadding - indexWidth,
        ];
        var right = rulePositions.first;
        for (final width in columnWidths) {
          right -= width;
          rulePositions.add(right);
        }
        return Stack(
          children: [
            Column(
              children: [
                Container(
                  color: HesabTheme.selectionSurface(context),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      SizedBox(width: indexWidth, child: _HeaderCell('#')),
                      for (var i = 0; i < columnWidths.length; i++)
                        SizedBox(
                          width: columnWidths[i],
                          child: _HeaderCell(
                            [
                              'تاریخ',
                              'جنس',
                              'دسته‌بندی',
                              'کیف پول',
                              'مقدار',
                              'مجموع',
                            ][i],
                          ),
                        ),
                      SizedBox(
                        width: actionsWidth,
                        child: _HeaderCell('عملیات'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            2,
                            12,
                            2,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: indexWidth,
                                child: _PaddedCell(
                                  child: _CellText(
                                    _dariDigits(
                                      pageIndex * pageSize + index + 1,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[0],
                                child: _PaddedCell(
                                  child: _CellText(dateLabel(expense.date)),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[1],
                                child: _PaddedCell(
                                  child: _CellText(
                                    expense.itemName,
                                    strong: true,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[2],
                                child: _PaddedCell(
                                  child: _CellText(expense.categoryName),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[3],
                                child: _PaddedCell(
                                  child: _CellText(expense.walletName),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[4],
                                child: _PaddedCell(
                                  child: _CellText(
                                    '${AmountCodec.formatQuantityCenti(expense.quantityCenti)} ${expense.unitName}',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: columnWidths[5],
                                child: _PaddedCell(
                                  child: _CellText(
                                    AmountCodec.formatMoneyMinor(
                                      expense.amountMinor,
                                    ),
                                    strong: true,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: actionsWidth,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!expense.isReversed)
                                      IconButton(
                                        tooltip: 'ویرایش خرید',
                                        visualDensity: VisualDensity.compact,
                                        iconSize: 17,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 36,
                                              height: 36,
                                            ),
                                        onPressed: () => onEdit(expense),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    IconButton(
                                      tooltip: 'جزئیات',
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 17,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 36,
                                            height: 36,
                                          ),
                                      onPressed: () => onDetails(expense),
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                      ),
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
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 36,
                                              height: 36,
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
                _ExpensePaginationBar(
                  pageIndex: pageIndex,
                  pageCount: pageCount,
                  onPreviousPage: onPreviousPage,
                  onNextPage: onNextPage,
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ExpenseTableRulesPainter(
                    positions: rulePositions,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ExpenseTableRulesPainter extends CustomPainter {
  const _ExpenseTableRulesPainter({
    required this.positions,
    required this.color,
  });
  final List<double> positions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final x in positions) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpenseTableRulesPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.color != color;
}

class _ExpensePaginationBar extends StatelessWidget {
  const _ExpensePaginationBar({
    required this.pageIndex,
    required this.pageCount,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 2),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'صفحه قبلی',
              visualDensity: VisualDensity.compact,
              onPressed: pageIndex > 0 ? onPreviousPage : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              'صفحه ${_dariDigits(pageIndex + 1)} از ${_dariDigits(pageCount)}',
              style: const TextStyle(fontSize: HesabTheme.fontCaption),
            ),
            IconButton(
              tooltip: 'صفحه بعدی',
              visualDensity: VisualDensity.compact,
              onPressed: pageIndex + 1 < pageCount ? onNextPage : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

String _dariDigits(int value) => value.toString();

class _CellText extends StatelessWidget {
  const _CellText(this.value, {this.strong = false});
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: value,
    child: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: HesabTheme.fontCaption,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class _PaddedCell extends StatelessWidget {
  const _PaddedCell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
    child: child,
  );
}

class _PurchaseInput {
  const _PurchaseInput({
    required this.walletId,
    required this.walletIds,
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
  final List<int> walletIds;
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
    this.initialExpense,
  });

  final List<WalletRecord> wallets;
  final List<ItemRecord> items;
  final List<CategoryRecord> categories;
  final List<UnitRecord> units;
  final ExpenseRecord? initialExpense;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _note = TextEditingController();
  final List<int> _walletIds = [];
  late final List<WalletRecord> _availableWallets = widget.wallets
      .where((wallet) => wallet.balanceMinor > 0)
      .toList();
  int? _categoryChoice;
  int? _unitChoice;
  ItemRecord? _selectedItem;
  String? _newCategoryName;
  String? _newUnitName;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    if (expense == null) {
      if (_availableWallets.isNotEmpty) {
        _walletIds.add(_availableWallets.first.id);
      }
      return;
    }

    if (_availableWallets.any((wallet) => wallet.id == expense.walletId)) {
      _walletIds.add(expense.walletId);
    }
    _name.text = expense.itemName;
    _quantity.text = AmountCodec.formatQuantityCenti(expense.quantityCenti);
    _price.text = AmountCodec.formatMoneyMinor(expense.unitPriceMinor)
        .replaceAll(',', '')
        .replaceAll(' ؋', '');
    _note.text = expense.note ?? '';
    _date = DateTime.parse(expense.date);

    for (final item in widget.items) {
      if (item.id == expense.itemId) {
        _selectedItem = item;
        _categoryChoice = item.categoryId;
        _unitChoice = item.unitId;
        return;
      }
    }
    for (final category in widget.categories) {
      if (category.name == expense.categoryName) {
        _categoryChoice = category.id;
        break;
      }
    }
    for (final unit in widget.units) {
      if (unit.name == expense.unitName) {
        _unitChoice = unit.id;
        break;
      }
    }
  }

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
    if (_walletIds.isEmpty || productName.isEmpty) return;
    if (_categoryChoice == null || _unitChoice == null) return;
    Navigator.pop(
      context,
      _PurchaseInput(
        walletId: _walletIds.first,
        walletIds: List.unmodifiable(_walletIds),
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
        _walletIds.isNotEmpty &&
        _name.text.trim().isNotEmpty &&
        _categoryChoice != null &&
        _unitChoice != null &&
        total != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initialExpense == null ? 'ثبت خرید' : 'ویرایش خرید'),
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
                    _walletSelector(),
                    narrow: narrow,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    autofocus: widget.initialExpense == null,
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
            child: Text(
              widget.initialExpense == null ? 'ثبت خرید' : 'ذخیره اصلاح',
            ),
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

  Widget _walletSelector() {
    final selected = _availableWallets
        .where((wallet) => _walletIds.contains(wallet.id))
        .toList();
    final label = selected.isEmpty
        ? 'کیف پول را انتخاب کنید'
        : selected.length == 1
        ? selected.first.name
        : '${selected.first.name} و ${selected.length - 1} کیف پول دیگر';
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
          child: Text(
            'انتخاب کیف پول‌ها به ترتیب برداشت',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        SizedBox(
          width: 280,
          height: (_availableWallets.length * 56.0).clamp(56, 6 * 56),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final wallet in _availableWallets)
                CheckboxListTile(
                  dense: true,
                  title: Text(wallet.name),
                  subtitle: Text(
                    AmountCodec.formatMoneyMinor(wallet.balanceMinor),
                  ),
                  value: _walletIds.contains(wallet.id),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _walletIds.add(wallet.id);
                    } else {
                      _walletIds.remove(wallet.id);
                    }
                  }),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) => OutlinedButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

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
