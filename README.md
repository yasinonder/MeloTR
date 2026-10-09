# MeloTR v0.1.0 — Android müzik çalar

MeloTR, MYT Müzik'ten ilham alan ancak **kendi özgün arayüzü** ve
**yerel/çevrimdışı müzik odaklı** yapısı olan Flutter Android uygulamasıdır.

## Çalışan kaynak kodunda olanlar

- Android medya izni ile telefondaki ses dosyalarını tarama
- Başlık / sanatçı / albüm bilgisini ve albüm kapağını gösterme
- Cihazdaki şarkıları oynatma, durdurma, ileri/geri sarma, sonraki/önceki
- Arka planda oynatma, Android medya bildirimi ve kilit ekranı kontrolleri
- Favorileri, dinleme geçmişini, özel çalma listelerini cihazda saklama
- Başlık / sanatçı / albüme göre arama
- Albüm ve sanatçı grupları, indirilenler klasörü filtresi
- Koyu tema, mini oynatıcı, tam ekran oynatıcı, 3 vurgu rengi
- Üyelik, reklam, ücretli servis veya internet zorunluluğu yok

**Not:** İnternetten veya YouTube'dan indirme mevcut değil. İndirilenler,
Android'in Downloads/Download klasöründe bulunup medya taramasına giren ses
dosyalarını gösterir. Mockuplardaki sanatçı fotoğrafları uygulamanın içinde
yer almaz; gerçek kapaklar telefondaki dosyaların metadata'sından okunur.

## GitHub'dan APK oluşturma (bilgisayarda Flutter gerektirmez)

1. GitHub hesabınızda `MeloTR` isimli **boş** bir repo oluşturun: https://github.com/new
   - **Add a README file** seçeneğini işaretleyin; depo `main` dalıyla hazır açılsın.
2. ChatGPT GitHub bağlantısına bu yeni repo için izin verin:
   https://github.com/settings/installations
   - ChatGPT için GitHub uygulamasının `Configure` bölümünde yeni `MeloTR` deposunu seçin.
3. Repo bağlantısını sohbet üzerinden iletin; asistan, dosyaları bu repoya aktarabilir.
   Alternatif olarak, bu ZIP dosyasının içindeki dosyaları GitHub'a yükleyin.
4. `.github/workflows/android-apk.yml` dosyası `main` dalına push edildiğinde
   otomatik çalışır. Elle başlatmak için `Actions` > `MeloTR - Android APK`
   > `Run workflow` (main) seçin.
5. Derleme yeşil olursa çalışma detayındaki `Artifacts` bölümünden
   `MeloTR-v0.1.0-APK` dosyasını indirin. İçindeki
   `MeloTR-v0.1.0-universal.apk` kurulabilir Android paketidir.
   `SHA256SUMS.txt` bütünlük kontrolü içindir.

**Not:** Burada Android SDK/Flutter ile APK doğrulaması yapılmadı.
GitHub Actions'da hata olursa o derlemenin loglarına göre kod güncellenmelidir.

## Bilgisayarda Flutter ile oluşturma

Flutter, Android SDK ve JDK kurulu olmalı:

```bash
flutter create --platforms=android --org com.melotr .
python3 tools/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK çıkışı: `build/app/outputs/flutter-apk/app-release.apk`

## İlk kullanım

1. Başla'ya basın.
2. Android'in müzik erişimi iznini onaylayın.
3. Şarkılardan birine basın, müzik çalmaya başlar.
4. Üç nokta üzerinden favoriye/listene ekleyin.
5. Müzik yoksa önce telefonunuza MP3/M4A/FLAC vb. ses dosyası koyun,
   ardından Ayarlar > Müzikleri yeniden tara seçeneğini kullanın.

## Teknik notlar

- Dart / Flutter, Material 3
- `on_audio_query_pluse`: Android MediaStore ses listesi (güncel Android eklentisi)
- `just_audio`: ses oynatma
- `just_audio_background` ve `audio_service`: arka plan medya kontrolü
- `shared_preferences`: küçük kişisel ayar ve liste kayıtları
- Ağ/sunucu, reklam SDK'sı veya izleme aracı eklenmedi.
- Kullanıcı verileri uygulama veri alanında tutulur. Uygulama kaldırılırsa
  yedeklenmemiş listeler ve favoriler silinebilir. Ses dosyaları silinmez.

## Test durumu

Kod oluşturuldu ve içerik/yapı kontrolleri uygulandı; bu çalışma ortamında
Flutter ve Android SDK olmadığı için fiziksel cihaz üzerinde doğrulanmış
APK derlemesi yapılmadı. CI iş akışı derleme/test için dahil edildi.
