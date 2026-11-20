const afghanJalaliMonths = <String>[
  'حمل',
  'ثور',
  'جوزا',
  'سرطان',
  'اسد',
  'سنبله',
  'میزان',
  'عقرب',
  'قوس',
  'جدی',
  'دلو',
  'حوت',
];

class JalaliDate {
  const JalaliDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String get monthName => afghanJalaliMonths[month - 1];

  String get monthAndYear => '$monthName ${_dariDigits(year.toString())}';

  String get fullDate =>
      '${_dariDigits(day.toString())} $monthName ${_dariDigits(year.toString())}';

  factory JalaliDate.fromGregorian(DateTime date) {
    const daysBeforeGregorianMonth = <int>[
      0,
      31,
      59,
      90,
      120,
      151,
      181,
      212,
      243,
      273,
      304,
      334,
    ];

    final gy = date.year;
    final gm = date.month;
    final gyForLeap = gm > 2 ? gy + 1 : gy;
    var days =
        355666 +
        365 * gy +
        (gyForLeap + 3) ~/ 4 -
        (gyForLeap + 99) ~/ 100 +
        (gyForLeap + 399) ~/ 400 +
        date.day +
        daysBeforeGregorianMonth[gm - 1];

    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = days < 186 ? 1 + days % 31 : 1 + (days - 186) % 30;
    return JalaliDate(year: jy, month: jm, day: jd);
  }

  DateTime toGregorian() {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw ArgumentError('Invalid Afghan Jalali date.');
    }
    final jalaliYear = year + 1595;
    var days =
        -355668 +
        365 * jalaliYear +
        (jalaliYear ~/ 33) * 8 +
        ((jalaliYear % 33 + 3) ~/ 4) +
        day +
        (month < 7 ? (month - 1) * 31 : (month - 7) * 30 + 186);

    var gregorianYear = 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gregorianYear += 100 * ((days - 1) ~/ 36524);
      days = (days - 1) % 36524;
      if (days >= 365) days++;
    }
    gregorianYear += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gregorianYear += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    var gregorianDay = days + 1;
    final leap =
        (gregorianYear % 4 == 0 && gregorianYear % 100 != 0) ||
        gregorianYear % 400 == 0;
    const monthLengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var gregorianMonth = 1;
    for (var index = 0; index < monthLengths.length; index++) {
      final length = monthLengths[index] + (index == 1 && leap ? 1 : 0);
      if (gregorianDay <= length) {
        gregorianMonth = index + 1;
        break;
      }
      gregorianDay -= length;
    }
    final gregorian = DateTime(gregorianYear, gregorianMonth, gregorianDay);
    final roundTrip = JalaliDate.fromGregorian(gregorian);
    if (roundTrip.year != year ||
        roundTrip.month != month ||
        roundTrip.day != day) {
      throw ArgumentError('Invalid Afghan Jalali date.');
    }
    return gregorian;
  }
}

String _dariDigits(String value) => value;
