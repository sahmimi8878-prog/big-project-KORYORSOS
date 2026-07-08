import 'package:intl/intl.dart';

class DateUtil {
  static  getFormattedDate(DateTime dt) {
    String formattedDate = DateFormat('dd-MM-yyyy').format(dt);

    return formattedDate;
  }
}