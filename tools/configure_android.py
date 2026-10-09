#!/usr/bin/env python3
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'android/app/src/main/AndroidManifest.xml'
s=p.read_text()
if 'xmlns:tools=' not in s:
    s=s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ',1)
perms=[
 ('android.permission.READ_MEDIA_AUDIO',None),
 ('android.permission.READ_EXTERNAL_STORAGE',32),
 ('android.permission.FOREGROUND_SERVICE',None),
 ('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',None),
 ('android.permission.WAKE_LOCK',None),
 ('android.permission.POST_NOTIFICATIONS',None),
]
for name,maxsdk in perms:
    if f'android:name="{name}"' not in s:
        att=f' android:maxSdkVersion="{maxsdk}"' if maxsdk else ''
        s=s.replace('<application',f'<uses-permission android:name="{name}"{att}/>\n    <application',1)
s=re.sub(r'android:label="melotr"','android:label="MeloTR"',s,count=1)
s=re.sub(r'android:name="(?:\.MainActivity|[\w.]+MainActivity)"','android:name="com.ryanheise.audioservice.AudioServiceActivity"',s,count=1)
services="""
        <service android:name="com.ryanheise.audioservice.AudioService"
          android:foregroundServiceType="mediaPlayback"
          android:exported="true" tools:ignore="Instantiatable">
          <intent-filter>
            <action android:name="android.media.browse.MediaBrowserService"/>
          </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
          android:exported="true" tools:ignore="Instantiatable">
          <intent-filter>
            <action android:name="android.intent.action.MEDIA_BUTTON"/>
          </intent-filter>
        </receiver>
"""
if 'android:name="com.ryanheise.audioservice.AudioService"' not in s:
    s=s.replace('</application>',services+'</application>',1)
p.write_text(s)
print('MeloTR Android izinleri ve servisleri hazir.')
