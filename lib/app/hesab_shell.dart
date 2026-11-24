import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
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
import '../features/shared/widgets/app_window_controls.dart';
import '../features/shared/widgets/app_window_resize_handles.dart';
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
            const expandedSidebarWidth = 280.0;
            final expandedContentWidth =
                constraints.maxWidth - expandedSidebarWidth;
            final expandedHeaderPadding = (expandedContentWidth * 0.045)
                .clamp(18.0, 64.0)
                .toDouble();
            final expandedHeaderContentWidth =
                expandedContentWidth - expandedHeaderPadding * 2;
            final expandedHeaderControlsHeight =
                expandedHeaderContentWidth < AppPageHeader.stackedBreakpoint
                ? 92.0
                : expandedHeaderContentWidth < 900
                ? 44.0
                : 56.0;
            final expandedHeaderHeight = 25.0 + expandedHeaderControlsHeight;
            final expandedPageHeight =
                (constraints.maxHeight - expandedHeaderHeight)
                    .clamp(0.0, constraints.maxHeight)
                    .toDouble();
            final dashboardBottomInset = _selectedIndex == 0
                ? DashboardScreen.pageInset
                : 0.0;
            final expandedPanelHeight = (expandedPageHeight -
                    dashboardBottomInset)
                .clamp(0.0, expandedPageHeight)
                .toDouble();
            final expandedNavigationIsCompact = expandedPageHeight < 760;
            final expandedNavigationHeight = expandedNavigationIsCompact
                ? _Sidebar.compactLabeledHeight
                : _Sidebar.labeledHeight;
            final collapsedSidebar =
                constraints.maxWidth <
                    ResponsiveDimensions.expandedNavigationBreakpoint ||
                expandedPanelHeight < expandedNavigationHeight;
            final sidebarWidth = collapsedSidebar ? 82.0 : expandedSidebarWidth;
            final contentWidth = constraints.maxWidth - sidebarWidth;
            final headerHorizontalPadding = (contentWidth * 0.045)
                .clamp(18.0, 64.0)
                .toDouble();
            final hasWindowControls =
                defaultTargetPlatform == TargetPlatform.windows;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeader(
                              context,
                              headerHorizontalPadding,
                            ),
                          ),
                          SizedBox(width: sidebarWidth),
                        ],
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildScreen()),
                            SizedBox(
                              width: sidebarWidth,
                              child: Padding(
                                padding: EdgeInsetsDirectional.symmetric(
                                  horizontal: collapsedSidebar ? 8 : 18,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, sidebarConstraints) {
                                    return _Sidebar(
                                      height: (sidebarConstraints.maxHeight -
                                              dashboardBottomInset)
                                          .clamp(
                                            0.0,
                                            sidebarConstraints.maxHeight,
                                          )
                                          .toDouble(),
                                      selectedIndex: _selectedIndex,
                                      items: _navigationItems,
                                      onSelect: _selectPage,
                                      onNewExpense: _startNewExpense,
                                      iconOnly: collapsedSidebar,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasWindowControls)
                    const Positioned.fill(child: AppWindowResizeHandles()),
                  if (hasWindowControls)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: AppWindowControls(),
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

  Widget _buildHeader(BuildContext context, double horizontalPadding) => Column(
    mainAxisSize: MainAxisSize.min,
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
        padding: EdgeInsetsDirectional.symmetric(horizontal: horizontalPadding),
        child: Divider(color: Theme.of(context).dividerColor, height: 1),
      ),
    ],
  );

  Widget _buildScreen() => switch (_selectedIndex) {
    0 => DashboardScreen(
      services: widget.services,
      fromDate: _periodFrom,
      toDate: _periodTo,
      selectedPeriod: _selectedPeriod,
      onAddFunds: () => setState(() => _selectedIndex = 3),
      onCreateWallet: () => setState(() => _selectedIndex = 3),
      onCreatePurchase: _startNewExpense,
    ),
    1 => ExpensesScreen(
      services: widget.services,
      fromDate: _periodFrom,
      toDate: _periodTo,
      newPurchaseRequest: _newExpenseRequest,
      onCreateWallet: () => setState(() => _selectedIndex = 3),
    ),
    2 => CatalogScreen(services: widget.services),
    3 => WalletScreen(services: widget.services),
    4 => ReportsScreen(
      services: widget.services,
      fromDate: _periodFrom,
      toDate: _periodTo,
      onCreatePurchase: _startNewExpense,
      onCreateWallet: () => setState(() => _selectedIndex = 3),
    ),
    _ => SettingsScreen(
      services: widget.services,
      onDatabaseChanged: widget.onDatabaseChanged,
    ),
  };
}

class _Sidebar extends StatelessWidget {
  static const compactLabeledHeight = 444.0;
  static const labeledHeight = 586.0;

  const _Sidebar({
    required this.height,
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onNewExpense,
    required this.iconOnly,
  });

  final double height;
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
          return SizedBox(
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: EdgeInsetsDirectional.fromSTEB(
                iconOnly ? 0 : 16,
                compact ? 8 : 12,
                iconOnly ? 0 : 16,
                compact ? 14 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        icon: Icon(Icons.add_rounded, size: compact ? 21 : 26),
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
    final buttonHeight = compact ? 44.0 : 58.0;
    final buttonShape = iconOnly
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    final button = SizedBox(
      width: iconOnly ? buttonHeight : double.infinity,
      height: buttonHeight,
      child: Material(
        color: selected
            ? HesabTheme.selectionSurface(context)
            : Colors.transparent,
        shape: buttonShape,
        child: InkWell(
          onTap: onTap,
          customBorder: buttonShape,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: iconOnly ? 0 : (compact ? 10 : 18),
              end: iconOnly ? 0 : (compact ? 10 : 18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
    return iconOnly
        ? Tooltip(
            message: item.label,
            child: SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: Center(child: button),
            ),
          )
        : button;
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.assetPath);

  final String label;
  final String assetPath;
}
