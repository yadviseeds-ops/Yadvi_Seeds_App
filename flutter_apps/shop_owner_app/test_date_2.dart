void main() {
  String dateStr = "2026-10-07T15:12:47Z";
  DateTime dt = DateTime.parse(dateStr);
  print("Parsed: $dt");
  print("Parsed UTC: ${dt.isUtc}");
  
  DateTime localDt = dt.toLocal();
  print("Local: $localDt");
  print("Local UTC: ${localDt.isUtc}");
}
