import '../models/track.dart';

interface class Scanner {
  Track scanSingle(String path) {
    throw Exception("Not implemented");
  }

  List<Track> scanLocation(String path) {
    throw Exception("Not implemented");
  }
}