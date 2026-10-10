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


## MeloTR 0.1.2 — İzinli dosyalardan MP3 oluşturma

- İndirilenler sayfasından telefondaki video/ses dosyasını seç, veya indirilebilir doğrudan HTTPS video/ses URL'sini gir.
- FFmpeg ile MP3'e dönüştür (128, 192, 256, 320 kbps).
- MediaStore ile Android Music/MeloTR klasörüne kaydet ve MeloTR kütüphanesini yenile.
- MP3 kaydı doğrulanana kadar geçici videoyu tut. Doğrulamadan sonra sadece uygulamanın geçici videosunu sil. Kullanıcıya ait orijinal dosyalara asla dokunma.
- YouTube araması YouTube'u açar; YouTube izleme sayfasından MP3 indirme desteklenmez.
- Derlemede eski arşivin en güncel kaynak kodunu ezmesi engellendi.

## MeloTR v0.1.3 — YouTube arama ve görselli sonuçlar

Ara > YouTube bölümünde şarkı veya sanatçı arandığında ilgili video başlıkları,
kanal adları ve kapak resimleri gösterilir. YouTube video URL'si de doğrudan
arama kutusuna yapıştırılabilir. Video satırına basıldığında resmi olmayan
YoutubeExplode istemcisiyle ses akışı alınır, FFmpeg ile MP3'e dönüştürülür ve
MediaStore üzerinden MeloTR müzik kütüphanesine eklenir. 128-320 kbps ayarlanır.
MP3 kaydı başarıyla doğrulanırsa sadece uygulamanın geçici ses/video dosyası
silinir, kullanıcıya ait orijinal dosyalara dokunulmaz.

**Kısıtlar:** Bu resmi YouTube API özelliği değildir; YouTube istemcilerinde
olan değişiklikler, erişim ve içerik kısıtlamaları veya Javascript doğrulaması
bazı içeriklerde bu deneysel yöntemi engelleyebilir. YouTube'un geliştirici
politikaları, yazılı izin olmadan platform içeriklerinin indirilip çevrimdışı
saklanmasına izin vermez. Yalnızca indirme yetkiniz olan içeriklerde kullanın.

## v0.1.4 – YouTube'da sonsuz yükleme göstergesi düzeltmesi

YouTube ses manifesti 35 saniye, indirme akışının iki veri paketi arası 25 saniye,
tüm indirme 5 dakika, FFmpeg dönüştürmesi 3 dakika ve MediaStore kaydı 45 saniye
ile sınırlandırıldı. Aşama durumları ve indirilen MB ile yüzde gösteriliyor.
Zaman aşımında hata ve tekrar deneme düğmesi görünür; kullanıcı sonsuz dönen
yükleme ekranında kalmaz. MP3 kaydı tamamlanmışsa, medya taramasının gecikmesi
başarı durumunu engellemez. YouTube erişimi ve gerçek indirme başarısı,
YouTube tarafından sınırlanabilir; cihaz üzerinde ayrıca denenmelidir.

## v0.1.5 – İndirilmeyi iptal et

YouTube indirmesi sırasında **İndirmeyi iptal et** düğmesi gösterilir.
Buton bağlantı/akış beklemelerini ve aktif ses aktarımını iptal eder;
FFmpeg dönüştürme başlamışsa dönüşümü de durdurmayı dener.
Kullanıcı iptalinde uygulamaya ait eksik/geçici dosyalar temizlenir;
telefondan önceden seçilen orijinal videolara dokunulmaz.
Android MediaStore'a MP3 kaydetme son aşamasında kayıt bütünlüğü için
iptal devre dışı kalır. İptal davranışı için otomatik testler eklendi.

## v0.1.6 – YouTube ses akışında alternatif denemeler

İndirme aşaması 2/4'te ses verisi alamazsa 18 saniyelik hareketsizlikten sonra başka bir ses kalitesi/biçimi otomatik denenir (en fazla üç akış). İndirilen MB ve kaçıncı akışın denendiği görüntülenir. Her akışın etkin aktarımı iki dakika ile sınırlıdır. Başarısız denemeler gerekçeli hata gösterir ve eksik geçici dosyaları temizler. Gerçek YouTube indirme başarısı, YouTube'un erişim kısıtlarına bağlıdır.
