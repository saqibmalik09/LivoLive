class NumberFormatter {
  NumberFormatter._();

  static String format(int number) {
    final bool isNegative = number < 0;
    final int absNumber = number.abs();

    String result;
    if (absNumber >= 1000000) {
      double value = absNumber / 1000000.0;
      result = value % 1 == 0
          ? '${value.toInt()}M'
          : '${value.toStringAsFixed(1)}M';
    } else if (absNumber >= 1000) {
      double value = absNumber / 1000.0;
      result = value % 1 == 0
          ? '${value.toInt()}K'
          : '${value.toStringAsFixed(1)}K';
    } else {
      result = absNumber.toString();
    }

    return isNegative ? '-$result' : result;
  }
}
