import zipfile

apk_path = r'C:\Users\Acer\.gemini\antigravity\scratch\yadvi-seeds-app\flutter_apps\unified_app\build\app\outputs\flutter-apk\app-release.apk'
search_strings = [
    b'fe_profile_total_assigned_shops',
    b'fe_profile_completed_visits',
    b'Total Assigned Shops',
    b'Verified & recorded',
    b'This information is assigned and managed by Admin',
    b'Total Orders',
    b'Select Report Date',
    b'Exit Application',
    b'yadvi-day1-test-f5upp75xna-el.a.run.app'
]

with zipfile.ZipFile(apk_path, 'r') as z:
    arm64 = z.read('lib/arm64-v8a/libapp.so')
    print(f'libapp.so size: {len(arm64)} bytes')
    for s in search_strings:
        found = s in arm64
        status = "FOUND" if found else "NOT FOUND"
        print(f'Looking for [{s.decode()}]: {status}')
