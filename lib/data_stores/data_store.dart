import '../models/track.dart';

interface class DataStore {
  void AddTrack(Track track) {}
  void PairTracks(String hashA, String hashB) {}
  void Load(String path) {}
  void Dump(String path) {}

  void UpdateTrack(Track track) {}
  void RemovePair(Track trackA, Track trackB) {}

  List<Track> GetTrackList() {
    throw Exception("Unimplemented");
  }

  List<Track> GetPairedTracks(Track track) {
    throw Exception("Unimplemented");
  }
}