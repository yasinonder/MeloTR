import 'package:iconsax/iconsax.dart';
import 'package:melotube/internal/models/song_item.dart';
import 'package:melotube/languages/languages.dart';
import 'package:melotube/main.dart';
import 'package:melotube/providers/playlist_provider.dart';
import 'package:melotube/ui/animations/animated_icon.dart';
import 'package:melotube/ui/animations/animated_text.dart';
import 'package:melotube/ui/sheets/add_to_playlist.dart';
import 'package:melotube/ui/sheets/common_sheet.dart';
import 'package:melotube/ui/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:melotube/ui/ui_utils.dart';

class NewPlaylistSheet extends StatefulWidget {
  const NewPlaylistSheet({
    this.fallbackSong,
    Key? key}) : super(key: key);
  final SongItem? fallbackSong;
  @override
  State<NewPlaylistSheet> createState() => _NewPlaylistSheetState();
}

class _NewPlaylistSheetState extends State<NewPlaylistSheet> {

  // Playlist Provider
  PlaylistProvider get playlistProvider => Provider.of(context, listen: false);

  // New Playlist name text controller
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CommonSheet(
      useCustomScroll: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(12).copyWith(top: 0, right: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.fallbackSong != null)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      UiUtils.showModal(
                        context: internalNavigatorKey.currentContext!,
                        modal: AddToPlaylistSheet(song: widget.fallbackSong!),
                      );
                    },
                    child: const AppAnimatedIcon(Iconsax.arrow_left, size: 22)
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(Languages.of(context)!.labelCreateMusicPlaylist, style: textStyle(context, bold: false))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: kToolbarHeight,
                      padding: const EdgeInsets.only(left: 12, right: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Row(
                        children: [
                          const AppAnimatedIcon(Icons.title_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              controller: controller,
                              decoration: InputDecoration.collapsed(hintText: Languages.of(context)!.labelPlaylistName, hintStyle: smallTextStyle(context, opacity: 0.6)),
                              style: smallTextStyle(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      playlistProvider.createGlobalPlaylist(controller.text, songs: widget.fallbackSong != null ? [widget.fallbackSong!] : []);
                      Navigator.pop(context);
                      if (widget.fallbackSong != null) {
                        UiUtils.showModal(
                          context: context,
                          modal: AddToPlaylistSheet(song: widget.fallbackSong!),
                        );
                      }
                    },
                    child: AnimatedText(Languages.of(context)!.labelCreate, style: smallTextStyle(context).copyWith(fontWeight: FontWeight.bold), auto: true)
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}