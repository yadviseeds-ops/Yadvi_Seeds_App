import os, re, json

apps = ['unified_app', 'admin_app', 'field_executive_app', 'shop_owner_app']
results = {}

for app in apps:
    app_dir = os.path.join('flutter_apps', app)
    res = {'name': app}
    
    # 1. build.gradle
    bg_path = os.path.join(app_dir, 'android', 'app', 'build.gradle')
    if os.path.exists(bg_path):
        with open(bg_path, 'r', encoding='utf-8', errors='ignore') as f:
            bg_text = f.read()
            m_id = re.search(r'applicationId\s+["\']([^"\']+)["\']', bg_text)
            m_ns = re.search(r'namespace\s+["\']([^"\']+)["\']', bg_text)
            res['applicationId'] = m_id.group(1) if m_id else None
            res['namespace'] = m_ns.group(1) if m_ns else None
            res['has_google_services_plugin'] = 'com.google.gms.google-services' in bg_text
            res['has_play_integrity'] = 'play-services-integrity' in bg_text
    
    # 2. pubspec.yaml dependencies
    pub_path = os.path.join(app_dir, 'pubspec.yaml')
    if os.path.exists(pub_path):
        with open(pub_path, 'r', encoding='utf-8', errors='ignore') as f:
            pub_text = f.read()
            res['firebase_core'] = re.findall(r'firebase_core:\s*([^\r\n]+)', pub_text)
            res['firebase_auth'] = re.findall(r'firebase_auth:\s*([^\r\n]+)', pub_text)
            res['firebase_messaging'] = re.findall(r'firebase_messaging:\s*([^\r\n]+)', pub_text)
    
    # 3. google-services.json
    gs_path = os.path.join(app_dir, 'android', 'app', 'google-services.json')
    if os.path.exists(gs_path):
        with open(gs_path, 'r', encoding='utf-8', errors='ignore') as f:
            try:
                gs_data = json.load(f)
                res['project_info'] = gs_data.get('project_info')
                res['clients'] = []
                for cl in gs_data.get('client', []):
                    cinfo = cl.get('client_info', {})
                    pkg = cinfo.get('android_client_info', {}).get('package_name')
                    appid = cinfo.get('mobilesdk_app_id')
                    certs = [c.get('sha1_hash') for c in cl.get('oauth_client', []) if c.get('sha1_hash')]
                    res['clients'].append({
                        'package': pkg,
                        'app_id': appid,
                        'oauth_sha1_hashes': certs
                    })
            except Exception as e:
                res['gs_error'] = str(e)
    
    # 4. firebase_options.dart
    fo_path = os.path.join(app_dir, 'lib', 'firebase_options.dart')
    if os.path.exists(fo_path):
        with open(fo_path, 'r', encoding='utf-8', errors='ignore') as f:
            fo_text = f.read()
            res['has_firebase_options'] = True
            # extract android target options
            m_android = re.search(r'static const FirebaseOptions android = FirebaseOptions\((.*?)\);', fo_text, re.DOTALL)
            if m_android:
                lines = m_android.group(1).splitlines()
                res['android_options'] = [l.strip() for l in lines if 'apiKey' not in l and l.strip()]
    else:
        res['has_firebase_options'] = False
        
    # 5. main.dart initialization
    main_path = os.path.join(app_dir, 'lib', 'main.dart')
    if os.path.exists(main_path):
        with open(main_path, 'r', encoding='utf-8', errors='ignore') as f:
            main_text = f.read()
            res['firebase_init_code'] = [l.strip() for l in main_text.splitlines() if 'Firebase.initializeApp' in l or 'DefaultFirebaseOptions' in l]

    results[app] = res

print(json.dumps(results, indent=2))

