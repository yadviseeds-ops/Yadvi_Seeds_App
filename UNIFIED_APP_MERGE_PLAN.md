# UNIFIED APP MERGE PLAN

## A. Existing Architecture
- **Field Executive App:** Flutter mobile app (`com.yadvi.field_executive_app`), containing role-specific features (visits, LR tracking, location, EOD).
- **Shop Owner App:** Flutter mobile app (`com.example.shop_owner_app`), containing features like products, cart, and order details. OTP authentication physically tested and verified.
- **Admin Module:** A React/Vite web application located at the root of the project.
- **Backend:** A unified FastAPI REST backend (`/backend`) providing data for all three roles.
- **Firebase:** Project `yadvi-seed-app-5f306` configured with both Android application IDs inside `google-services.json`.

## B. Proposed Unified Architecture
Create a single Flutter app conceptually based on the `shop_owner_app` (to preserve the physically tested Firebase configuration). 
**Structure:**
```
lib/
  core/
    auth/           (Unified AuthService)
    api/            (Unified API client)
    config/         (Common app_config.dart)
  features/
    common/         (LoginScreen, OtpScreen, RoleSelectionScreen)
    admin/          (WebView wrapper for React web app, or native Flutter Dashboard)
    field_executive/(Moved from field_executive_app/lib/features)
    shop_owner/     (Moved from shop_owner_app/lib/features)
  models/           (Merged models from both apps)
  services/         (Merged services)
```

## C. Files to Reuse
- `shop_owner_app/android/app/google-services.json` (Has keys for both, but we will use the `com.example.shop_owner_app` ID as the unified base to prevent breaking existing OTP verification).
- `shop_owner_app/lib/core/auth/auth_service.dart` (Already heavily tested for OTP).
- All UI screens in `field_executive_app/lib/features/` and `shop_owner_app/lib/features/` (to be reused exactly as they are, just moved into subfolders).

## D. Files to Move
- Move `field_executive_app/lib/features/*` into `unified_app/lib/features/field_executive/`.
- Move `shop_owner_app/lib/features/*` into `unified_app/lib/features/shop_owner/`.
- Move models from both apps into `unified_app/lib/models/`.
- Move API service layers (`fe_service.dart`, etc.) into `unified_app/lib/services/`.

## E. Files Requiring Import Changes
- ALL moved screens will require updated relative imports (e.g., `import '../../models/order.dart'` -> `import '../../../models/order.dart'`).
- The `main.dart` file will be entirely rewritten to route to the unified `RoleSelectionScreen` instead of directly to a specific role's login.

## F. Dependencies to Merge
- We will merge `pubspec.yaml` from both apps. 
- **Shop Owner:** `provider`, `firebase_auth`, `firebase_core`, `firebase_messaging`.
- **Field Executive:** `geolocator`, `flutter_secure_storage`.
- Conflicting versions will be upgraded to the highest common version (e.g., `firebase_auth: ^6.7.0` instead of `^5.7.0`).

## G. Firebase Configuration Plan
- We will use `com.example.shop_owner_app` (the Shop Owner app's Android project) as the shell for the unified app. 
- Why? Because it has been physically tested and verified to receive Firebase SMS OTPs successfully on a real device. Creating a new Application ID would require regenerating SHA-1/SHA-256 keys in the Firebase Console, risking the SMS quota and anti-abuse verification.
- The `google-services.json` is already valid for this package.

## H. Authentication Flow
1. Open App -> `RoleSelectionScreen`.
2. User selects a Role (Admin / Field Executive / Shop Owner).
3. App stores the *intended* role in memory.
4. User enters Mobile Number -> `LoginScreen` (Common).
5. Firebase OTP SMS is sent.
6. User enters OTP -> `OtpScreen` (Common).
7. Firebase ID Token generated.

## I. Role Authorization Flow (Crucial Security)
1. Flutter sends the Firebase ID Token to the FastAPI backend: `POST /api/v1/auth/login-firebase`.
2. The FastAPI backend verifies the token and retrieves the user's actual database role.
3. The backend returns a response: `{"access_token": "...", "role": "shop_owner", ...}`.
4. **Validation:** Flutter compares the user's *intended* role (from `RoleSelectionScreen`) with the backend's *actual* role.
5. If they mismatch (e.g., Shop Owner tries to log in as Admin), Flutter deletes the token and shows an error: `"Unauthorized: You do not have permission to access the Administrator module."`

## J. Navigation Flow
- If authorized -> Save JWT securely.
- If actual role == "administrator" -> Navigate to `AdminDashboardScreen`.
- If actual role == "field_executive" -> Navigate to `FEDashboardScreen`.
- If actual role == "shop_owner" -> Navigate to `ShopOwnerDashboardScreen`.

## K. Risks/Conflicts
- **Model Name Conflicts:** Both apps might have a `Order` model with slightly different fields. We will need to unify them into a single `order_model.dart` that contains all fields, or alias them.
- **Admin Module Integration:** The Admin module is currently a React web application. Blindly porting it to Flutter is risky and time-consuming. **Safest approach:** We use the `webview_flutter` package to render the existing hosted React Admin dashboard inside the Flutter app for Admin users, providing a seamless "one-app" experience without destroying or rewriting the working React code.

## L. Exact Implementation Order
1. **Prepare Shell:** Use `shop_owner_app` as the base. Create the new folder structure (`lib/features/common`, `lib/features/field_executive`, etc.).
2. **Merge Dependencies:** Update `pubspec.yaml` with packages from both apps.
3. **Common Login:** Move the OTP and Login screens to `features/common/` and implement the `RoleSelectionScreen`.
4. **Backend Authorization Hook:** Update `AuthService` to compare the selected role with the backend-returned role.
5. **Migrate Shop Owner:** Move existing Shop Owner screens into `features/shop_owner/` and fix imports.
6. **Migrate Field Executive:** Copy Field Exec screens into `features/field_executive/`, copy unique models/services, and fix imports.
7. **Admin WebView:** Create `features/admin/admin_webview_screen.dart` to load the React app.
8. **Navigation:** Update `main.dart` to route authenticated users to their respective dashboards based on the backend role.
9. **Test:** Verify login, role rejection (security), and logout for all three roles.
