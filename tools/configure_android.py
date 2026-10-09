#!/usr/bin/env python3
"""Patch AndroidManifest after `flutter create --platforms=android .`.
Idempotent; uses stdlib only. Run from the project root.
"""
from pathlib import Path
import re
import shutil

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Önce `flutter create --platforms=android --org com.melotr .` çalıştırın.')
source = manifest.read_text(encoding='utf-8')
if 'xmlns:tools=' not in source:
    source = source.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
permissions = [
    ('android.permission.READ_MEDIA_AUDIO', None),
    ('android.permission.READ_EXTERNAL_STORAGE', '32'),
    ('android.permission.FOREGROUND_SERVICE', None),
    ('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK', None),
    ('android.permission.WAKE_LOCK', None),
    ('android.permission.POST_NOTIFICATIONS', None),
    ('android.permission.INTERNET', None),
    ('android.permission.WRITE_EXTERNAL_STORAGE', '29'),
]
for p, maxsdk in permissions:
    if f'android:name="{p}"' not in source:
        max_part = f' android:maxSdkVersion="{maxsdk}"' if maxsdk else ''
        source = source.replace('<application', f'<uses-permission android:name="{p}"{max_part}/>\n    <application', 1)
source = re.sub(r'android:label="melotr"', 'android:label="MeloTR"', source, count=1)
source = re.sub(r'android:name="(?:\.MainActivity|[\w.]+MainActivity)"',
    'android:name="com.ryanheise.audioservice.AudioServiceActivity"', source, count=1)
services = '''
        <!-- Android media background service -->
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''
if 'android:name="com.ryanheise.audioservice.AudioService"' not in source:
    source = source.replace('</application>', services + '    </application>', 1)
if 'android:requestLegacyExternalStorage=' not in source:
    source = source.replace('<application ', '<application android:requestLegacyExternalStorage="true" ', 1)
manifest.write_text(source, encoding='utf-8')
for density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']:
    source_icon = root / f'assets/icons/mipmap-{density}/ic_launcher.png'
    target = root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    if source_icon.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_icon, target)
print('Android izinleri, medya servisi ve MeloTR ikonu eklendi.')
