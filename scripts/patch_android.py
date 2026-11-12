"""Applies Navoo's Android settings on top of the files `flutter create` generates. Run from app/."""
import os, re, shutil, glob

root = 'android/app'
# Gradle: desugaring (needed by notifications), minSdk 23
g = root + '/build.gradle.kts' if os.path.exists(root + '/build.gradle.kts') else root + '/build.gradle'
s = open(g).read()
kts = g.endswith('.kts')
if 'CoreLibraryDesugaring' not in s and 'coreLibraryDesugaring' not in s:
    s = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        ' + ('isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'), s, count=1)
    s += ('\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' if kts
          else "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n")
s = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', s)
s = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', s)
s = re.sub(r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"', s)
open(g, 'w').write(s)

# Manifest
m = root + '/src/main/AndroidManifest.xml'
x = open(m).read()
perms = ''.join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in
                ['INTERNET', 'POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED', 'VIBRATE', 'SET_WALLPAPER'])
perms += '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>\n'
if 'SET_WALLPAPER' not in x:
    x = x.replace('<application', perms + '    <application', 1)
x = re.sub(r'android:label="[^"]*"', 'android:label="Navoo"', x, count=1)
receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if 'ScheduledNotificationReceiver' not in x:
    x = x.replace('</application>', receivers + '    </application>', 1)
cal = '''        <intent>
            <action android:name="android.intent.action.INSERT" />
            <data android:mimeType="vnd.android.cursor.item/event" />
        </intent>
'''
if '<queries>' in x and 'cursor.item/event' not in x:
    x = x.replace('<queries>', '<queries>\n' + cal, 1)
elif '<queries>' not in x:
    x = x.replace('</manifest>', '    <queries>\n' + cal + '    </queries>\n</manifest>')
deep = '''            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.navoo.navoo" android:host="login-callback" />
            </intent-filter>
        </activity>'''
if 'login-callback' not in x:
    x = x.replace('        </activity>', deep, 1)
open(m, 'w').write(x)

# MainActivity with the wallpaper channel
for f in glob.glob(root + '/src/main/kotlin/**/MainActivity.kt', recursive=True) + glob.glob(root + '/src/main/java/**/MainActivity.java', recursive=True):
    os.remove(f)
dst = root + '/src/main/kotlin/com/navoo/navoo'
os.makedirs(dst, exist_ok=True)
shutil.copy('branding/android/kotlin/MainActivity.kt', dst + '/MainActivity.kt')

# Launcher icons
for d in glob.glob('branding/android/mipmap-*'):
    shutil.copy(d + '/ic_launcher.png', root + '/src/main/res/' + os.path.basename(d) + '/ic_launcher.png')

# Default sample test is not ours
if os.path.exists('test/widget_test.dart'):
    os.remove('test/widget_test.dart')
print('patched', g, m)
