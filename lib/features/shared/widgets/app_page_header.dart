import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/hesab_theme.dart';

class AppPageHeader extends StatelessWidget {
  static const stackedBreakpoint = 420.0;

  const AppPageHeader({
    required this.title,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final String title;
  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final stacked = constraints.maxWidth < stackedBreakpoint;
        final isWindows = defaultTargetPlatform == TargetPlatform.windows;
        if (constraints.maxWidth < 140) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _PageTitle(title: title, compact: true),
            ),
          );
        }
        return Directionality(
          textDirection: TextDirection.ltr,
          child: stacked
              ? Column(
                  children: [
                    Row(
                      children: [
                        _ThemeButton(
                          compact: true,
                          isDarkMode: isDarkMode,
                          onToggleTheme: onToggleTheme,
                        ),
                        if (isWindows)
                          Expanded(child: _WindowDragArea(height: 40))
                        else
                          const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, rowConstraints) {
                        final periodSelector = SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _PeriodSelector(
                            selectedPeriod: selectedPeriod,
                            onPeriodChanged: onPeriodChanged,
                            compact: true,
                          ),
                        );
                        final pageTitle = _PageTitle(
                          title: title,
                          compact: true,
                        );
                        return rowConstraints.maxWidth >= stackedBreakpoint
                            ? Row(
                                children: [
                                  Expanded(child: periodSelector),
                                  const SizedBox(width: 12),
                                  pageTitle,
                                ],
                              )
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Center(child: periodSelector),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: pageTitle,
                                  ),
                                ],
                              );
                      },
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ThemeButton(
                      compact: compact,
                      isDarkMode: isDarkMode,
                      onToggleTheme: onToggleTheme,
                    ),
                    if (isWindows)
                      Expanded(
                        child: _WindowDragArea(height: compact ? 40 : 48),
                      )
                    else
                      const Spacer(),
                    _PeriodSelector(
                      selectedPeriod: selectedPeriod,
                      onPeriodChanged: onPeriodChanged,
                      compact: compact,
                    ),
                    if (isWindows)
                      Expanded(
                        child: _WindowDragArea(height: compact ? 40 : 48),
                      )
                    else
                      const Spacer(),
                    _PageTitle(title: title, compact: compact),
                  ],
                ),
        );
      },
    );
  }
}

class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea({required this.height});

  final double height;

  static const _channel = MethodChannel('hesab/window');

  Future<void> _startDrag() async {
    try {
      await _channel.invokeMethod<void>('startDragging');
    } on PlatformException {
      // The custom drag area is only active on the Windows runner.
    } on MissingPluginException {
      // Other Flutter targets keep their standard window behavior.
    }
  }

  Future<void> _toggleMaximize() =>
      _channel.invokeMethod<void>('toggleMaximize');

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: _toggleMaximize,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _startDrag(),
      child: SizedBox(height: height),
    ),
  );
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.compact,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool compact;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: isDarkMode ? 'روشن‌سازی' : 'حالت شب',
        onPressed: onToggleTheme,
        icon: Icon(
          isDarkMode ? Icons.light_mode_rounded : Icons.nightlight_round,
          color: colors.primary,
        ),
        iconSize: compact ? 20 : 23,
        padding: EdgeInsets.all(compact ? 8 : 12),
        constraints: BoxConstraints.tightFor(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.compact});
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: compact ? 24 : HesabTheme.fontPageTitle,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.compact,
  });

  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: HesabTheme.selectionSurface(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodButton(
              label: 'این ماه',
              selected: selectedPeriod == 0,
              compact: compact,
              onTap: () => onPeriodChanged(0),
            ),
            _PeriodButton(
              label: 'امسال',
              selected: selectedPeriod == 1,
              compact: compact,
              onTap: () => onPeriodChanged(1),
            ),
            _PeriodButton(
              label: 'دلخواه',
              selected: selectedPeriod == 2,
              compact: compact,
              onTap: () => onPeriodChanged(2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.surface
        : Colors.transparent,
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: compact ? 38 : 46,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: compact
                    ? HesabTheme.fontBody
                    : HesabTheme.fontControl,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
