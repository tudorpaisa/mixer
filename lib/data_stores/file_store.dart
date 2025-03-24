import 'dart:io';
import 'package:flutter/foundation.dart';

import './data_store.dart';
import '../models/track.dart';
import 'dart:convert';

class FileStoreFormat {
  Map<String, Track> tracks;
  List<List<String>> edges;

  FileStoreFormat(this.tracks, this.edges);

  static FileStoreFormat fromJson(Map<String, dynamic> json) {
    Map<String, Track> tracks = {};
    try {
      var rawTracks = json["tracks"] as Map<String, dynamic>;
      for (var k in rawTracks.keys) {
        tracks[k] = Track.fromJson(rawTracks[k] as Map<String, dynamic>);
      }
    } catch (Exception) {
      var rawTracks = json["tracks"] as List<dynamic>;
      for (var i in rawTracks) {
        var t = Track.fromJson(i as Map<String, dynamic>);
        tracks[t.getId()] = t;
      }
    }

    List<List<String>> edges = [];
    if (json.containsKey("edges")) {
      var rawEdges = json["edges"] as List<dynamic>;
      for (var e in rawEdges) {
        List<String> lst = [];
        for (var s in e as List<dynamic>) {
          lst.add(s as String);
        }
        edges.add(lst);
      }
    }

    return FileStoreFormat(tracks, edges);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> out = {};
    Map<String, dynamic> rawTracks = {};
    for (var k in tracks.keys) {
      rawTracks[k] = tracks[k]!.toJson();
    }

    out["tracks"] = rawTracks;
    out["edges"] = edges;

    return out;
  }
}

class FileStore implements DataStore {
  Map<String, Track> _tracks = {};
  Set<List<String>> _edges = Set();

  FileStore() {}

  @override
  void AddTrack(Track track) {
    var trackId = track.getId();
    if (_tracks.containsKey(trackId)) {
      if (_tracks[trackId]!.key != track.key && track.key.isNotEmpty) {
        _tracks[trackId]!.key = track.key;
      }

      if (_tracks[trackId]!.genre != track.genre && track.genre.isNotEmpty) {
        _tracks[trackId]!.genre = track.genre;
      }

      if (_tracks[trackId]!.album != track.album && track.album.isNotEmpty) {
        _tracks[trackId]!.album = track.album;
      }

      if (_tracks[trackId]!.tempo != track.tempo && track.tempo.isNotEmpty) {
        _tracks[trackId]!.tempo = track.tempo;
      }

      return;
    }
    _tracks[trackId] = track;
  }

  @override
  void PairTracks(String hashA, String hashB) {
    _edges.add([hashA, hashB]);
  }

  @override
  void Load(String path) {
    var file = File(path);
    var str = file.readAsStringSync();
    var json = jsonDecode(str);
    var fsFormat = FileStoreFormat.fromJson(json);
    for (var track in fsFormat.tracks.values) {
      AddTrack(track);
    }
    for (var edge in fsFormat.edges) {
      PairTracks(edge[0], edge[1]);
    }
  }

  @override
  void Dump(String path) {
    var outObj = FileStoreFormat(_tracks, _edges.toList());
    var outStr = jsonEncode(outObj.toJson());

    var file = File(path);
    file.writeAsStringSync(outStr);
  }

  @override
  List<Track> GetTrackList() {
    var lst = _tracks.values.toList();
    lst.sort((a, b) => a.title.compareTo(b.title));
    return lst;
  }

  @override
  void UpdateTrack(Track track) {
    _tracks[track.getId()] = track;
  }

  @override
  void RemovePair(Track trackA, Track trackB) {
    var aId = trackA.getId();
    var bId = trackB.getId();

    var e = _edges.toList();
    for (var i = 0; i < e.length; i++) {
      if (e[i].contains(aId) && e[i].contains(bId)) {
        e.removeAt(i);
        break;
      }
    }
    _edges = Set.from(e);
  }

  @override
  List<Track> GetPairedTracks(Track track) {
    var trackid = track.getId();
    List<String> trackIds = [];
    for (var edge in _edges) {
      if (edge.contains(trackid)) {
        trackIds.addAll(edge);
      }
    }

    List<Track> out = [];
    for (var i in trackIds) {
      if (i != trackid) {
        out.add(_tracks[i]!);
      }
    }
    return out;
  }

}