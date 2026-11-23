import 'package:material_ui/material_ui.dart';

import '../../../core/theme/hesab_theme.dart';
import '../models/expense_export_models.dart';

class ExpenseExportDialog extends StatefulWidget {
  const ExpenseExportDialog({
    required this.totalCount,
    required this.pageSize,
    required this.filterSummary,
    required this.search,
    required this.categoryName,
    required this.walletId,
    required this.fromDate,
    required this.toDate,
    required this.refreshTotalCount,
    super.key,
  });

  final int totalCount;
  final int pageSize;
  final String filterSummary;
  final String? search;
  final String? categoryName;
  final int? walletId;
  final DateTime fromDate;
  final DateTime? toDate;
  final Future<int> Function() refreshTotalCount;

  @override
  State<ExpenseExportDialog> createState() => _ExpenseExportDialogState();
}

class _ExpenseExportDialogState extends State<ExpenseExportDialog> {
  late int _totalCount = widget.totalCount;
  final Set<int> _selectedPageIndexes = {};
  ExpenseExportFormat _format = ExpenseExportFormat.excel;
  bool _checkingSnapshot = false;
  String? _message;

  int get _pageCount => (_totalCount + widget.pageSize - 1) ~/ widget.pageSize;

  int get _selectedRecordCount => _selectedPageIndexes.fold(
    0,
    (total, pageIndex) => total + _recordCountForPage(pageIndex),
  );

  bool get _canContinue =>
      !_checkingSnapshot && _selectedPageIndexes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectAllPages();
  }

  void _selectAllPages() {
    _selectedPageIndexes
      ..clear()
      ..addAll(List<int>.generate(_pageCount, (index) => index));
  }

  int _recordCountForPage(int pageIndex) =>
      (_totalCount - pageIndex * widget.pageSize)
          .clamp(0, widget.pageSize)
          .toInt();

  void _togglePage(int pageIndex, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedPageIndexes.add(pageIndex);
      } else {
        _selectedPageIndexes.remove(pageIndex);
      }
      _message = null;
    });
  }

  Future<void> _confirm() async {
    if (!_canContinue) return;
    setState(() {
      _checkingSnapshot = true;
      _message = null;
    });
    try {
      final latestCount = await widget.refreshTotalCount();
      if (!mounted) return;
      if (latestCount != _totalCount) {
        setState(() {
          _totalCount = latestCount;
          _selectedPageIndexes.removeWhere((page) => page >= _pageCount);
          _checkingSnapshot = false;
          _message = 'دیتا تازه شد؛ صفحه‌ها و شمارش‌ها را بازبینی کنید.';
        });
        return;
      }

      final pageIndexes = _selectedPageIndexes.toList()..sort();
      Navigator.of(context).pop(
        ExpenseExportSelection(
          format: _format,
          pageIndexes: pageIndexes,
          pageSize: widget.pageSize,
          expectedTotalCount: _totalCount,
          search: widget.search,
          categoryName: widget.categoryName,
          walletId: widget.walletId,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingSnapshot = false;
        _message = 'شمارش دیتا تازه نشد. دوباره تلاش کنید.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      scrollable: true,
      title: const Text('خروجی گرفتن مصارف'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('فورمت فایل'),
            const SizedBox(height: 8),
            SegmentedButton<ExpenseExportFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ExpenseExportFormat.excel,
                  label: Text('اکسل (.xlsx)'),
                ),
                ButtonSegment(
                  value: ExpenseExportFormat.csv,
                  label: Text('CSV (.csv)'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (selection) => setState(() {
                _format = selection.single;
                _message = null;
              }),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HesabTheme.selectionSurface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'محدودهٔ فعلی',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.filterSummary,
                    style: const TextStyle(fontSize: HesabTheme.fontCaption),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  '${_dariDigits(_pageCount)} صفحه، ${_dariDigits(_totalCount)} مورد',
                  style: const TextStyle(fontSize: HesabTheme.fontCaption),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: _pageCount == 0 || _checkingSnapshot
                          ? null
                          : () => setState(() {
                              _selectAllPages();
                              _message = null;
                            }),
                      child: const Text('همه صفحه‌ها'),
                    ),
                    TextButton(
                      onPressed:
                          _selectedPageIndexes.isEmpty || _checkingSnapshot
                          ? null
                          : () => setState(() {
                              _selectedPageIndexes.clear();
                              _message = null;
                            }),
                      child: const Text('پاک‌کردن انتخاب'),
                    ),
                  ],
                ),
              ],
            ),
            if (_pageCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text('برای این محدوده مصرفی پیدا نشد.')),
              )
            else
              SizedBox(
                height: 248,
                child: ListView.builder(
                  itemCount: _pageCount,
                  itemBuilder: (context, pageIndex) {
                    final firstRow = pageIndex * widget.pageSize + 1;
                    final recordCount = _recordCountForPage(pageIndex);
                    final lastRow = firstRow + recordCount - 1;
                    return CheckboxListTile(
                      key: ValueKey('export-page-$pageIndex'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selectedPageIndexes.contains(pageIndex),
                      onChanged: _checkingSnapshot
                          ? null
                          : (value) => _togglePage(pageIndex, value),
                      title: Text(
                        'صفحه ${_dariDigits(pageIndex + 1)}: '
                        '${_dariDigits(firstRow)}–${_dariDigits(lastRow)}',
                      ),
                      subtitle: Text(
                        '${_dariDigits(recordCount)} مورد',
                        style: const TextStyle(
                          fontSize: HesabTheme.fontCaption,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'انتخاب‌شده: ${_dariDigits(_selectedPageIndexes.length)} صفحه، '
              '${_dariDigits(_selectedRecordCount)} مورد',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_checkingSnapshot) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checkingSnapshot ? null : () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        FilledButton(
          onPressed: _canContinue ? _confirm : null,
          child: const Text('خروجی گرفتن'),
        ),
      ],
    ),
  );
}

String _dariDigits(int value) => value.toString();
