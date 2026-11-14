p = 'flutter_apps/admin_app/lib/features/reports/eod_report_details_screen.dart'
with open(p, 'r', encoding='utf-8') as f:
    c = f.read().replace('\r\n', '\n')
c = c.replace('if (v.purpose != null && v.purpose!.isNotEmpty)', 'if (v.purpose.isNotEmpty)')
with open(p, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(c)

p2 = 'flutter_apps/admin_app/lib/features/reports/eod_reports_screen.dart'
with open(p2, 'r', encoding='utf-8') as f:
    c2 = f.read().replace('\r\n', '\n')
c2 = c2.replace("import '../../models/eod_model.dart';\n", "")
with open(p2, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(c2)
print('Fixed warnings in admin_app successfully')

