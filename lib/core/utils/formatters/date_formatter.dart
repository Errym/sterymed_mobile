import 'package:intl/intl.dart';

abstract final class AppDateFormatter {
  static final _dayMonthYear = DateFormat('dd/MM/yyyy');
  static final _dayMonthYearTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _time = DateFormat('HH:mm');

  static String date(DateTime d) => _dayMonthYear.format(d);
  static String dateTime(DateTime d) => _dayMonthYearTime.format(d);
  static String time(DateTime d) => _time.format(d);

  static int daysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;
}
