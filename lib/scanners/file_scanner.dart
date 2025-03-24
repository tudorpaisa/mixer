import 'dart:io';
import '../models/track.dart';
import './scanner.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

const SUPPORTED_FILE_TYPES = [
  "mp3",
  "mp4",
  "flac",
  "ogg",
  "opus",
];

class FileScanner implements Scanner {

  @override
  Track scanSingle(String path) {
    final track = File(path);
    final metadata = readMetadata(track);

    if (metadata == null) {
      throw Exception("Skipping track with empty metadata: $path");
    }

    return Track(metadata.title ?? "", metadata.artist ?? "", metadata.album ?? "", "", "", "");
  }

  @override
  List<Track> scanLocation(String path) {
    List<FileSystemEntity> files = Directory(path)
        .listSync(recursive: true, followLinks: false)
        .toList();

    List<Track> tracks = [];
    if (files.isEmpty) return tracks;

    for (var i in files) {
      if (!SUPPORTED_FILE_TYPES.contains(i.path.split(".").last.toLowerCase())) {
        continue;
      }
      try {
        tracks.add(scanSingle(i.absolute.path));
      } catch (Exception) {
        continue;
      }
    }

    return tracks;
  }
}