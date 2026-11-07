# Navoo – Android demo app

Flow: Splash (auto 3 s, or tap "Get started") → Welcome → Log in → "Your development user is pending approval".
Any email + password (or Apple / Google buttons) leads to the pending-approval screen.

## Get the APK without installing anything (GitHub)
1. Create a new GitHub repo and upload everything in this folder (keep the `.github` folder).
2. Open the repo's **Actions** tab → "Build Navoo APK" runs automatically (or press *Run workflow*).
3. When it finishes (~4 min), open the run and download **navoo-apk** → `app-debug.apk`.
4. Copy it to an Android phone and install (allow "Install unknown apps").

## Or build in Android Studio
Open this folder → let it sync → Build ▸ Build APK(s). Output: `app/build/outputs/apk/debug/app-debug.apk`.
