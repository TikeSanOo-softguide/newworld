/// Detail-page amount text for 总分, 投注, limits, and history.
///
/// The profile and socket send a number (`DECIMAL(10, 2)` rounded to two
/// places). `1500.00`, `970.00`, and `2100.00` therefore arrive as whole
/// numbers and print without a decimal. A fractional value keeps the digits
/// it actually has. `970.5` stays `970.5` and is not padded to `970.50`.
String formatDetailAmount(num amount) =>
    amount == amount.roundToDouble() ? amount.toInt().toString() : '$amount';
