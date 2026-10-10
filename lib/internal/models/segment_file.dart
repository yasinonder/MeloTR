import 'dart:io';

import 'package:melotube/internal/models/audio_tags.dart';

class SegmentFile {

  File segmentFile;
  AudioTags tags;
  int duration;

  SegmentFile({
    required this.segmentFile,
    required this.tags,
    required this.duration
  });

}