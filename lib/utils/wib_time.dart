import 'package:intl/intl.dart';

class WibTime {
  static const Duration _wibOffset = Duration(hours: 7);

  static DateTime now() => toWib(DateTime.now());

  static DateTime toWib(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    return utc.add(_wibOffset);
  }

  static String clock(DateTime value) {
    final wib = toWib(value);
    return '${DateFormat('HH:mm', 'id_ID').format(wib)} WIB';
  }

  static String dateLabel(DateTime value, {DateTime? nowWib}) {
    final wib = toWib(value);
    final nowValue = nowWib ?? WibTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);
    final thatDay = DateTime(wib.year, wib.month, wib.day);
    final dayDiff = today.difference(thatDay).inDays;

    if (dayDiff == 0) return 'Hari ini';
    if (dayDiff == 1) return 'Kemarin';
    return DateFormat('dd MMM yyyy', 'id_ID').format(wib);
  }

  static String relative(DateTime value, {DateTime? nowWib}) {
    final nowValue = nowWib ?? WibTime.now();
    final wib = toWib(value);
    final diff = nowValue.difference(wib);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';
    return '${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(wib)} WIB';
  }
}
