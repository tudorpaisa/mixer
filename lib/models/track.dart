import 'dart:convert';

class Track {
  String title;
  String artists;
  String album;
  String key;
  String tempo;
  String genre;

  String getId() {
    final str = "$title $artists";
    final bytes = utf8.encode(str);
    final base64Str = base64Encode(bytes);
    return base64Str;
  }

  Track(this.title, this.artists, this.album, this.key, this.tempo, this.genre);

  Track.fromJson(Map<String, dynamic> json)
    : title = json["title"] as String,
      artists = json["artists"] as String,
      album = json["album"] as String,
      key = json["key"] as String,
      tempo = json["tempo"] as String,
      genre = json["genre"] as String;

  Map<String, dynamic> toJson() => {
    "title": title,
    "artists": artists,
    "album": album,
    "key": key,
    "tempo": tempo,
    "genre": genre,
  };
}