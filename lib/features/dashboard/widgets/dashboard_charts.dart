import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../data/models/catalog_models.dart';

class ItemExpenseTrendCard extends StatefulWidget {
  const ItemExpenseTrendCard({
    required this.items,
    required this.loadMonthlyExpenses,
    super.key,
  });

  final List<ItemRecord> items;
  final Future<Map<String, int>> Function({
    required int itemId,
    required int jalaliYear,
  })
  loadMonthlyExpenses;

  @override
  State<ItemExpenseTrendCard> createState() => _ItemExpenseTrendCardState();
}

class _ItemExpenseTrendCardState extends State<ItemExpenseTrendCard> {
  int? _itemId;
  int _year = JalaliDate.fromGregorian(DateTime.now()).year;
  bool _yearView = false;
  int? _hoveredIndex;
  String? _requestedKey;
  Future<Map<String, int>>? _chartFuture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedId = widget.items.any((item) => item.id == _itemId)
        ? _itemId!
        : widget.items.isEmpty
        ? null
        : widget.items.first.id;
    final chartKey = '$selectedId-$_year-$_yearView';
    if (selectedId != null && chartKey != _requestedKey) {
      _requestedKey = chartKey;
      _chartFuture = _yearView
          ? _loadYearlyExpenses(selectedId)
          : widget.loadMonthlyExpenses(itemId: selectedId, jalaliYear: _year);
    }
    final currentJalaliYear = JalaliDate.fromGregorian(DateTime.now()).year;
    final years = List<int>.generate(101, (index) => currentJalaliYear - index);
    final selectedItem = widget.items.where((item) => item.id == selectedId);
    final selectedItemName = selectedItem.isEmpty
        ? 'انتخاب جنس'
        : selectedItem.first.name;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'مصارف جنس در ${_yearView ? 'سال‌ها' : 'ماه‌ها'}',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FilterMenuButton<bool>(
                label: _yearView ? 'سال‌ها' : 'ماه‌ها',
                selected: _yearView,
                options: const [(false, 'ماه‌ها'), (true, 'سال‌ها')],
                onSelected: (value) => setState(() {
                  _yearView = value;
                  _hoveredIndex = null;
                }),
              ),
              if (!_yearView)
                _FilterMenuButton<int>(
                  label: _chartDariDigits(_year.toString()),
                  selected: _year,
                  options: [
                    for (final year in years)
                      (year, _chartDariDigits(year.toString())),
                  ],
                  onSelected: (value) => setState(() {
                    _year = value;
                    _hoveredIndex = null;
                  }),
                ),
              _FilterMenuButton<int>(
                label: selectedItemName,
                selected: selectedId,
                enabled: widget.items.isNotEmpty,
                options: [
                  for (final item in widget.items) (item.id, item.name),
                ],
                onSelected: (value) => setState(() {
                  _itemId = value;
                  _hoveredIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: selectedId == null
                ? Center(
                    child: Text(
                      'برای نمایش نمودار، جنس ثبت کنید.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : FutureBuilder<Map<String, int>>(
                    key: ValueKey('$selectedId-$_year-$_yearView'),
                    future: _chartFuture,
                    builder: (context, snapshot) {
                      final chartYears = List<int>.generate(
                        5,
                        (i) => _year - 4 + i,
                      );
                      final labels = _yearView
                          ? chartYears
                                .map(
                                  (year) => _chartDariDigits(year.toString()),
                                )
                                .toList()
                          : afghanJalaliMonths;
                      final values = _yearView
                          ? List<int>.generate(
                              5,
                              (i) => snapshot.data?['${chartYears[i]}'] ?? 0,
                            )
                          : List<int>.generate(
                              12,
                              (i) =>
                                  snapshot.data?[(i + 1).toString().padLeft(
                                    2,
                                    '0',
                                  )] ??
                                  0,
                            );
                      final currentMonthIndex =
                          JalaliDate.fromGregorian(DateTime.now()).month - 1;
                      final active =
                          (_hoveredIndex ??
                                  (_yearView
                                      ? values.length - 1
                                      : currentMonthIndex))
                              .clamp(0, values.length - 1)
                              .toInt();
                      return Column(
                        children: [
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const LinearProgressIndicator(minHeight: 2),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) => MouseRegion(
                                onHover: (event) {
                                  final slot = box.maxWidth / values.length;
                                  final index = (event.localPosition.dx / slot)
                                      .floor()
                                      .clamp(0, values.length - 1)
                                      .toInt();
                                  if (_hoveredIndex != index) {
                                    setState(() => _hoveredIndex = index);
                                  }
                                },
                                onExit: (_) =>
                                    setState(() => _hoveredIndex = null),
                                child: CustomPaint(
                                  size: Size(box.maxWidth, box.maxHeight),
                                  painter: _ReferencePillBars(
                                    values: values,
                                    labels: labels,
                                    activeIndex: active,
                                    colors: colors,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _loadYearlyExpenses(int itemId) async {
    final chartYears = List<int>.generate(5, (i) => _year - 4 + i);
    final annual = await Future.wait([
      for (final year in chartYears)
        widget.loadMonthlyExpenses(itemId: itemId, jalaliYear: year),
    ]);
    return {
      for (var i = 0; i < chartYears.length; i++)
        '${chartYears[i]}': annual[i].values.fold<int>(
          0,
          (sum, amount) => sum + amount,
        ),
    };
  }
}

class _FilterMenuButton<T> extends StatelessWidget {
  const _FilterMenuButton({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final T? selected;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38, maxWidth: 190),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 19,
                color: enabled
                    ? colors.primary
                    : colors.onSurfaceVariant.withValues(alpha: .5),
              ),
            ],
          ),
        ),
      ),
    );
    return PopupMenuButton<T>(
      enabled: enabled,
      initialValue: selected,
      tooltip: label,
      constraints: const BoxConstraints(
        minWidth: 0,
        maxWidth: 360,
        maxHeight: 6 * 48,
      ),
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final (value, optionLabel) in options)
          PopupMenuItem<T>(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value == selected)
                  Icon(Icons.check_rounded, color: colors.primary, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    optionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: child,
    );
  }
}

class _ReferencePillBars extends CustomPainter {
  const _ReferencePillBars({
    required this.values,
    required this.labels,
    required this.activeIndex,
    required this.colors,
  });
  final List<int> values;
  final List<String> labels;
  final int activeIndex;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.isEmpty) return;
    const left = 36.0, right = 4.0, top = 20.0, bottom = 25.0;
    final width = size.width - left - right,
        height = size.height - top - bottom;
    if (width <= 0 || height <= 0) return;
    final maxValue = values.fold<int>(1, (a, b) => a > b ? a : b);
    final max = _chartCeiling(maxValue);
    for (var i = 0; i <= 4; i++) {
      final y = top + height * (1 - i / 4);
      final paint = Paint()
        ..color = colors.outlineVariant.withValues(alpha: .7)
        ..strokeWidth = 1;
      for (var x = left; x < size.width - right; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width - right).toDouble(), y),
          paint,
        );
      }
      _barText(
        canvas,
        _compactChartAmount((max * i / 4).round()),
        TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
        Offset(left - 3, y),
        true,
      );
    }
    final slot = width / values.length;
    final barWidth = (slot * .52).clamp(7.0, 28.0).toDouble();
    for (var i = 0; i < values.length; i++) {
      final barHeight = height * (values[i] / max).clamp(0.0, 1.0).toDouble();
      final cx = left + slot * (i + .5);
      final rect = Rect.fromLTWH(
        cx - barWidth / 2,
        top + height - barHeight,
        barWidth,
        barHeight,
      );
      final radius = RRect.fromRectAndRadius(
        rect,
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(
        radius,
        Paint()
          ..color = i == activeIndex
              ? colors.primary
              : colors.primary.withValues(alpha: .34),
      );
      canvas.save();
      canvas.clipRRect(radius);
      for (var x = rect.left - barHeight; x < rect.right + barHeight; x += 7) {
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x - barHeight * .55, rect.bottom),
          Paint()
            ..color = Colors.white.withValues(alpha: .22)
            ..strokeWidth = 1.4,
        );
      }
      canvas.restore();
      if (i == activeIndex && values[i] > 0) {
        final label = _barTextPainter(
          AmountCodec.formatMoneyMinor(values[i]),
          TextStyle(
            color: colors.onPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        );
        final bw = math.min(label.width + 12, size.width - 2);
        final bx = (cx - bw / 2).clamp(1.0, size.width - bw - 1).toDouble();
        final by = math.max(1.0, rect.top - label.height - 7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, label.height + 5),
            const Radius.circular(10),
          ),
          Paint()..color = colors.primary,
        );
        label.paint(canvas, Offset(bx + (bw - label.width) / 2, by + 2));
      }
      _barText(
        canvas,
        labels[i],
        TextStyle(
          color: i == activeIndex ? colors.onSurface : colors.onSurfaceVariant,
          fontSize: 8,
          fontWeight: i == activeIndex ? FontWeight.w700 : FontWeight.w400,
        ),
        Offset(cx, size.height - bottom + 4),
        false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReferencePillBars old) =>
      old.values != values ||
      old.activeIndex != activeIndex ||
      old.colors != colors;
}

int _chartCeiling(int value) {
  if (value <= 100) return 100;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
  final normalized = value / magnitude;
  final step = normalized <= 1.5
      ? 1.5
      : normalized <= 2
      ? 2.0
      : normalized <= 3
      ? 3.0
      : normalized <= 5
      ? 5.0
      : normalized <= 8
      ? 8.0
      : 10.0;
  return (step * magnitude).ceil();
}

String _compactChartAmount(int minor) {
  final value = minor ~/ 100;
  final label = value >= 1000
      ? '${(value / 1000).round()}هزار'
      : value.toString();
  return _chartDariDigits(label);
}

String _chartDariDigits(String value) => value;
TextPainter _barTextPainter(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.rtl,
)..layout();
void _barText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset point,
  bool right,
) {
  final painter = _barTextPainter(text, style);
  painter.paint(
    canvas,
    Offset(
      right ? point.dx - painter.width : point.dx - painter.width / 2,
      point.dy - painter.height / 2,
    ),
  );
}

class ExpenseTrendCard extends StatefulWidget {
  const ExpenseTrendCard({
    required this.monthlyExpenses,
    required this.dailyExpenses,
    required this.fromDate,
    required this.toDate,
    required this.selectedPeriod,
    super.key,
  });
  final Map<String, int> monthlyExpenses;
  final Map<String, int> dailyExpenses;
  final DateTime fromDate;
  final DateTime? toDate;
  final int selectedPeriod;

  @override
  State<ExpenseTrendCard> createState() => _ExpenseTrendCardState();
}

class _ExpenseTrendCardState extends State<ExpenseTrendCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rangeDays = (widget.toDate ?? DateTime.now())
        .difference(widget.fromDate)
        .inDays;
    final weeklyView =
        widget.selectedPeriod == 0 ||
        (widget.selectedPeriod == 2 && rangeDays <= 45);
    final month = JalaliDate.fromGregorian(widget.fromDate);
    final labels = weeklyView
        ? List<String>.generate(5, (index) => 'هفته ${index + 1}')
        : afghanJalaliMonths;
    final values = weeklyView
        ? List<int>.filled(5, 0)
        : List<int>.generate(12, (index) {
            final key =
                '${month.year}-${(index + 1).toString().padLeft(2, '0')}';
            return widget.monthlyExpenses[key] ?? 0;
          });
    if (weeklyView) {
      for (final entry in widget.dailyExpenses.entries) {
        final date = JalaliDate.fromGregorian(DateTime.parse(entry.key));
        if (date.year == month.year && date.month == month.month) {
          final week = ((date.day - 1) ~/ 7).clamp(0, 4);
          values[week] += entry.value;
        }
      }
    }
    final peak = values.indexOf(values.reduce((a, b) => a > b ? a : b));
    final focusIndex = (_hoveredIndex ?? peak)
        .clamp(0, values.length - 1)
        .toInt();
    final hasData = values.any((value) => value > 0);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weeklyView ? 'روند مصارف هفتگی' : 'روند مصارف ماهانه',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      weeklyView ? 'مصارف هفته‌های ماه' : 'مقایسه مصارف 12 ماه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${labels[focusIndex]}: ${AmountCodec.formatMoneyMinor(values[focusIndex])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: hasData
                ? LayoutBuilder(
                    builder: (context, constraints) => MouseRegion(
                      onHover: (event) {
                        const leftPad = 46.0, rightPad = 14.0;
                        final step =
                            (constraints.maxWidth - leftPad - rightPad) /
                            (values.length - 1);
                        final index =
                            ((event.localPosition.dx - leftPad) / step)
                                .round()
                                .clamp(0, values.length - 1)
                                .toInt();
                        if (index != _hoveredIndex) {
                          setState(() => _hoveredIndex = index);
                        }
                      },
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _ReferenceMonthlyLinePainter(
                          months: labels,
                          values: values,
                          activeIndex: focusIndex,
                          border: colors.outlineVariant,
                          muted: colors.onSurfaceVariant,
                          primary: colors.primary,
                          accent: colors.tertiary,
                          surface: colors.surface,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'در این دوره مصرفی ثبت نشده است',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ReferenceCategoryBreakdownCard extends StatefulWidget {
  const ReferenceCategoryBreakdownCard({
    required this.categories,
    required this.purchaseCounts,
    required this.totalMinor,
    super.key,
  });

  final Map<String, int> categories;
  final Map<String, int> purchaseCounts;
  final int totalMinor;

  @override
  State<ReferenceCategoryBreakdownCard> createState() =>
      _ReferenceCategoryBreakdownCardState();
}

class _ReferenceCategoryBreakdownCardState
    extends State<ReferenceCategoryBreakdownCard> {
  int? _hoveredIndex;

  static const Color _kActiveLime = Color(0xFF7FDF3C);
  static const Color _kActiveGreenText = Color(0xFF3E9B12);

  int? _hitTest(Offset point, Size size, List<int> values, int total) {
    if (values.isEmpty || total <= 0) return null;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2 - 4;
    final innerR = outerR * 0.59;
    final distance = (point - center).distance;
    if (distance < innerR - 6 || distance > outerR + 6) {
      return null;
    }

    // Matches the top-centered arch of the largest category
    final firstSweep = values.first / total * math.pi * 2;
    final startOffset = -math.pi / 2 - firstSweep / 2;
    final rawAngle = math.atan2(point.dy - center.dy, point.dx - center.dx);
    var angle = (rawAngle - startOffset) % (math.pi * 2);
    if (angle < 0) angle += math.pi * 2;

    var start = 0.0;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      if (angle >= start && angle <= start + sweep) return index;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final entries = widget.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final values = entries.map((entry) => entry.value).toList();
    final total = values.fold<int>(0, (sum, value) => sum + value);

    final inactiveGray =
        isDark ? const Color(0xFF424E48) : const Color(0xFF9EA09F);
    final innerFill =
        isDark ? const Color(0xFF1A2621) : const Color(0xFFF7F7F7);
    final innerBorder =
        isDark ? const Color(0xFF283932) : const Color(0xFFECEEEE);
    final accentReadable = isDark ? _kActiveLime : _kActiveGreenText;

    final largest =
        values.isEmpty ? 0 : values.indexOf(values.reduce(math.max));
    final activeIndex = _hoveredIndex != null && _hoveredIndex! < entries.length
        ? _hoveredIndex!
        : largest;
    final active = entries.isEmpty ? null : entries[activeIndex];
    final share =
        active == null || total == 0 ? 0.0 : active.value / total * 100;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded, size: 19, color: colors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مصارف براساس دسته‌بندی',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      _hoveredIndex == null
                          ? 'پیش‌فرض: بیشترین دسته مصرف'
                          : 'جزئیات دسته انتخاب‌شده',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              _CategoryShareBadge(
                share: share,
                color: accentReadable,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  flex: 48,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Center(
                        child: MouseRegion(
                          onHover: (event) {
                            final next = _hitTest(
                              event.localPosition,
                              Size(side, side),
                              values,
                              total,
                            );
                            if (next != _hoveredIndex) {
                              setState(() => _hoveredIndex = next);
                            }
                          },
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: Size.square(side),
                                  painter: _ReferenceDonutPainter(
                                    values: values,
                                    activeIndex: activeIndex,
                                    activeColor: _kActiveLime,
                                    inactiveColor: inactiveGray,
                                    innerFillColor: innerFill,
                                    innerBorderColor: innerBorder,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(side * .25),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        active?.key ?? 'مجموع مصارف',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          AmountCodec.formatMoneyMinor(
                                            active?.value ?? widget.totalMinor,
                                          ),
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (active != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_chartDariDigits((widget.purchaseCounts[active.key] ?? 0).toString())} خرید',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: accentReadable,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  flex: 52,
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'پس از ثبت مصارف، دسته‌ها این‌جا دیده می‌شوند.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (
                              var index = 0;
                              index < math.min(entries.length, 4);
                              index++
                            )
                              _ReferenceCategoryRow(
                                name: entries[index].key,
                                amount: entries[index].value,
                                color: index == activeIndex
                                    ? _kActiveLime
                                    : inactiveGray,
                                active: index == activeIndex,
                                onHover: (hovering) => setState(
                                  () => _hoveredIndex = hovering ? index : null,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceDonutPainter extends CustomPainter {
  const _ReferenceDonutPainter({
    required this.values,
    required this.activeIndex,
    this.activeColor = const Color(0xFF7FDF3C),
    this.inactiveColor = const Color(0xFF9EA09F),
    this.innerFillColor = const Color(0xFFF7F7F7),
    this.innerBorderColor = const Color(0xFFECEEEE),
  });

  final List<int> values;
  final int activeIndex;
  final Color activeColor;
  final Color inactiveColor;
  final Color innerFillColor;
  final Color innerBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2 - 4;
    final innerR = outerR * 0.59;
    final gapPx = math.max(2.6, outerR * 0.028);

    // Soft inner circle (#F7F7F7) separated by a crisp gap from the ring
    final discR = math.max(0.0, innerR - gapPx);
    canvas.drawCircle(center, discR, Paint()..color = innerFillColor);
    canvas.drawCircle(
      center,
      discR,
      Paint()
        ..color = innerBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (values.isEmpty || total <= 0) {
      final emptyRing = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: center, radius: outerR))
        ..addOval(Rect.fromCircle(center: center, radius: innerR));
      canvas.drawPath(emptyRing, Paint()..color = inactiveColor.withAlpha(80));
      return;
    }

    // Centers the largest category across the top arch (9 o'clock -> 3 o'clock at 50%)
    final firstSweep = values.first / total * math.pi * 2;
    var startAngle = -math.pi / 2 - firstSweep / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;

      final path = _buildRoundedSectorPath(
        center: center,
        outerR: outerR,
        innerR: innerR,
        startAngle: startAngle,
        sweep: sweep,
        gapPx: values.length > 1 ? gapPx : 0.0,
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = i == activeIndex ? activeColor : inactiveColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      startAngle += sweep;
    }
  }

  Path _buildRoundedSectorPath({
    required Offset center,
    required double outerR,
    required double innerR,
    required double startAngle,
    required double sweep,
    required double gapPx,
  }) {
    if (sweep >= math.pi * 2 - 0.001 || gapPx <= 0.0) {
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: center, radius: outerR))
        ..addOval(Rect.fromCircle(center: center, radius: innerR));
    }

    final thickness = outerR - innerR;
    final sinHalf = math.sin(math.min(sweep * 0.46, math.pi * 0.48));
    final h = math.min(gapPx / 2.0, innerR * sinHalf * 0.72);

    final cOut = math.max(
      0.0,
      math.min(
        math.min(outerR * 0.095, thickness * 0.45),
        (outerR * sinHalf - h) / (1.0 + sinHalf),
      ),
    );
    final cIn = math.max(
      0.0,
      math.min(
        math.min(outerR * 0.070, thickness * 0.40),
        (innerR * sinHalf - h) / math.max(1e-6, 1.0 - sinHalf),
      ),
    );

    final a0 = startAngle;
    final a1 = startAngle + sweep;
    final alphaOut = math.asin(((h + cOut) / (outerR - cOut)).clamp(-1.0, 1.0));
    final alphaIn = math.asin(((h + cIn) / (innerR + cIn)).clamp(-1.0, 1.0));

    Offset polar(double rad, double ang) =>
        Offset(center.dx + rad * math.cos(ang), center.dy + rad * math.sin(ang));

    final cOs = polar(outerR - cOut, a0 + alphaOut);
    final cOe = polar(outerR - cOut, a1 - alphaOut);
    final cIe = polar(innerR + cIn, a1 - alphaIn);
    final cIs = polar(innerR + cIn, a0 + alphaIn);

    final path = Path();

    if (cOut > 0.2) {
      path.arcTo(
        Rect.fromCircle(center: cOs, radius: cOut),
        a0 - math.pi / 2,
        math.pi / 2 + alphaOut,
        true,
      );
    } else {
      final p = polar(outerR, a0 + alphaOut);
      path.moveTo(p.dx, p.dy);
    }

    path.arcTo(
      Rect.fromCircle(center: center, radius: outerR),
      a0 + alphaOut,
      math.max(0.0, sweep - 2 * alphaOut),
      false,
    );

    if (cOut > 0.2) {
      path.arcTo(
        Rect.fromCircle(center: cOe, radius: cOut),
        a1 - alphaOut,
        math.pi / 2 + alphaOut,
        false,
      );
    }

    if (cIn > 0.2) {
      path.arcTo(
        Rect.fromCircle(center: cIe, radius: cIn),
        a1 + math.pi / 2,
        math.pi / 2 - alphaIn,
        false,
      );
    }

    path.arcTo(
      Rect.fromCircle(center: center, radius: innerR),
      a1 - alphaIn,
      -math.max(0.0, sweep - 2 * alphaIn),
      false,
    );

    if (cIn > 0.2) {
      path.arcTo(
        Rect.fromCircle(center: cIs, radius: cIn),
        a0 + alphaIn - math.pi,
        math.pi / 2 - alphaIn,
        false,
      );
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ReferenceDonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.innerFillColor != innerFillColor;
}

class _CategoryShareBadge extends StatelessWidget {
  const _CategoryShareBadge({required this.share, required this.color});
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      '${_chartDariDigits(share.toStringAsFixed(1))}٪',
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class _ReferenceCategoryRow extends StatelessWidget {
  const _ReferenceCategoryRow({
    required this.name,
    required this.amount,
    required this.color,
    required this.active,
    required this.onHover,
  });
  final String name;
  final int amount;
  final Color color;
  final bool active;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => onHover(true),
    onExit: (_) => onHover(false),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Text(
              AmountCodec.formatMoneyMinor(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    required this.categories,
    required this.totalMinor,
    super.key,
  });

  final Map<String, int> categories;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = <Color>[
      const Color(0xFF66D82D),
      colors.primary,
      const Color(0xFF4E8ADF),
      const Color(0xFFF0B942),
      const Color(0xFFAB72C4),
      const Color(0xFFE57C68),
    ];
    final entries = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        MediaQuery.sizeOf(context).width < 600 ? 14 : 18,
        18,
        MediaQuery.sizeOf(context).width < 600 ? 14 : 18,
        16,
      ),
      child: Column(
        children: [
          Text(
            'مصارف براساس دسته‌بندی:',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min(constraints.maxWidth * 0.66, 230.0);
              return SizedBox(
                width: diameter,
                height: diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(diameter),
                      painter: _CategoryRingPainter(
                        values: entries.map((entry) => entry.value).toList(),
                        colors: palette,
                        emptyColor: colors.outlineVariant.withValues(
                          alpha: 0.68,
                        ),
                        strokeWidth: diameter * 0.16,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(diameter * 0.22),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'مجموع مصارف',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: HesabTheme.fontCaption,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            child: Text(
                              AmountCodec.formatMoneyMinor(totalMinor),
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: HesabTheme.fontBody,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          if (entries.isEmpty)
            Text(
              'پس از ثبت مصارف، دسته‌بندی‌ها در این‌جا دیده می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: HesabTheme.fontCaption,
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 14,
              runSpacing: 8,
              children: [
                for (
                  var index = 0;
                  index < math.min(entries.length, 4);
                  index++
                )
                  _CategoryLegend(
                    name: entries[index].key,
                    amount: entries[index].value,
                    color: palette[index % palette.length],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.name,
    required this.amount,
    required this.color,
  });

  final String name;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        '$name: ${AmountCodec.formatMoneyMinor(amount)}',
        style: const TextStyle(fontSize: HesabTheme.fontCaption),
      ),
    ],
  );
}

class _ReferenceMonthlyLinePainter extends CustomPainter {
  const _ReferenceMonthlyLinePainter({
    required this.months,
    required this.values,
    required this.activeIndex,
    required this.border,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.surface,
  });

  final List<String> months;
  final List<int> values;
  final int activeIndex;
  final Color border;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const leftPad = 46.0, rightPad = 14.0, topPad = 22.0, bottomPad = 25.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0) return;
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final maxValue = _chartCeiling(math.max(rawMax, 1));
    final gridPaint = Paint()
      ..color = border.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final ratio = i / 4;
      final y = topPad + chartHeight * (1 - ratio);
      _drawReferenceDashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      _referenceChartText(
        canvas,
        _compactChartAmount((maxValue * ratio).round()),
        TextStyle(color: muted, fontSize: 9),
        rightOfX: leftPad - 6,
        centerY: y,
      );
    }
    final stepX = chartWidth / (values.length - 1);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          leftPad + stepX * i,
          topPad + chartHeight * (1 - (values[i] / maxValue).clamp(0.0, 1.0)),
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final midX = (points[i].dx + points[i + 1].dx) / 2;
      line.cubicTo(
        midX,
        points[i].dy,
        midX,
        points[i + 1].dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, topPad + chartHeight)
      ..lineTo(points.first.dx, topPad + chartHeight)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topPad),
          Offset(0, topPad + chartHeight),
          [
            primary.withValues(alpha: .28),
            accent.withValues(alpha: .07),
            primary.withValues(alpha: 0),
          ],
          const [0, .65, 1],
        ),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
    final focus = points[activeIndex.clamp(0, points.length - 1)];
    _drawReferenceDashedLine(
      canvas,
      Offset(focus.dx, topPad),
      Offset(focus.dx, topPad + chartHeight),
      Paint()
        ..color = primary.withValues(alpha: .4)
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      focus,
      7,
      Paint()..color = primary.withValues(alpha: .22),
    );
    canvas.drawCircle(focus, 4.5, Paint()..color = surface);
    canvas.drawCircle(
      focus,
      4.5,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var i = 0; i < months.length; i++) {
      final focused = i == activeIndex;
      _referenceChartText(
        canvas,
        months[i],
        TextStyle(
          color: focused ? primary : muted,
          fontSize: 9,
          fontWeight: focused ? FontWeight.w800 : FontWeight.w500,
        ),
        centerX: points[i].dx,
        topY: topPad + chartHeight + 5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceMonthlyLinePainter old) =>
      old.values != values ||
      old.activeIndex != activeIndex ||
      old.border != border ||
      old.muted != muted ||
      old.primary != primary ||
      old.accent != accent ||
      old.surface != surface;
}

TextPainter _referenceChartTextPainter(String text, TextStyle style) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
    )..layout();

void _referenceChartText(
  Canvas canvas,
  String text,
  TextStyle style, {
  double? centerX,
  double? rightOfX,
  double? topY,
  double? centerY,
}) {
  final painter = _referenceChartTextPainter(text, style);
  final dx = centerX != null
      ? centerX - painter.width / 2
      : rightOfX! - painter.width;
  final dy = centerY != null ? centerY - painter.height / 2 : topY!;
  painter.paint(canvas, Offset(dx, dy));
}

void _drawReferenceDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
) {
  const dash = 4.0, gap = 4.0;
  final dx = end.dx - start.dx, dy = end.dy - start.dy;
  final distance = math.sqrt(dx * dx + dy * dy);
  if (distance == 0) return;
  final unitX = dx / distance, unitY = dy / distance;
  for (var offset = 0.0; offset < distance; offset += dash + gap) {
    final stop = math.min(offset + dash, distance);
    canvas.drawLine(
      Offset(start.dx + unitX * offset, start.dy + unitY * offset),
      Offset(start.dx + unitX * stop, start.dy + unitY * stop),
      paint,
    );
  }
}

class _CategoryRingPainter extends CustomPainter {
  const _CategoryRingPainter({
    required this.values,
    required this.colors,
    required this.emptyColor,
    required this.strokeWidth,
  });

  final List<int> values;
  final List<Color> colors;
  final Color emptyColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = emptyColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
      return;
    }
    var start = -math.pi / 2;
    final gap = values.length > 1 ? 0.055 : 0.0;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      canvas.drawArc(
        rect,
        start + math.min(gap / 2, sweep * .3),
        math.max(.02, sweep - math.min(gap, sweep * .6)),
        false,
        Paint()
          ..color = colors[index % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryRingPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
