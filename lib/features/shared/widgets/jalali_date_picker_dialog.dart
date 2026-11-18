import 'package:material_ui/material_ui.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../core/theme/hesab_theme.dart';
import '../../../core/text/name_normalizer.dart';

Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  required DateTime initialDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => JalaliDatePickerDialog(initialDate: initialDate),
);

class JalaliDatePickerDialog extends StatefulWidget {
  const JalaliDatePickerDialog({required this.initialDate, super.key});
  final DateTime initialDate;

  @override
  State<JalaliDatePickerDialog> createState() => _JalaliDatePickerDialogState();
}

class _JalaliDatePickerDialogState extends State<JalaliDatePickerDialog> {
  late JalaliDate _visibleMonth;
  late JalaliDate _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = JalaliDate.fromGregorian(widget.initialDate);
    _visibleMonth = _selectedDate;
  }

  void _moveMonth(int offset) {
    var year = _visibleMonth.year;
    var month = _visibleMonth.month + offset;
    if (month < 1) {
      month = 12;
      year--;
    } else if (month > 12) {
      month = 1;
      year++;
    }
    setState(() {
      _visibleMonth = JalaliDate(year: year, month: month, day: 1);
      if (_selectedDate.year != year || _selectedDate.month != month) {
        _selectedDate = _visibleMonth;
      }
    });
  }

  Future<void> _chooseYear() async {
    final year = await showDialog<int>(
      context: context,
      builder: (_) => _YearDialog(initialYear: _visibleMonth.year),
    );
    if (year == null) return;
    setState(() {
      _visibleMonth = JalaliDate(
        year: year,
        month: _visibleMonth.month,
        day: 1,
      );
      _selectedDate = _visibleMonth;
    });
  }

  void _selectToday() {
    final today = JalaliDate.fromGregorian(DateTime.now());
    setState(() {
      _visibleMonth = today;
      _selectedDate = today;
    });
  }

  int get _daysInMonth {
    if (_visibleMonth.month <= 6) return 31;
    if (_visibleMonth.month <= 11) return 30;
    try {
      JalaliDate(year: _visibleMonth.year, month: 12, day: 30).toGregorian();
      return 30;
    } on ArgumentError {
      return 29;
    }
  }

  int get _firstDayOffset {
    final date = JalaliDate(
      year: _visibleMonth.year,
      month: _visibleMonth.month,
      day: 1,
    ).toGregorian();
    // Afghan weeks begin on Saturday.
    return (date.weekday + 1) % 7;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dialogWidth = (MediaQuery.sizeOf(context).width - 40)
        .clamp(250.0, 338.0)
        .toDouble();
    final cells = _firstDayOffset + _daysInMonth;
    final rowCount = (cells / 7).ceil();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'ماه پیش',
                        onPressed: () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _chooseYear,
                          child: Text(
                            _visibleMonth.monthAndYear,
                            style: const TextStyle(
                              fontSize: HesabTheme.fontSection,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'ماه بعد',
                        onPressed: () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: HesabTheme.fontCaption,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  for (var row = 0; row < rowCount; row++)
                    Row(
                      children: [
                        for (var column = 0; column < 7; column++)
                          Expanded(
                            child: _dayCell(
                              row * 7 + column - _firstDayOffset + 1,
                              colors,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectToday,
                        icon: const Icon(Icons.today_rounded, size: 18),
                        label: const Text('امروز'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text('لغو'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedDate.toGregorian()),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('تأیید'),
                      ),
                    ],
                  ),
                  Text(
                    'تاریخ انتخاب‌شده: ${_selectedDate.fullDate}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: HesabTheme.fontCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayCell(int day, ColorScheme colors) {
    if (day < 1 || day > _daysInMonth) {
      return const SizedBox(height: 36);
    }
    final today = JalaliDate.fromGregorian(DateTime.now());
    final isSelected =
        _selectedDate.year == _visibleMonth.year &&
        _selectedDate.month == _visibleMonth.month &&
        _selectedDate.day == day;
    final isToday =
        today.year == _visibleMonth.year &&
        today.month == _visibleMonth.month &&
        today.day == day;
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isSelected ? colors.primary : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(
              () => _selectedDate = JalaliDate(
                year: _visibleMonth.year,
                month: _visibleMonth.month,
                day: day,
              ),
            ),
            child: Center(
              child: Text(
                _dariDigits(day),
                style: TextStyle(
                  fontSize: HesabTheme.fontCaption,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dariDigits(int value) => value.toString().replaceAllMapped(
    RegExp(r'\d'),
    (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 1728),
  );
}

class _YearDialog extends StatefulWidget {
  const _YearDialog({required this.initialYear});
  final int initialYear;

  @override
  State<_YearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends State<_YearDialog> {
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: '${widget.initialYear}');
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('رفتن به سال جلالی'),
    content: TextField(
      controller: _year,
      autofocus: true,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'سال',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
      FilledButton(onPressed: _submit, child: const Text('رفتن')),
    ],
  );

  void _submit() {
    final year = int.tryParse(NameNormalizer.normalize(_year.text));
    if (year != null && year >= 1 && year <= 9999) {
      Navigator.pop(context, year);
    }
  }
}
