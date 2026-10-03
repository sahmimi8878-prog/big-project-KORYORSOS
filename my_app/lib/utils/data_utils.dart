import 'package:intl/intl.dart';

class DateUtil {
  static  getFormattedDate(DateTime dt) {
    String formattedDate = DateFormat('dd-MM-yyyy').format(dt);

    return formattedDate;
  }

  static String getThaiDate(DateTime dt) {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];

    return '${dt.day} ${months[dt.month - 1]} ${dt.year + 543}';
  }
}