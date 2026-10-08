import os
import shutil
import re

FE_LIB = r"c:\Users\Acer\.gemini\antigravity\scratch\yadvi-seeds-app\flutter_apps\field_executive_app\lib"
SO_LIB = r"c:\Users\Acer\.gemini\antigravity\scratch\yadvi-seeds-app\flutter_apps\shop_owner_app\lib"
SO_ROOT = r"c:\Users\Acer\.gemini\antigravity\scratch\yadvi-seeds-app\flutter_apps\shop_owner_app"

def copy_and_update_features():
    src_features = os.path.join(FE_LIB, "features")
    dest_features = os.path.join(SO_LIB, "features", "field_executive")
    
    if not os.path.exists(dest_features):
        os.makedirs(dest_features)
        
    for item in os.listdir(src_features):
        if item == "auth":
            continue
        src_path = os.path.join(src_features, item)
        dest_path = os.path.join(dest_features, item)
        
        if os.path.isdir(src_path):
            if os.path.exists(dest_path):
                shutil.rmtree(dest_path)
            shutil.copytree(src_path, dest_path)

    # Walk through the copied files and update imports
    for root, dirs, files in os.walk(dest_features):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # Update relative imports from 2 levels up to 3 levels up
                content = re.sub(r"import '\.\./\.\./core/", r"import '../../../core/", content)
                content = re.sub(r"import '\.\./\.\./services/", r"import '../../../services/", content)
                content = re.sub(r"import '\.\./\.\./models/", r"import '../../../models/", content)
                
                # Update logout routing
                content = content.replace("import '../auth/login_screen.dart';", "import '../../auth/role_selection_screen.dart';")
                content = content.replace("const LoginScreen()", "const RoleSelectionScreen()")
                
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)

def copy_models_and_services():
    # Copy Models
    src_models = os.path.join(FE_LIB, "models")
    dest_models = os.path.join(SO_LIB, "models")
    for item in os.listdir(src_models):
        shutil.copy2(os.path.join(src_models, item), os.path.join(dest_models, item))
        
    # Copy Services
    src_services = os.path.join(FE_LIB, "services")
    dest_services = os.path.join(SO_LIB, "services")
    for item in os.listdir(src_services):
        shutil.copy2(os.path.join(src_services, item), os.path.join(dest_services, item))

def update_pubspec():
    pubspec_path = os.path.join(SO_ROOT, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    if "geolocator:" not in content:
        content = content.replace("dependencies:\n  flutter:\n    sdk: flutter", "dependencies:\n  flutter:\n    sdk: flutter\n  geolocator: ^14.0.2")
        with open(pubspec_path, "w", encoding="utf-8") as f:
            f.write(content)

def update_manifest():
    manifest_path = os.path.join(SO_ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    if "android.permission.ACCESS_FINE_LOCATION" not in content:
        permissions = '''    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n'''
        content = content.replace("<application", permissions + "    <application")
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)

if __name__ == "__main__":
    copy_and_update_features()
    copy_models_and_services()
    update_pubspec()
    update_manifest()
    print("Integration copy script complete.")
