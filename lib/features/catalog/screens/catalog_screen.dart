import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({required this.services, super.key});
  final HesabServices services;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  int _tab = 0;
  int _revision = 0;

  Future<void> _create() async {
    try {
      if (_tab == 0) {
        final categories = await widget.services.catalog.categories();
        final units = await widget.services.catalog.units();
        if (!mounted) return;
        final result =
            await showDialog<({String name, int category, int unit})>(
              context: context,
              builder: (_) => _ItemDialog(categories: categories, units: units),
            );
        if (result != null) {
          await widget.services.catalog.createItem(
            name: result.name,
            categoryId: result.category,
            unitId: result.unit,
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

  Future<void> _archive(String type, int id) async {
    try {
      switch (type) {
        case 'item':
          await widget.services.catalog.archiveItem(id);
        case 'category':
          await widget.services.catalog.archiveCategory(id);
        case 'unit':
          await widget.services.catalog.archiveUnit(id);
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<Object>(
        key: ValueKey('$_tab-$_revision'),
        future: switch (_tab) {
          0 => widget.services.catalog.items(),
          1 => widget.services.catalog.categories(),
          _ => widget.services.catalog.units(),
        },
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
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن'),
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
        ),
      ),
    );
  }

  Widget _rows(AsyncSnapshot<Object> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text('بارگذاری معلومات انجام نشد: ${snapshot.error}'),
      );
    }
    final values = snapshot.data! as List;
    if (values.isEmpty) {
      return const Center(child: Text('هنوز چیزی ثبت نشده است.'));
    }
    return ListView.separated(
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
        final label = isItem
            ? '${value.name}  •  ${value.categoryName} / ${value.unitName}'
            : value.name as String;
        return Card(
          child: ListTile(
            minTileHeight: HesabTheme.controlHeight,
            title: Text(
              label,
              style: const TextStyle(fontSize: HesabTheme.fontBody),
            ),
            trailing: IconButton(
              tooltip: 'بایگانی',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => _archive(
                _tab == 0
                    ? 'item'
                    : _tab == 1
                    ? 'category'
                    : 'unit',
                id,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});
  final String title;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
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
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('ثبت'),
      ),
    ],
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.categories, required this.units});
  final List<CategoryRecord> categories;
  final List<UnitRecord> units;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _name = TextEditingController();
  int? _category;
  int? _unit;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('جنس تازه'),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _unit,
            decoration: const InputDecoration(
              labelText: 'واحد',
              border: OutlineInputBorder(),
            ),
            items: widget.units
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => _unit = v),
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
            _category == null || _unit == null || _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                name: _name.text,
                category: _category!,
                unit: _unit!,
              )),
        child: const Text('ثبت'),
      ),
    ],
  );
}
