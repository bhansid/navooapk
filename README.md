# Navoo

AI behaviour-change coach. Flutter app (`app/`) + coach API on Netlify (`server/`).

- Every push to `main` builds the Android APK and runs the full user journey on a virtual phone (Actions → "Build & test Navoo APK" → artifacts `navoo-apk` and `screenshots`).
- Optional build secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY` for real accounts with email verification. Without them, accounts are stored on the phone.
