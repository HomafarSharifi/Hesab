import 'package:material_ui/material_ui.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/finance/grouped_amount_input_formatter.dart';
import '../../../core/text/name_normalizer.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/financial_models.dart';
import '../../shared/widgets/jalali_date_picker_dialog.dart';

class PurchaseInput {
  const PurchaseInput({
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

class PurchaseDialog extends StatefulWidget {
  const PurchaseDialog({
    required this.wallets,
    required this.items,
    required this.categories,
    required this.units,
    this.initialExpense,
    super.key,
  });

  final List<WalletRecord> wallets;
  final List<ItemRecord> items;
  final List<CategoryRecord> categories;
  final List<UnitRecord> units;
  final ExpenseRecord? initialExpense;

  @override
  State<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<PurchaseDialog> {
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
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    if (expense == null) return;

    _walletId = widget.wallets.any((wallet) => wallet.id == expense.walletId)
        ? expense.walletId
        : null;
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
    if (_walletId == null || productName.isEmpty) return;
    if (_categoryChoice == null || _unitChoice == null) return;
    Navigator.pop(
      context,
      PurchaseInput(
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
                    _walletDropdown(),
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
                      inputFormatters: const [GroupedAmountInputFormatter()],
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
