import 'package:flutter_test/flutter_test.dart';
import 'package:hesab/core/calendar/jalali_date.dart';

void main() {
  test('converts known Nowruz boundaries and formats Afghan month names', () {
    final firstDay = JalaliDate.fromGregorian(DateTime(2024, 3, 20));
    expect((firstDay.year, firstDay.month, firstDay.day), (1403, 1, 1));
    final secondDay = JalaliDate.fromGregorian(DateTime(2024, 3, 21));
    expect((secondDay.year, secondDay.month, secondDay.day), (1403, 1, 2));
    expect(
      const JalaliDate(year: 1403, month: 1, day: 1).fullDate,
      '۱ حمل ۱۴۰۳',
    );
  });

  test('round trips the Jalali date through Gregorian', () {
    final date = const JalaliDate(year: 1405, month: 8, day: 27);
    expect(JalaliDate.fromGregorian(date.toGregorian()).year, date.year);
    expect(JalaliDate.fromGregorian(date.toGregorian()).month, date.month);
    expect(JalaliDate.fromGregorian(date.toGregorian()).day, date.day);
  });
}
