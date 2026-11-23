import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../models/expense_export_models.dart';
import '../services/expense_csv_exporter.dart';
import '../services/expense_excel_exporter.dart';
import '../services/expense_export_file_saver.dart';
import '../widgets/expense_export_dialog.dart';
import '../widgets/purchase_dialog.dart';
import '../../shared/widgets/app_empty_state.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.services,
    required this.fromDate,
    required this.toDate,
    this.newPurchaseRequest = 0,
    required this.onCreateWallet,
    super.key,
  });

  final HesabServices services;
  final DateTime fromDate;
  final DateTime? toDate;
  final int newPurchaseRequest;
  final VoidCallback onCreateWallet;

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
      final input = await showDialog<PurchaseInput>(
        context: context,
        builder: (_) => PurchaseDialog(
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
      final input = await showDialog<PurchaseInput>(
        context: context,
        builder: (_) => PurchaseDialog(
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
          throw StateError('دیتا مصارف تغییر کرده است؛ دوباره تلاش کنید.');
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
  Widget build(BuildContext context) => FutureBuilder<ExpensePageResult>(
    future: _loadExpenses(),
    builder: (context, snapshot) {
      final empty = snapshot.data?.records.isEmpty == true;
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          empty &&
          _search.isEmpty &&
          _categoryFilter == null &&
          _walletFilter == null) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AppEmptyState(
            illustration: 'expenses-empty',
            message: 'در این دوره خریدی ثبت نشده است.',
            actionLabel: 'ثبت خرید',
            onAction: _createFirstExpense,
          ),
        );
      }
      return _buildExpensesContent(context);
    },
  );

  Future<void> _createFirstExpense() async {
    final wallets = await widget.services.catalog.wallets();
    if (!mounted) return;
    if (wallets.isEmpty) {
      widget.onCreateWallet();
    } else {
      await _newPurchase();
    }
  }

  Widget _buildExpensesContent(BuildContext context) => Directionality(
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
                    child: Text('بارگذاری دیتا انجام نشد: ${snapshot.error}'),
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
        final contentWidth = constraints.maxWidth - outerHorizontalPadding * 2;
        final flexibleWidth = contentWidth - indexWidth - actionsWidth;
        final totalFlex = columnFlexes.fold<double>(
          0,
          (sum, flex) => sum + flex,
        );
        final columnWidths = columnFlexes
            .map((flex) => flexibleWidth * flex / totalFlex)
            .toList();
        final rulePositions = <double>[
          constraints.maxWidth - outerHorizontalPadding - indexWidth,
        ];
        var currentRight =
            constraints.maxWidth - outerHorizontalPadding - indexWidth;

        for (final width in columnWidths) {
          currentRight -= width;
          rulePositions.add(currentRight);
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
                      SizedBox(width: 28, child: _HeaderCell('#')),
                      Expanded(flex: 12, child: _HeaderCell('تاریخ')),
                      Expanded(flex: 18, child: _HeaderCell('جنس')),
                      Expanded(flex: 12, child: _HeaderCell('دسته‌بندی')),
                      Expanded(flex: 11, child: _HeaderCell('کیف پول')),
                      Expanded(flex: 11, child: _HeaderCell('مقدار')),
                      Expanded(flex: 11, child: _HeaderCell('مجموع')),
                      SizedBox(width: 108, child: Text('عملیات')),
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
                                width: 28,
                                child: _PaddedCell(
                                  child: _CellText(
                                    _dariDigits(
                                      pageIndex * pageSize + index + 1,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 12,
                                child: _PaddedCell(
                                  child: _CellText(dateLabel(expense.date)),
                                ),
                              ),
                              Expanded(
                                flex: 18,
                                child: _PaddedCell(
                                  child: _CellText(
                                    expense.itemName,
                                    strong: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 12,
                                child: _PaddedCell(
                                  child: _CellText(expense.categoryName),
                                ),
                              ),
                              Expanded(
                                flex: 11,
                                child: _PaddedCell(
                                  child: _CellText(expense.walletName),
                                ),
                              ),
                              Expanded(
                                flex: 11,
                                child: _PaddedCell(
                                  child: _CellText(
                                    '${AmountCodec.formatQuantityCenti(expense.quantityCenti)} ${expense.unitName}',
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 11,
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
                                width: 108,
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

String _dariDigits(int value) => value.toString().replaceAllMapped(
  RegExp(r'\d'),
  (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 1728),
);

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
    child: Text(label),
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
