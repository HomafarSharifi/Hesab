import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../core/finance/amount_codec.dart';
import '../../../core/theme/hesab_theme.dart';

class ExpenseTrendCard extends StatelessWidget {
  const ExpenseTrendCard({required this.monthlyExpenses, super.key});
  final Map<String, int> monthlyExpenses;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentJalaliYear = JalaliDate.fromGregorian(DateTime.now()).year;
    final values = List<int>.generate(
      12,
      (index) =>
          monthlyExpenses['$currentJalaliYear-${(index + 1).toString().padLeft(2, '0')}'] ??
          0,
    );
    final hasData = values.any((value) => value > 0);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(HesabTheme.cardRadius),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        MediaQuery.sizeOf(context).width < 600 ? 14 : 20,
        18,
        MediaQuery.sizeOf(context).width < 600 ? 14 : 20,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'روند مصارف',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChartGridPainter(
                      color: colors.outlineVariant.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                if (hasData)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TrendPainter(
                        values: values,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Center(
                    child: Text(
                      'در این دوره مصرفی ثبت نشده است',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: HesabTheme.fontBody,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final month in afghanJalaliMonths)
                  Flexible(
                    child: Text(
                      month,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: HesabTheme.fontCaption,
                        color: colors.onSurface,
                      ),
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

class _ChartGridPainter extends CustomPainter {
  const _ChartGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<int>(0, math.max).toDouble();
    if (maxValue <= 0) return;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y =
          size.height -
          (values[index] / maxValue) * size.height * 0.84 -
          size.height * 0.08;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
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
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      canvas.drawArc(
        rect,
        start,
        sweep,
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
