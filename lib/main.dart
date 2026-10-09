import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:url_launcher/url_launcher.dart';

import 'music_library.dart';

const _bg = Color(0xFF090D18);
const _surface = Color(0xFF151B2C);
const _muted = Color(0xFF9AA3BB);
const _pink = Color(0xFFF1377E);
const _violet = Color(0xFF9A4FF3);
const _blue = Color(0xFF35B0E7);
const _white = Color(0xFFF7F7FD);
const _accents = [_pink, _violet, _blue];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.melotr.music.playback',
    androidNotificationChannelName: 'MeloTR müzik çalma',
    androidNotificationOngoing: true,
  );
  runApp(const MeloTRApp());
}

class MeloTRApp extends StatefulWidget {
  const MeloTRApp({super.key});
  @override
  State<MeloTRApp> createState() => _MeloTRAppState();
}

class _MeloTRAppState extends State<MeloTRApp> {
  final MusicLibrary library = MusicLibrary();

  @override
  void initState() {
    super.initState();
    unawaited(library.init());
  }

  @override
  void dispose() {
    library.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: library,
    builder: (context, _) {
      final accent = _accents[library.accentIndex.clamp(0, 2).toInt()];
      final theme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: Colors.white24,
          thumbColor: accent,
          overlayColor: accent.withOpacity(.14),
          trackHeight: 3,
        ),
        snackBarTheme: const SnackBarThemeData(backgroundColor: _surface),
      );
      return MaterialApp(
        title: 'MeloTR',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: !library.initialized
            ? const LoadingScreen()
            : (!library.introSeen
                ? WelcomeScreen(onBegin: library.completeIntro)
                : MainShell(library: library)),
      );
    },
  );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _Logo(size: 44), SizedBox(height: 28), CircularProgressIndicator(),
    ])),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({this.size = 31});
  final double size;
  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(style: TextStyle(fontSize: size, fontWeight: FontWeight.w900,
        letterSpacing: -1.6), children: const [
      TextSpan(text: 'Melo', style: TextStyle(color: _white)),
      TextSpan(text: 'TR', style: TextStyle(color: _pink)),
    ]),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onBegin});
  final Future<void> Function() onBegin;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      const Positioned.fill(child: _AmbientBackground()),
      SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(children: [
          const Spacer(flex: 2),
          Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_violet, _pink]),
                boxShadow: [BoxShadow(color: _pink.withOpacity(.35), blurRadius: 80, spreadRadius: 12)]),
            child: const Icon(Icons.graphic_eq_rounded, size: 94)),
          const SizedBox(height: 44),
          const _Logo(size: 56),
          const SizedBox(height: 12),
          const Text('Müziğin Yeni Ritmi', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, color: _muted, letterSpacing: 2)),
          const SizedBox(height: 18),
          const Text('Müziklerin, listelerin ve favorilerin tek bir yerde.\nİnternetsiz, özgürce dinle.',
              textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.55)),
          const Spacer(flex: 2),
          SizedBox(width: double.infinity, height: 58,
            child: FilledButton.icon(onPressed: onBegin,
              style: FilledButton.styleFrom(backgroundColor: _pink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('Başla', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 18),
          const Text('Üyelik gerektirmez • Yerel müzik arşivin', style: TextStyle(color: _muted)),
          const SizedBox(height: 38),
        ]))),
    ]),
  );
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF1E1035), _bg, Color(0xFF2C0A26)])),
    child: CustomPaint(painter: _OrbitPainter()),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3;
    for (var i = 0; i < 12; i++) {
      paint.color = (i.isEven ? _pink : _violet).withOpacity(.08 + .013 * (i % 5));
      canvas.drawOval(Rect.fromCenter(
        center: Offset(size.width * .66, size.height * .38),
        width: 140.0 + i * 52, height: 150.0 + i * 73), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.library});
  final MusicLibrary library;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final lib = widget.library;
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Expanded(child: IndexedStack(index: _page, children: [
          HomePage(library: lib),
          SearchPage(library: lib),
          LibraryPage(library: lib),
          DownloadsPage(library: lib),
          SettingsPage(library: lib),
        ])),
        if (lib.currentSong != null)
          MiniPlayer(library: lib),
        _BottomMenu(index: _page, onSelect: (i) => setState(() => _page = i)),
      ])),
    );
  }
}

class _BottomMenu extends StatelessWidget {
  const _BottomMenu({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    const entries = [
      (Icons.home_rounded, 'Ana Sayfa'),
      (Icons.search_rounded, 'Ara'),
      (Icons.library_music_rounded, 'Kütüphane'),
      (Icons.download_rounded, 'İndirilenler'),
      (Icons.settings_rounded, 'Ayarlar'),
    ];
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 5),
      decoration: const BoxDecoration(color: Color(0xFF0D1220),
        border: Border(top: BorderSide(color: Color(0xFF273047)))),
      child: Row(children: List.generate(entries.length, (i) => Expanded(
        child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => onSelect(i),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(entries[i].$1, size: 25, color: i == index ? accent : _muted),
              const SizedBox(height: 3),
              Text(entries[i].$2, maxLines: 1, style: TextStyle(
                fontSize: 10, fontWeight: i == index ? FontWeight.bold : FontWeight.w400,
                color: i == index ? _white : _muted)),
            ]))),
        ))),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, this.title, this.subtitle});
  final String? title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [const _Logo(), if (title != null) ...[
          const SizedBox(height: 13),
          Text(title!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ], if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: _muted, fontSize: 13)),
        ]])),
      Container(height: 42, width: 42, decoration: const BoxDecoration(
          color: _surface, shape: BoxShape.circle),
        child: const Icon(Icons.graphic_eq_rounded, color: _pink)),
    ]),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, required this.icon, this.trailing, this.onTap});
  final String title;
  final IconData icon;
  final String? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(21, 24, 18, 14),
    child: Row(children: [
      Icon(icon, color: _pink, size: 23),
      const SizedBox(width: 9),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
      if (trailing != null) TextButton(onPressed: onTap,
        child: Text(trailing!, style: const TextStyle(color: _muted, fontSize: 12))),
    ]),
  );
}

class GradientArt extends StatelessWidget {
  const GradientArt({super.key, this.size = 64, this.seed = 0, this.icon = Icons.music_note_rounded});
  final double size;
  final int seed;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final palettes = <List<Color>>[
      [const Color(0xFF6C1C7A), const Color(0xFFED307C)],
      [const Color(0xFF1A255F), const Color(0xFF654BE3)],
      [const Color(0xFF5B172C), const Color(0xFFC36B49)],
      [const Color(0xFF0A4C6F), const Color(0xFF52A8AD)],
      [const Color(0xFF201C4F), const Color(0xFF9E3269)],
    ];
    final colors = palettes[seed.abs() % palettes.length];
    return Container(width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(math.max(9.0, size * .14)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(.13), blurRadius: 12)]),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(right: -size * .35, top: -size * .28,
          child: Container(width: size * .88, height: size * .88,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.16), width: 2)))),
        Icon(icon, size: size * .39, color: Colors.white.withOpacity(.9)),
      ]),
    );
  }
}

class SongArt extends StatelessWidget {
  const SongArt({super.key, required this.song, this.size = 56});
  final SongModel song;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(math.max(9.0, size * .13)),
    child: QueryArtworkWidget(
      id: song.id, type: ArtworkType.AUDIO,
      artworkWidth: size, artworkHeight: size,
      artworkFit: BoxFit.cover,
      nullArtworkWidget: GradientArt(size: size, seed: song.id),
    ),
  );
}

class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.library, required this.group,
    required this.index});
  final SongModel song;
  final MusicLibrary library;
  final List<SongModel> group;
  final int index;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 21, vertical: 4),
    leading: SongArt(song: song, size: 54),
    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${readableArtist(song.artist)}  •  ${fmtDuration(Duration(milliseconds: song.duration ?? 0))}',
      maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _muted, fontSize: 12)),
    trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded, color: _muted),
      color: _surface, onSelected: (action) {
        if (action == 'favorite') unawaited(library.toggleFavorite(song.id));
        if (action == 'playlist') showAddToPlaylist(context, library, song.id);
      }, itemBuilder: (_) => [
        PopupMenuItem(value: 'favorite', child: Text(
            library.favorites.contains(song.id) ? 'Favorilerden çıkar' : 'Favorilere ekle')),
        const PopupMenuItem(value: 'playlist', child: Text('Çalma listesine ekle')),
      ]),
    onTap: () => unawaited(library.playSongs(group, index)),
  );
}

class MusicList extends StatelessWidget {
  const MusicList({super.key, required this.songs, required this.library});
  final List<SongModel> songs;
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const EmptyState(
      icon: Icons.music_off_rounded, title: 'Henüz şarkı yok',
      caption: 'Müzik eklediğinde burada görünecek.');
    return ListView.builder(shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), itemCount: songs.length,
      itemBuilder: (context, i) => SongTile(song: songs[i], library: library,
        group: songs, index: i));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title,
    required this.caption, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String caption;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 32, 26, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 84, height: 84,
        decoration: const BoxDecoration(color: _surface, shape: BoxShape.circle),
        child: Icon(icon, size: 38, color: _violet)),
      const SizedBox(height: 15),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      const SizedBox(height: 9),
      Text(caption, textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, height: 1.45)),
      if (action != null && onAction != null) ...[
        const SizedBox(height: 16),
        FilledButton(onPressed: onAction, child: Text(action!)),
      ],
    ]),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.library});
  final MusicLibrary library;

  @override
  Widget build(BuildContext context) {
    final recent = library.recentSongs;
    final highlight = recent.isNotEmpty ? recent.first :
        (library.songs.isEmpty ? null : library.songs.first);
    final favs = library.favoriteSongs.take(8).toList();
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: PageHeader(subtitle: 'Müzik hep yanında.')),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 19),
        child: _HeroCard(song: highlight, library: library))),
      if (!library.permissionGranted)
        SliverToBoxAdapter(child: EmptyState(
          icon: Icons.perm_media_rounded,
          title: 'Müziklerine erişim ver',
          caption: 'Cihazındaki şarkıları bulmak için Android müzik izni gerekiyor.',
          action: 'İzin ver ve tara', onAction: () => unawaited(library.refresh()))),
      if (library.error != null)
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(library.error!, style: const TextStyle(color: Colors.orangeAccent)))),
      SliverToBoxAdapter(child: SectionHeading(
        title: 'Favoriler', icon: Icons.favorite_rounded,
        trailing: '${library.favorites.length} şarkı')),
      SliverToBoxAdapter(child: favs.isEmpty
        ? const _HorizontalHint(text: 'Beğendiğin şarkılar burada görünecek.')
        : _SongCarousel(songs: favs, library: library)),
      SliverToBoxAdapter(child: const SectionHeading(
        title: 'Son Dinlenenler', icon: Icons.history_rounded)),
      SliverToBoxAdapter(child: recent.isEmpty
        ? const _HorizontalHint(text: 'Dinlemeye başladıkça bu alan dolacak.')
        : _SongCarousel(songs: recent.take(8).toList(), library: library)),
      SliverToBoxAdapter(child: SectionHeading(
        title: 'Çalma Listeleri', icon: Icons.queue_music_rounded,
        trailing: '${library.playlists.length} liste')),
      SliverToBoxAdapter(child: library.playlists.isEmpty
        ? const _HorizontalHint(text: 'Kütüphaneden kendi listeni oluşturabilirsin.')
        : SizedBox(height: 176, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: library.playlists.length,
            itemBuilder: (context, i) {
              final name = library.playlists.keys.elementAt(i);
              return GestureDetector(onTap: () => openCollection(context,
                name, library.tracksInPlaylist(name), library),
                child: Padding(padding: const EdgeInsets.only(right: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GradientArt(size: 125, seed: i + 1, icon: Icons.queue_music_rounded),
                    const SizedBox(height: 7),
                    SizedBox(width: 125, child: Text(name, maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ])));
            }))),
      const SliverToBoxAdapter(child: SizedBox(height: 35)),
    ]);
  }
}

class _HorizontalHint extends StatelessWidget {
  const _HorizontalHint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
    child: Text(text, style: const TextStyle(color: _muted)));
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.song, required this.library});
  final SongModel? song;
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) => Container(
    height: 222, clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [Color(0xFF401650), Color(0xFF8D174E), Color(0xFF2A173F)]),
      border: Border.all(color: Colors.white12)),
    child: Stack(children: [
      Positioned(right: -55, top: -75,
        child: Container(width: 275, height: 275,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 30)))),
      Positioned(right: 30, bottom: 24,
        child: Icon(Icons.graphic_eq_rounded, size: 100, color: Colors.white.withOpacity(.1))),
      Padding(padding: const EdgeInsets.all(21),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.graphic_eq_rounded, color: Color(0xFFEE93FE)),
            SizedBox(width: 8), Text('DİNLEMEYE DEVAM ET',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1))]),
          const Spacer(),
          Text(song?.title ?? 'Müziğin Hazır',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(song == null ? 'Cihazındaki müzikleri keşfet' : readableArtist(song?.artist),
            style: const TextStyle(color: Color(0xFFE1CFE5))),
          const SizedBox(height: 15),
          Align(alignment: Alignment.centerRight,
            child: CircleAvatar(radius: 26, backgroundColor: const Color(0xFFE641AB),
              child: IconButton(icon: const Icon(Icons.play_arrow_rounded, size: 32),
                onPressed: () {
                  if (song != null) {
                    final i = library.songs.indexWhere((s) => s.id == song!.id);
                    if (i >= 0) unawaited(library.playSongs(library.songs, i));
                  } else {
                    unawaited(library.refresh());
                  }
                }))),
        ])),
    ]),
  );
}

class _SongCarousel extends StatelessWidget {
  const _SongCarousel({required this.songs, required this.library});
  final List<SongModel> songs;
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) => SizedBox(height: 185,
    child: ListView.builder(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return InkWell(onTap: () => unawaited(library.playSongs(songs, i)),
          borderRadius: BorderRadius.circular(15),
          child: Padding(padding: const EdgeInsets.only(right: 13),
            child: SizedBox(width: 125,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SongArt(song: song, size: 125),
                const SizedBox(height: 8),
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(readableArtist(song.artist), maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              ]))));
      }));
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.library});
  final MusicLibrary library;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String text = '';
  String category = 'Tümü';
  final field = TextEditingController();
  Future<void> _openYouTubeSearch() async {
    final keyword = field.text.trim();
    if (keyword.isEmpty) return;
    final url = Uri.https('www.youtube.com', '/results',
        {'search_query': keyword});
    try {
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube açılamadı. Tarayıcıyı kontrol edin.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube araması başlatılamadı.')),
        );
      }
    }
  }
  @override
  void dispose() {field.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) {
    final all = widget.library.songs;
    final keyword = text.toLowerCase().trim();
    final found = all.where((s) {
      if (keyword.isEmpty) return true;
      if (category == 'Şarkılar') return s.title.toLowerCase().contains(keyword);
      if (category == 'Sanatçılar') return readableArtist(s.artist).toLowerCase().contains(keyword);
      if (category == 'Albümler') return readableAlbum(s.album).toLowerCase().contains(keyword);
      return ('${s.title} ${readableArtist(s.artist)} ${readableAlbum(s.album)}')
        .toLowerCase().contains(keyword);
    }).toList();
    return Column(children: [
      const PageHeader(title: 'Ara', subtitle: 'Cihazındaki müziklerde ara'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 19),
        child: TextField(controller: field, onChanged: (v) => setState(() => text = v),
          decoration: InputDecoration(
            hintText: 'Şarkı, sanatçı veya albüm ara',
            hintStyle: const TextStyle(fontSize: 13, color: _muted),
            prefixIcon: const Icon(Icons.search_rounded, color: _violet),
            suffixIcon: text.isNotEmpty ? IconButton(onPressed: () {
              field.clear(); setState(() => text = '');
            }, icon: const Icon(Icons.close_rounded)) : null,
            filled: true, fillColor: _surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _violet)),
          ))),
      Padding(
        padding: const EdgeInsets.fromLTRB(19, 12, 19, 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _pink.withOpacity(.42)),
          ),
          child: Row(children: [
            const Icon(Icons.play_circle_fill_rounded, color: _pink, size: 30),
            const SizedBox(width: 9),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YouTube’da şarkı ara',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Resmi YouTube’da açılır.',
                    style: TextStyle(fontSize: 11, color: _muted)),
              ],
            )),
            const SizedBox(width: 6),
            TextButton(
              onPressed: text.trim().isEmpty ? null : () => unawaited(_openYouTubeSearch()),
              child: const Text('Ara ↗'),
            ),
          ]),
        ),
      ),
      SizedBox(height: 59, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: ['Tümü', 'Şarkılar', 'Sanatçılar', 'Albümler'].map((c) =>
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(label: Text(c), selected: category == c,
              onSelected: (_) => setState(() => category = c)))).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(21, 5, 21, 4),
        child: Row(children: [
          const Icon(Icons.music_note_rounded, color: _pink, size: 19),
          const SizedBox(width: 8),
          Text('${found.length} şarkı', style: const TextStyle(color: _muted)),
        ])),
      Expanded(child: found.isEmpty
        ? const EmptyState(icon: Icons.search_off_rounded,
            title: 'Sonuç bulunamadı', caption: 'Başka bir kelime deneyebilirsin.')
        : ListView.builder(itemCount: found.length,
            itemBuilder: (context, i) => SongTile(song: found[i], library: widget.library,
              group: found, index: i))),
    ]);
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.library});
  final MusicLibrary library;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final lib = widget.library;
    const tabs = ['Şarkılar', 'Sanatçılar', 'Albümler', 'Listeler'];
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: PageHeader(title: 'Kütüphane',
        subtitle: 'Müziğinin tümü, tek bir yerde')),
      SliverToBoxAdapter(child: SizedBox(height: 54,
        child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: List.generate(tabs.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(label: Text(tabs[i]), selected: tab == i,
              onSelected: (_) => setState(() => tab = i))))))),
      if (tab == 0) ...[
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(19, 17, 19, 7),
          child: Row(children: [
            Expanded(child: _ShortcutCard(icon: Icons.favorite_rounded, title: 'Favoriler',
              count: lib.favoriteSongs.length, color: _pink,
              onTap: () => openCollection(context, 'Favoriler', lib.favoriteSongs, lib))),
            const SizedBox(width: 8),
            Expanded(child: _ShortcutCard(icon: Icons.history_rounded, title: 'Son Dinlenenler',
              count: lib.recentSongs.length, color: _violet,
              onTap: () => openCollection(context, 'Son Dinlenenler', lib.recentSongs, lib))),
          ]))),
        SliverToBoxAdapter(child: SectionHeading(
          title: 'Tüm Şarkılar', icon: Icons.music_note_rounded,
          trailing: '${lib.songs.length} şarkı')),
        if (lib.songs.isEmpty)
          SliverToBoxAdapter(child: EmptyState(icon: Icons.headphones_rounded,
            title: 'Kütüphanen boş', caption: 'Cihazındaki şarkıları tara.',
            action: 'Yeniden tara', onAction: () => unawaited(lib.refresh())))
        else
          SliverList.builder(itemCount: lib.songs.length,
            itemBuilder: (context, i) => SongTile(song: lib.songs[i],
              group: lib.songs, index: i, library: lib)),
      ],
      if (tab == 1 || tab == 2) ...[
        SliverToBoxAdapter(child: SectionHeading(
            title: tab == 1 ? 'Sanatçılar' : 'Albümler',
            icon: tab == 1 ? Icons.person_rounded : Icons.album_rounded)),
        SliverList.builder(itemCount: _groups(tab == 1).length,
          itemBuilder: (context, i) {
            final pair = _groups(tab == 1).entries.elementAt(i);
            return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 21, vertical: 4),
              leading: GradientArt(size: 56, seed: i, icon: tab == 1
                ? Icons.person_rounded : Icons.album_rounded),
              title: Text(pair.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${pair.value.length} şarkı', style: const TextStyle(color: _muted)),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => openCollection(context, pair.key, pair.value, lib));
          }),
      ],
      if (tab == 3) ...[
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(21, 18, 21, 0),
          child: FilledButton.icon(onPressed: () => showCreatePlaylist(context, lib),
            icon: const Icon(Icons.add_rounded), label: const Text('Yeni Çalma Listesi')))),
        if (lib.playlists.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: Icons.queue_music_rounded,
            title: 'Henüz listen yok', caption: 'En sevdiğin şarkıları bir araya getir.')),
        SliverList.builder(itemCount: lib.playlists.length,
          itemBuilder: (context, i) {
            final name = lib.playlists.keys.elementAt(i);
            return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 21, vertical: 7),
              leading: GradientArt(size: 58, seed: i, icon: Icons.queue_music_rounded),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${lib.tracksInPlaylist(name).length} şarkı',
                style: const TextStyle(color: _muted)),
              onTap: () => openCollection(context, name, lib.tracksInPlaylist(name), lib),
              trailing: PopupMenuButton<String>(color: _surface,
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Listeyi sil'))],
                onSelected: (_) => unawaited(lib.deletePlaylist(name))));
          }),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }

  Map<String, List<SongModel>> _groups(bool artists) {
    final entries = <String, List<SongModel>>{};
    for (final song in widget.library.songs) {
      final key = artists ? readableArtist(song.artist) : readableAlbum(song.album);
      entries.putIfAbsent(key, () => []).add(song);
    }
    return Map.fromEntries(entries.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())));
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.icon, required this.title,
    required this.count, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(.24), _surface]),
        borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 27, color: color), const SizedBox(height: 17),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        Text('$count şarkı', style: const TextStyle(color: _muted, fontSize: 12)),
      ])),
  );
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key, required this.library});
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) {
    final downloads = library.songs.where((song) {
      final path = song.data.toLowerCase().replaceAll('\\', '/');
      return path.contains('/download/') || path.contains('/downloads/');
    }).toList();
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: PageHeader(title: 'İndirilenler',
        subtitle: 'Telefonda bulunan müzik dosyaları')),
      SliverToBoxAdapter(child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18)),
        child: const Row(children: [Icon(Icons.info_outline_rounded, color: _violet),
          SizedBox(width: 12), Expanded(child: Text(
            'Bu bölüm İndirilenler klasöründeki müzikleri gösterir. MeloTR henüz internetten müzik indirmez.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.45)))]))),
      if (downloads.isEmpty)
        const SliverToBoxAdapter(child: EmptyState(icon: Icons.download_for_offline_outlined,
          title: 'İndirilen müzik yok',
          caption: 'İndirdiğin veya kendi eklediğin ses dosyalarını Android medya taraması bulduğunda burada görebilirsin.'))
      else
        SliverList.builder(itemCount: downloads.length,
          itemBuilder: (context, i) => SongTile(song: downloads[i],
            group: downloads, index: i, library: library)),
    ]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.library});
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) => ListView(children: [
    const PageHeader(title: 'Ayarlar', subtitle: 'Müzik deneyimini kişiselleştir'),
    const SectionHeading(title: 'Görünüm', icon: Icons.palette_rounded),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Vurgu rengi', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 13),
          Row(children: List.generate(_accents.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(onTap: () => unawaited(library.changeAccent(i)),
              child: Container(width: 43, height: 43, decoration: BoxDecoration(
                color: _accents[i], shape: BoxShape.circle,
                border: Border.all(color: i == library.accentIndex
                    ? Colors.white : Colors.transparent, width: 3)),
                child: i == library.accentIndex
                  ? const Icon(Icons.check_rounded, color: Colors.white) : null))))),
        ]))),
    const SectionHeading(title: 'Kütüphane', icon: Icons.library_music_rounded),
    ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: const Icon(Icons.refresh_rounded, color: _violet),
      title: const Text('Müzikleri yeniden tara'),
      subtitle: Text('${library.songs.length} şarkı bulundu',
        style: const TextStyle(color: _muted)),
      trailing: library.loading ? const SizedBox(height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded),
      onTap: library.loading ? null : () => unawaited(library.refresh())),
    const SectionHeading(title: 'Uygulama', icon: Icons.info_outline_rounded),
    const ListTile(contentPadding: EdgeInsets.symmetric(horizontal: 22),
      title: Text('MeloTR'), subtitle: Text('Sürüm 0.1.0 • Offline müzik çalar',
        style: TextStyle(color: _muted))),
    const ListTile(contentPadding: EdgeInsets.symmetric(horizontal: 22),
      title: Text('Gizlilik'), subtitle: Text('Üyelik ve sunucu yok. Favoriler ve listeler cihazında saklanır.',
        style: TextStyle(color: _muted))),
    const SizedBox(height: 24),
  ]);
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.library});
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) {
    final song = library.currentSong;
    if (song == null) return const SizedBox.shrink();
    return InkWell(onTap: () => Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => NowPlayingPage(library: library))),
      child: Container(margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF1A2032),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF394058))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            SongArt(song: song, size: 49),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(readableArtist(song.artist), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _muted)),
            ])),
            IconButton(icon: Icon(library.favorites.contains(song.id)
                ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: library.favorites.contains(song.id) ? _pink : _muted, size: 21),
              onPressed: () => unawaited(library.toggleFavorite(song.id))),
            IconButton(icon: Icon(library.player.playing
              ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: _pink, size: 36),
              onPressed: () => unawaited(library.playOrPause())),
            IconButton(icon: const Icon(Icons.skip_next_rounded),
              onPressed: () => unawaited(library.next())),
          ]),
          StreamBuilder<Duration>(stream: library.player.positionStream,
            builder: (context, snapshot) {
              final total = library.player.duration?.inMilliseconds ?? 0;
              final at = snapshot.data?.inMilliseconds ?? 0;
              return Padding(padding: const EdgeInsets.only(top: 5),
                child: LinearProgressIndicator(
                  value: total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0).toDouble(),
                  minHeight: 2, backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(_pink)));
            }),
        ])),
    );
  }
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key, required this.library});
  final MusicLibrary library;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: library,
    builder: (context, _) {
      final song = library.currentSong;
      if (song == null) return const Scaffold(body: Center(child: Text('Şarkı seçilmedi.')));
      return Scaffold(body: Stack(children: [
        const Positioned.fill(child: _AmbientBackground()),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 31)),
              const Expanded(child: Center(child: _Logo(size: 26))),
              IconButton(onPressed: () => showAddToPlaylist(context, library, song.id),
                icon: const Icon(Icons.more_vert_rounded)),
            ])),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 38),
            child: AspectRatio(aspectRatio: 1, child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.contain,
                child: SongArt(song: song, size: constraints.maxWidth))))),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(song.title, maxLines: 2,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(readableArtist(song.artist), style: const TextStyle(
                    color: _muted, fontSize: 17))])),
              IconButton(onPressed: () => unawaited(library.toggleFavorite(song.id)),
                icon: Icon(library.favorites.contains(song.id)
                  ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _pink, size: 30)),
            ])),
          const SizedBox(height: 24),
          StreamBuilder<Duration>(stream: library.player.positionStream,
            builder: (context, snapshot) {
              final duration = library.player.duration ?? Duration.zero;
              final position = snapshot.data ?? Duration.zero;
              final maxTime = duration.inMilliseconds.toDouble();
              final value = position.inMilliseconds.toDouble().clamp(0.0,
                  math.max(maxTime, 1.0)).toDouble();
              return Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Slider(min: 0, max: math.max(maxTime, 1.0), value: value,
                    onChanged: maxTime <= 0 ? null : (v) =>
                      unawaited(library.player.seek(Duration(milliseconds: v.round()))))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(fmtDuration(position)), Text(fmtDuration(duration))])),
              ]);
            }),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              IconButton(icon: Icon(Icons.shuffle_rounded,
                color: library.player.shuffleModeEnabled ? _pink : _muted),
                onPressed: () => unawaited(library.toggleShuffle())),
              IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 39),
                onPressed: () => unawaited(library.previous())),
              Container(decoration: BoxDecoration(shape: BoxShape.circle,
                color: _pink, boxShadow: [BoxShadow(color: _pink.withOpacity(.33), blurRadius: 30)]),
                child: IconButton(iconSize: 45,
                  icon: Icon(library.player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: () => unawaited(library.playOrPause()))),
              IconButton(icon: const Icon(Icons.skip_next_rounded, size: 39),
                onPressed: () => unawaited(library.next())),
              IconButton(icon: Icon(library.player.loopMode == LoopMode.one
                  ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: library.player.loopMode == LoopMode.off ? _muted : _pink),
                onPressed: () => unawaited(library.cycleRepeat())),
            ])),
          const SizedBox(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(onPressed: () => showAddToPlaylist(context, library, song.id),
                icon: const Icon(Icons.playlist_add_rounded, color: _muted)),
              TextButton.icon(onPressed: () => _openQueue(context, library),
                icon: const Icon(Icons.queue_music_rounded), label: const Text('Sıradaki Şarkılar')),
            ])),
          const SizedBox(height: 20),
        ])),
      ]));
    });
}

void _openQueue(BuildContext context, MusicLibrary library) {
  showModalBottomSheet<void>(context: context, isScrollControlled: true,
    backgroundColor: _surface,
    builder: (sheetContext) => SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .66,
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(19),
          child: Text('Çalma Sırası', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: library.queue.length,
          itemBuilder: (_, i) => SongTile(song: library.queue[i],
            group: library.queue, index: i, library: library))),
      ]))));
}

void openCollection(BuildContext context, String title,
    List<SongModel> songs, MusicLibrary library) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(children: [
      Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 5),
        child: Text('${songs.length} şarkı', style: const TextStyle(color: _muted))),
      MusicList(songs: songs, library: library),
    ]))));
}

Future<void> showCreatePlaylist(BuildContext context, MusicLibrary library) async {
  final field = TextEditingController();
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    backgroundColor: _surface,
    title: const Text('Yeni çalma listesi'),
    content: TextField(controller: field, autofocus: true, maxLength: 50,
      decoration: const InputDecoration(hintText: 'Liste adı')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
      FilledButton(onPressed: () {
        final name = field.text.trim();
        if (name.isNotEmpty) unawaited(library.savePlaylist(name));
        Navigator.pop(dialogContext);
      }, child: const Text('Oluştur')),
    ]));
  field.dispose();
}

Future<void> showAddToPlaylist(BuildContext context, MusicLibrary library, int id) async {
  await showModalBottomSheet<void>(context: context, backgroundColor: _surface,
    showDragHandle: true, builder: (sheetContext) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 3, 14, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Çalma listesine ekle',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...library.playlists.keys.map((name) => ListTile(
            leading: Icon(library.playlists[name]!.contains(id)
              ? Icons.check_circle_rounded : Icons.playlist_add_rounded,
              color: library.playlists[name]!.contains(id) ? _pink : _muted),
            title: Text(name), onTap: () {
              unawaited(library.toggleInPlaylist(name, id));
              Navigator.pop(sheetContext);
            })),
          ListTile(leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Yeni liste oluştur'), onTap: () {
              Navigator.pop(sheetContext);
              showCreatePlaylist(context, library);
            }),
        ]))));
}
