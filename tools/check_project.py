#!/usr/bin/env python3
"""Kaynak paket üzerinde hızlı, SDK gerektirmeyen bütünlük kontrolü."""
from pathlib import Path
import re
import yaml

root = Path(__file__).resolve().parents[1]
config = yaml.safe_load((root / 'pubspec.yaml').read_text())
assert config['name'] == 'melotr'
assert len(list((root / 'assets/icons').rglob('ic_launcher.png'))) == 5
for filename in ['lib/main.dart', 'lib/music_library.dart',
                 'tools/configure_android.py', 'test/widget_test.dart',
                 '.github/workflows/android-apk.yml']:
    assert (root / filename).is_file(), filename
for name in ['HomePage', 'SearchPage', 'LibraryPage', 'DownloadsPage',
             'SettingsPage', 'NowPlayingPage', 'MiniPlayer']:
    assert f'class {name} ' in (root / 'lib/main.dart').read_text(), name
assert 'flutter build apk --release' in (root / '.github/workflows/android-apk.yml').read_text()
assert 'on_audio_query_pluse' in config['dependencies']
assert re.search(r'Future<void> playSongs', (root/'lib/music_library.dart').read_text())
print('Proje dosyaları, ikonlar, ekranlar, paketler ve CI tanımı: TAMAM')
