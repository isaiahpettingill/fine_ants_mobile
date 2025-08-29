String formatDateTimeShort(DateTime dt) {
  final local = dt.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final m = months[local.month - 1];
  final day = local.day;
  final year = local.year;
  var hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$m $day, $year · $hour:$minute $ampm';
}

