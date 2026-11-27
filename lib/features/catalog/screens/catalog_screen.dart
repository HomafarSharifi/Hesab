import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../core/text/name_normalizer.dart';
import '../../../data/models/catalog_models.dart';
import '../../shared/widgets/app_empty_state.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({required this.services, super.key});
  final HesabServices services;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  int _tab = 0;
  int _revision = 0;
  final _searchController = TextEditingController();
  final _itemsScrollController = ScrollController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    _itemsScrollController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    try {
      if (_tab == 0) {
        final categories = await widget.services.catalog.categories();
        final units = await widget.services.catalog.units();
        if (!mounted) return;
        final result =
            await showDialog<({String name, int category})>(
              context: context,
              builder: (_) => _ItemDialog(categories: categories),
            );
        if (result != null) {
          final defaultUnitId = units.isNotEmpty ? units.first.id : 1;
          await widget.services.catalog.createItem(
            name: result.name,
            categoryId: result.category,
            unitId: defaultUnitId,
          );
        }
      } else {
        final name = await showDialog<String>(
          context: context,
          builder: (_) =>
              _NameDialog(title: _tab == 1 ? 'دسته‌بندی تازه' : 'واحد تازه'),
        );
        if (name != null) {
          if (_tab == 1) {
            await widget.services.catalog.createCategory(name);
          } else {
            await widget.services.catalog.createUnit(name);
          }
        }
      }
      if (mounted) setState(() => _revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _delete(String type, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کامل'),
        content: Text(
          '«$name» به‌طور کامل حذف شود؟ اگر در سابقه استفاده شده باشد، حذف انجام نمی‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      switch (type) {
        case 'item':
          await widget.services.catalog.deleteItem(id);
        case 'category':
          await widget.services.catalog.deleteCategory(id);
        case 'unit':
          await widget.services.catalog.deleteUnit(id);
      }
      if (mounted) setState(() => _revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _editName(String type, int id, String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: 'ویرایش', initialName: currentName),
    );
    if (name == null || !mounted) return;
    try {
      await widget.services.catalog.updateName(type: type, id: id, value: name);
      if (mounted) setState(() => _revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _editItem(ItemRecord item) async {
    try {
      final categories = await widget.services.catalog.categories();
      if (!mounted) return;
      final result = await showDialog<({String name, int category})>(
        context: context,
        builder: (_) => _ItemDialog(
          categories: categories,
          initialItem: item,
        ),
      );
      if (result == null) return;
      await widget.services.catalog.updateItem(
        id: item.id,
        name: result.name,
        categoryId: result.category,
        unitId: item.unitId,
      );
      if (mounted) setState(() => _revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<Object>(
        key: ValueKey('$_tab-$_search-$_revision'),
        future: switch (_tab) {
          0 => widget.services.catalog.items(search: _search),
          1 => widget.services.catalog.categories(),
          _ => widget.services.catalog.units(),
        },
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              (_tab != 0 || _search.isEmpty) &&
              _isCurrentListEmpty(snapshot.data)) {
            return AppEmptyState(
              illustration: switch (_tab) {
                0 => 'catalog-items-empty',
                1 => 'catalog-categories-empty',
                _ => 'catalog-units-empty',
              },
              message: switch (_tab) {
                0 => 'هنوز جنسی ثبت نشده است.',
                1 => 'هنوز دسته‌بندی‌ای ثبت نشده است.',
                _ => 'هنوز واحدی ثبت نشده است.',
              },
              actionLabel: switch (_tab) {
                0 => 'افزودن جنس',
                1 => 'افزودن دسته‌بندی',
                _ => 'افزودن واحد',
              },
              onAction: _create,
            );
          }
          return Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن'),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: switch (_tab) {
                          0 => 'جستجوی جنس',
                          1 => 'جستجوی دسته‌بندی',
                          _ => 'جستجوی واحد',
                        },
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'پاک کردن جستجو',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('اجناس')),
                  ButtonSegment(value: 1, label: Text('دسته‌بندی')),
                  ButtonSegment(value: 2, label: Text('واحدها')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
              const SizedBox(height: 20),
              Expanded(child: _rows(snapshot)),
            ],
          ),
          );
        },
      ),
    );
  }

  bool _isCurrentListEmpty(Object? data) {
    if (data is! List) return false;
    if (_tab == 0 || NameNormalizer.normalize(_search).isEmpty) {
      return data.isEmpty;
    }
    final query = NameNormalizer.normalize(_search);
    return data.where((value) =>
      NameNormalizer.normalize(value.name).contains(query),
    ).isEmpty;
  }

  Widget _rows(AsyncSnapshot<Object> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text('بارگذاری دیتا انجام نشد: ${snapshot.error}'),
      );
    }
    final loadedValues = snapshot.data! as List;
    final normalizedSearch = NameNormalizer.normalize(_search);
    final values = _tab == 0 || normalizedSearch.isEmpty
        ? loadedValues
        : loadedValues
              .where(
                (value) =>
                    NameNormalizer.normalize(value.name)
                        .contains(normalizedSearch),
              )
              .toList();
    if (values.isEmpty) {
      return const Center(child: Text('هنوز چیزی ثبت نشده است.'));
    }
    return Scrollbar(
      controller: _itemsScrollController,
      scrollbarOrientation: ScrollbarOrientation.right,
      child: ListView.separated(
        controller: _itemsScrollController,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
        final value = values[index];
        final isItem = value is ItemRecord;
        final id = isItem
            ? value.id
            : value is CategoryRecord
            ? value.id
            : (value as UnitRecord).id;
        final label = value.name as String;
        return Card(
          child: ListTile(
            minTileHeight: HesabTheme.controlHeight,
            title: Text(
              label,
              style: const TextStyle(fontSize: HesabTheme.fontBody),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'ویرایش',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    if (isItem) {
                      _editItem(value);
                    } else {
                      _editName(_tab == 1 ? 'category' : 'unit', id, label);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(
                    _tab == 0
                        ? 'item'
                        : _tab == 1
                        ? 'category'
                        : 'unit',
                    id,
                    label,
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initialName = ''});
  final String title;
  final String initialName;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
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
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('ثبت'),
      ),
    ],
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({
    required this.categories,
    this.initialItem,
  });
  final List<CategoryRecord> categories;
  final ItemRecord? initialItem;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final _name = TextEditingController(
    text: widget.initialItem?.name ?? '',
  );
  int? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialItem?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialItem == null ? 'جنس تازه' : 'ویرایش جنس'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'نام جنس',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'دسته‌بندی',
              border: OutlineInputBorder(),
            ),
            items: widget.categories
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(
        onPressed:
            _category == null || _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                name: _name.text,
                category: _category!,
              )),
        child: const Text('ثبت'),
      ),
    ],
  );
}
