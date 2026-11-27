import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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

  Future<void> _chooseDate() async {
    final date = await showDialog<JalaliDate>(
      context: context,
      builder: (_) => _DateInputDialog(initialDate: _selectedDate),
    );
    if (date == null) return;
    setState(() {
      _visibleMonth = JalaliDate(year: date.year, month: date.month, day: 1);
      _selectedDate = date;
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
                          onPressed: _chooseDate,
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

  String _dariDigits(int value) => value.toString();
}

class _DateInputDialog extends StatefulWidget {
  const _DateInputDialog({required this.initialDate});
  final JalaliDate initialDate;

  @override
  State<_DateInputDialog> createState() => _DateInputDialogState();
}

class _DateInputDialogState extends State<_DateInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final year = widget.initialDate.year;
    final month = widget.initialDate.month.toString().padLeft(2, '0');
    final day = widget.initialDate.day.toString().padLeft(2, '0');
    final formatted = '$year-$month-$day';
    _controller = TextEditingController(
      text: formatted,
    )..selection = TextSelection(baseOffset: 0, extentOffset: formatted.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: const Text('رفتن به تاریخ جلالی'),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.datetime,
          inputFormatters: [JalaliDateInputFormatter()],
          decoration: InputDecoration(
            labelText: 'تاریخ (سال-ماه-روز)',
            hintText: '1403-01-01',
            helperText: 'مثال: ۱۴۰۳-۰۸-۱۵',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        FilledButton(onPressed: _submit, child: const Text('رفتن')),
      ],
    ),
  );

  void _submit() {
    final raw = NameNormalizer.normalize(_controller.text).replaceAll('/', '-');
    final parts = raw
        .split('-')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      setState(() => _errorText = 'لطفاً تاریخ را وارد کنید.');
      return;
    }

    int? year;
    var month = widget.initialDate.month;
    var day = widget.initialDate.day;

    if (parts.length == 1 && parts[0].length == 8) {
      year = int.tryParse(parts[0].substring(0, 4));
      final parsedMonth = int.tryParse(parts[0].substring(4, 6));
      final parsedDay = int.tryParse(parts[0].substring(6, 8));
      if (parsedMonth == null || parsedMonth < 1 || parsedMonth > 12) {
        setState(() => _errorText = 'ماه باید بین ۱ تا ۱۲ باشد.');
        return;
      }
      if (parsedDay == null || parsedDay < 1 || parsedDay > 31) {
        setState(() => _errorText = 'روز باید بین ۱ تا ۳۱ باشد.');
        return;
      }
      month = parsedMonth;
      day = parsedDay;
    } else {
      year = int.tryParse(parts[0]);
      if (parts.length >= 2) {
        final parsedMonth = int.tryParse(parts[1]);
        if (parsedMonth == null || parsedMonth < 1 || parsedMonth > 12) {
          setState(() => _errorText = 'ماه باید بین ۱ تا ۱۲ باشد.');
          return;
        }
        month = parsedMonth;
        day = 1;
      }

      if (parts.length >= 3) {
        final parsedDay = int.tryParse(parts[2]);
        if (parsedDay == null || parsedDay < 1 || parsedDay > 31) {
          setState(() => _errorText = 'روز باید بین ۱ تا ۳۱ باشد.');
          return;
        }
        day = parsedDay;
      }
    }

    if (year == null || year < 1 || year > 9999) {
      setState(() => _errorText = 'سال واردشده معتبر نیست.');
      return;
    }

    try {
      final jalaliDate = JalaliDate(year: year, month: month, day: day);
      jalaliDate.toGregorian();
      Navigator.pop(context, jalaliDate);
    } catch (_) {
      setState(() => _errorText = 'تاریخ جلالی واردشده معتبر نیست.');
    }
  }
}

class JalaliDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    if (oldValue.text.endsWith('-') &&
        newValue.text == oldValue.text.substring(0, oldValue.text.length - 1)) {
      final truncated = oldValue.text.substring(0, oldValue.text.length - 2);
      return TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
    }

    var raw = NameNormalizer.normalize(newValue.text).replaceAll('/', '-');
    raw = raw.replaceAll(RegExp(r'[^0-9\-]'), '');

    final parts = raw.split('-');
    final buffer = StringBuffer();

    if (parts.isNotEmpty) {
      final yearPart = parts[0];
      if (yearPart.length <= 4) {
        buffer.write(yearPart);
        if (parts.length > 1) {
          buffer.write('-');
        }
      } else {
        buffer.write(yearPart.substring(0, 4));
        buffer.write('-');
        final extra = yearPart.substring(4);
        if (parts.length == 1) {
          parts.add(extra);
        } else {
          parts[1] = extra + parts[1];
        }
      }
    }

    if (parts.length > 1) {
      final monthPart = parts[1];
      if (monthPart.length <= 2) {
        buffer.write(monthPart);
        if (parts.length > 2) {
          buffer.write('-');
        }
      } else {
        buffer.write(monthPart.substring(0, 2));
        buffer.write('-');
        final extra = monthPart.substring(2);
        if (parts.length == 2) {
          parts.add(extra);
        } else {
          parts[2] = extra + parts[2];
        }
      }
    }

    if (parts.length > 2) {
      final dayPart = parts[2];
      buffer.write(dayPart.length > 2 ? dayPart.substring(0, 2) : dayPart);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
