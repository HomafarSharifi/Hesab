import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/calendar/jalali_date.dart';
import '../core/layout/responsive_dimensions.dart';
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
    required this.onDatabaseChanged,
    required this.onToggleTheme,
    required this.isDarkMode,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onDatabaseChanged;
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
  int _newExpenseRequest = 0;

  void _startNewExpense() {
    setState(() {
      _selectedIndex = 1;
      _newExpenseRequest++;
    });
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
      _newExpenseRequest = 0;
    });
  }

  static const _navigationItems = <_NavigationItem>[
    _NavigationItem('داشبورد', 'asset/icons/home.svg'),
    _NavigationItem('مصارف', 'asset/icons/receipt.svg'),
    _NavigationItem('اجناس', 'asset/icons/items.svg'),
    _NavigationItem('کیف پول', 'asset/icons/wallet.svg'),
    _NavigationItem('گزارشات', 'asset/icons/graph.svg'),
    _NavigationItem('تنظیمات', 'asset/icons/setting.svg'),
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
            final collapsedSidebar =
                constraints.maxWidth <
                ResponsiveDimensions.expandedNavigationBreakpoint;
            final sidebarWidth = collapsedSidebar ? 82.0 : 280.0;
            final contentWidth = constraints.maxWidth - sidebarWidth;
            final headerHorizontalPadding = (contentWidth * 0.045)
                .clamp(18.0, 64.0)
                .toDouble();
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Expanded(
                    child: _buildContent(context, headerHorizontalPadding),
                  ),
                  SizedBox(
                    width: sidebarWidth,
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        0,
                        collapsedSidebar ? 8 : 18,
                        collapsedSidebar ? 8 : 18,
                        collapsedSidebar ? 8 : 18,
                      ),
                      child: _Sidebar(
                        selectedIndex: _selectedIndex,
                        items: _navigationItems,
                        onSelect: _selectPage,
                        onNewExpense: _startNewExpense,
                        iconOnly: collapsedSidebar,
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
                selectedPeriod: _selectedPeriod,
                onAddFunds: () => setState(() => _selectedIndex = 3),
              ),
              1 => ExpensesScreen(
                services: widget.services,
                fromDate: _periodFrom,
                toDate: _periodTo,
                newPurchaseRequest: _newExpenseRequest,
              ),
              2 => CatalogScreen(services: widget.services),
              3 => WalletScreen(services: widget.services),
              4 => ReportsScreen(
                services: widget.services,
                fromDate: _periodFrom,
                toDate: _periodTo,
              ),
              _ => SettingsScreen(
                services: widget.services,
                onDatabaseChanged: widget.onDatabaseChanged,
              ),
            },
          ),
        ],
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onNewExpense,
    required this.iconOnly,
  });

  final int selectedIndex;
  final List<_NavigationItem> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewExpense;
  final bool iconOnly;

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
                    if (!iconOnly) _HesabMark(compact: compact),
                    if (iconOnly)
                      Tooltip(
                        message: 'ثبت مصرف',
                        child: IconButton.filled(
                          onPressed: onNewExpense,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                    SizedBox(height: compact ? 10 : 18),
                    if (!iconOnly)
                      SizedBox(
                        width: double.infinity,
                        height: compact ? 48 : HesabTheme.sidebarActionHeight,
                        child: FilledButton.icon(
                          onPressed: onNewExpense,
                          icon: Icon(
                            Icons.add_rounded,
                            size: compact ? 21 : 26,
                          ),
                          label: Text(
                            'ثبت مصرف',
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
                        iconOnly: iconOnly,
                        onTap: () => onSelect(i),
                      ),
                      if (i != items.length - 1)
                        SizedBox(height: compact ? 6 : 12),
                    ],
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: compact ? 58 : 68,
      height: compact ? 58 : 68,
      child: SvgPicture.asset(
        'asset/logo.svg',
        colorMapper: _LogoOutlineColorMapper(
          isDark ? const Color(0xFFF2F5F4) : const Color(0xFF231F20),
        ),
      ),
    );
  }
}

class _LogoOutlineColorMapper extends ColorMapper {
  const _LogoOutlineColorMapper(this.outlineColor);

  final Color outlineColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => attributeName == 'stroke' && color == const Color(0xFF231F20)
      ? outlineColor
      : color;
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.iconOnly,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final bool compact;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = Material(
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
              mainAxisAlignment: iconOnly
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  item.assetPath,
                  width: compact ? 22 : 27,
                  height: compact ? 22 : 27,
                  colorFilter: ColorFilter.mode(
                    selected ? colors.primary : colors.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
                if (!iconOnly) SizedBox(width: compact ? 10 : 18),
                if (!iconOnly)
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return iconOnly ? Tooltip(message: item.label, child: button) : button;
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.assetPath);

  final String label;
  final String assetPath;
}
