void main() {
  String dateStr = "2026-10-07T15:12:47";
  if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
    dateStr += 'Z';
  }
  DateTime dt = DateTime.tryParse(dateStr)!.toLocal();
  DateTime now = DateTime.now();
  print("Parsed: $dt");
  print("Now: $now");
  print("Is today? ${dt.year == now.year && dt.month == now.month && dt.day == now.day}");
}
