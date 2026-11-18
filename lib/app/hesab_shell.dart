import 'package:material_ui/material_ui.dart';

import '../core/calendar/jalali_date.dart';
import '../core/theme/hesab_theme.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/expenses/screens/expenses_screen.dart';
import '../features/catalog/screens/catalog_screen.dart';
import '../features/wallets/screens/wallet_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/shared/widgets/app_page_header.dart';
import '../features/shared/widgets/jalali_date_range_dialog.dart';
import 'hesab_services.dart';

class HesabShell extends StatefulWidget {
  const HesabShell({
    required this.services,
    required this.onToggleTheme,
    required this.isDarkMode,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<HesabShell> createState() => _HesabShellState();
}

class _HesabShellState extends State<HesabShell> {
  int _selectedIndex = 0;
  int _selectedPeriod = 0;
  DateTime? _customFrom;
  DateTime? _customTo;

  static const _navigationItems = <_NavigationItem>[
    _NavigationItem('پیشخوان', Icons.home_rounded),
    _NavigationItem('مصارف', Icons.receipt_rounded),
    _NavigationItem('اجناس', Icons.inventory_2_rounded),
    _NavigationItem('کیف پول', Icons.account_balance_wallet_rounded),
    _NavigationItem('گزارشات', Icons.pie_chart_rounded),
    _NavigationItem('تنظیمات', Icons.settings_rounded),
  ];

  DateTime get _periodFrom {
    final today = JalaliDate.fromGregorian(DateTime.now());
    return switch (_selectedPeriod) {
      0 => JalaliDate(
        year: today.year,
        month: today.month,
        day: 1,
      ).toGregorian(),
      1 => JalaliDate(year: today.year, month: 1, day: 1).toGregorian(),
      _ => _customFrom!,
    };
  }

  DateTime? get _periodTo => _selectedPeriod == 2 ? _customTo : null;

  Future<void> _selectPeriod(int period) async {
    if (period != 2) {
      setState(() => _selectedPeriod = period);
      return;
    }
    final today = DateTime.now();
    final range = await showJalaliDateRangeDialog(
      context,
      initialStart: _customFrom ?? today,
      initialEnd: _customTo ?? today,
    );
    if (range == null || !mounted) return;
    setState(() {
      _customFrom = range.start;
      _customTo = range.end;
      _selectedPeriod = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 900;
            final sidebarWidth = (constraints.maxWidth * 0.22)
                .clamp(220.0, 320.0)
                .toDouble();
            final contentWidth = constraints.maxWidth - sidebarWidth;
            final headerHorizontalPadding =
                ((compactLayout ? constraints.maxWidth : contentWidth) * 0.045)
                    .clamp(compactLayout ? 12.0 : 18.0, 64.0)
                    .toDouble();
            return Directionality(
              textDirection: TextDirection.ltr,
              child: compactLayout
                  ? Column(
                      children: [
                        Expanded(
                          child: _buildContent(
                            context,
                            headerHorizontalPadding,
                          ),
                        ),
                        _CompactNavigation(
                          items: _navigationItems,
                          selectedIndex: _selectedIndex,
                          onSelect: (index) =>
                              setState(() => _selectedIndex = index),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildContent(
                            context,
                            headerHorizontalPadding,
                          ),
                        ),
                        SizedBox(
                          width: sidebarWidth,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              0,
                              18,
                              18,
                              18,
                            ),
                            child: _Sidebar(
                              selectedIndex: _selectedIndex,
                              items: _navigationItems,
                              onSelect: (index) =>
                                  setState(() => _selectedIndex = index),
                              onNewExpense: () =>
                                  setState(() => _selectedIndex = 1),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  Widget _buildContent(BuildContext context, double horizontalPadding) =>
      Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              12,
              horizontalPadding,
              12,
            ),
            child: AppPageHeader(
              title: _navigationItems[_selectedIndex].label,
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: _selectPeriod,
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: horizontalPadding,
            ),
            child: Divider(color: Theme.of(context).dividerColor, height: 1),
          ),
          Expanded(
            child: switch (_selectedIndex) {
              0 => DashboardScreen(
                services: widget.services,
                fromDate: _periodFrom,
                toDate: _periodTo,
                onAddFunds: () => setState(() => _selectedIndex = 3),
              ),
              1 => ExpensesScreen(
                services: widget.services,
                fromDate: _periodFrom,
                toDate: _periodTo,
              ),
              2 => CatalogScreen(services: widget.services),
              3 => WalletScreen(services: widget.services),
              4 => ReportsScreen(
                services: widget.services,
                fromDate: _periodFrom,
                toDate: _periodTo,
              ),
              _ => SettingsScreen(
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),
            },
          ),
        ],
      );
}

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                SizedBox(
                  width: 76,
                  child: InkWell(
                    onTap: () => onSelect(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[index].icon,
                          size: 21,
                          color: index == selectedIndex
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onNewExpense,
  });

  final int selectedIndex;
  final List<_NavigationItem> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 760;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: compact
                    ? const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14)
                    : const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 16),
                child: Column(
                  children: [
                    _HesabMark(compact: compact),
                    SizedBox(height: compact ? 10 : 18),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 48 : HesabTheme.sidebarActionHeight,
                      child: FilledButton.icon(
                        onPressed: onNewExpense,
                        icon: Icon(Icons.add_rounded, size: compact ? 21 : 26),
                        label: Text(
                          'مصرف تازه',
                          style: TextStyle(
                            fontSize: compact
                                ? HesabTheme.fontBody
                                : HesabTheme.fontControl,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 20),
                    for (var i = 0; i < items.length; i++) ...[
                      _NavigationButton(
                        item: items[i],
                        selected: i == selectedIndex,
                        compact: compact,
                        onTap: () => onSelect(i),
                      ),
                      if (i != items.length - 1)
                        SizedBox(height: compact ? 6 : 12),
                    ],
                    SizedBox(height: compact ? 16 : 0),
                    if (!compact) const SizedBox(height: 24),
                    Text(
                      'حساب',
                      style: TextStyle(
                        fontSize: HesabTheme.fontBody,
                        color: colors.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HesabMark extends StatelessWidget {
  const _HesabMark({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 42 : 50,
    height: compact ? 42 : 50,
    child: Image.asset('asset/piggy_bank.png'),
  );
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? HesabTheme.selectionSurface(context)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: compact ? 44 : 58,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: compact ? 10 : 18,
              end: compact ? 10 : 18,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: compact ? 22 : 27,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: compact ? 10 : 18),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact
                          ? HesabTheme.fontBody
                          : HesabTheme.fontControl,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
