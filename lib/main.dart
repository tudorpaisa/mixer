import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import './scanners/file_scanner.dart';
import './models/track.dart';
import './data_stores/file_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return MaterialApp(
      title: 'Mixxer',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Mixxer Command Center'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Track> _tracks = [];
  FileStore db = FileStore();
  String newPairSearchFilter = "";
  String pairSearchFilter = "";
  String trackListSearchFilter = "";

  Track? selectedTrack;
  List<Track> pairedTracks = [];

  Directory? _appDocumentsDirectory;

  final String _fileName = "data.json";

  Future<void> scanFolder(BuildContext context) async {
    String? result = await FilePicker.platform
        .getDirectoryPath(dialogTitle: "Pick a folder to scan");
    if (result == null) {
      // TODO: add a dialog or smth
      return;
    }
    var fs = FileScanner();
    var tracks = fs.scanLocation(result);
    for (var t in tracks) {
      db.AddTrack(t);
    }
    setState(() {
      saveData(context);
      _tracks = db.GetTrackList();
    });
    return;
  }

  Future<void> loadJson(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(dialogTitle: "Pick a JSON file to load");
    if (result == null) return;
    if (result.count >= 1) {
      var path = result.files[0].path;
      if (!path!.endsWith("json")) return;
      db.Load(path);

      setState(() {
        saveData(context);
        _tracks = db.GetTrackList();
      });

    }
  }

  Future<void> setUpPermission() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      openAppSettings();
    }
  }

  Future<void> loadData() async {
    _appDocumentsDirectory = await getApplicationDocumentsDirectory();
    var dir = Directory(_appDocumentsDirectory!.absolute.path + "/mixxer");
    var dirExists = await dir.exists();
    if (dirExists) {
      var filePath = dir.path + "/" + _fileName;
      db.Load(filePath);
      setState(() {
        _tracks = db.GetTrackList();
      });
    }
  }

  void saveData(BuildContext context) {
    if (_appDocumentsDirectory == null) {
      showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
                content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("File system inaccessible. Unable to save."),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Close")),
                ]);
          });

      return;
    }

    var dir = Directory(_appDocumentsDirectory!.absolute.path + "/mixxer");
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    var filePath = dir.path + "/" + _fileName;
    db.Dump(filePath);
  }

  SearchAnchor buildSearchTrackList() {
    return SearchAnchor(
        builder: (BuildContext context, SearchController controller) {
      return SearchBar(
        controller: controller,
        padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 8.0)),
        leading: const Icon(Icons.search),
        onTap: () {},
        onChanged: (s) {
          setState(() {
            trackListSearchFilter = s;
          });
        },
        onSubmitted: (s) {
          setState(() {
            trackListSearchFilter = s;
          });
        },
      );
    }, suggestionsBuilder: (BuildContext ctx, SearchController controller) {
      List<ListTile> out = [];
      for (var i in _tracks) {
        out.add(ListTile(
          title: Text("${i.title} - ${i.artists}"),
        ));
      }
      return out;
    });
  }

  SearchAnchor buildSearchPairedTrackList() {
    return SearchAnchor(
        builder: (BuildContext context, SearchController controller) {
      return SearchBar(
        controller: controller,
        padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 8.0)),
        leading: const Icon(Icons.search),
        onTap: () {},
        onSubmitted: (s) {
          setState(() {
            pairSearchFilter = s;
          });
        },
      );
    }, suggestionsBuilder: (BuildContext ctx, SearchController controller) {
      List<ListTile> out = [];
      for (var i in db.GetPairedTracks(selectedTrack!)) {
        out.add(ListTile(
          title: Text("${i.title} - ${i.artists}"),
        ));
      }
      return out;
    });
  }

  ListTile buildTrackListTile(
      Track track, BuildContext context, bool canEdit, bool canTap) {
    IconButton editButton = IconButton(
        onPressed: () {
          showEditDialog(track, context);
        },
        icon: Icon(Icons.edit));
    IconButton removeButton = IconButton(
        onPressed: () {
          showRemovePairDialog(track, context);
        },
        icon: Icon(Icons.remove));

    return ListTile(
        title: Wrap(children: [
          Text(track.title),
          Text(" - "),
          Text(track.artists),
        ]),
        // subtitle: Text( "${track.key == "" ? "UNK" : track.key} - ${track.tempo == "" ? "UNK" : track.tempo} BPM - ${track.genre.isEmpty ? "UNK" : track.genre}"),
        subtitle: ClipRect(
            child:Row(
            children: [
              Text("Key: ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(track.key),
              VerticalDivider(),
              Text("BPM: ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(track.tempo),
              VerticalDivider(),
              Text("Genre: ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(track.genre),
            ],
          )
        ),
        trailing: canEdit ? editButton : removeButton,
        onTap: () {
          if (canTap) {
            setState(() {
              if (selectedTrack?.getId() != track.getId()) {
                selectedTrack = track;
              } else if (selectedTrack?.getId() == track.getId()) {
                selectedTrack = null;
              }
            });
          }
        });
  }

  List<ListTile> getSearchList(BuildContext context) {
    List<ListTile> out = [];
    for (var i in _tracks) {
      if (i.artists.toLowerCase().contains(newPairSearchFilter.toLowerCase()) ||
          i.title.toLowerCase().contains(newPairSearchFilter.toLowerCase())) {
        out.add(buildTrackListTile(i, context, false, false));
      }
    }
    return out;
  }

  List<ListTile> getTrackList(BuildContext context) {
    List<ListTile> out = [];
    for (var i in _tracks) {
      var tile = buildTrackListTile(i, context, true, true);
      if (trackListSearchFilter.isNotEmpty) {
        if (i.artists.toLowerCase().contains(trackListSearchFilter.toLowerCase()) ||
            i.title.toLowerCase().contains(trackListSearchFilter.toLowerCase()) ||
            i.genre.toLowerCase().contains(trackListSearchFilter.toLowerCase()) ||
            i.tempo.toLowerCase().contains(trackListSearchFilter.toLowerCase()) ||
            i.key.toLowerCase().contains(trackListSearchFilter.toLowerCase())) {
          out.add(tile);
        }
      } else {
        out.add(tile);
      }
    }
    return out;
  }

  List<ListTile> getPairList(BuildContext context) {
    if (selectedTrack == null) return [];

    List<ListTile> out = [];
    for (var i in db.GetPairedTracks(selectedTrack!)) {
      var tile = buildTrackListTile(i, context, false, true);

      if (pairSearchFilter.isNotEmpty) {
        if (i.artists.contains(pairSearchFilter) ||
            i.title.contains(pairSearchFilter)) {
          out.add(tile);
        }
      } else {
        out.add(tile);
      }
    }
    return out;
  }

  Widget displaySelectedTrack(BuildContext context) {
    if (selectedTrack == null) {
      return Text("No track selected");
    }
    return Container(
      child: Row(
        children: [
          Text("Title: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(selectedTrack!.title),
          VerticalDivider(),
          Text("Artist: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(selectedTrack!.artists),
          VerticalDivider(),
          Text("Key: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(selectedTrack!.key.isEmpty ? "UNK" : selectedTrack!.key),
          VerticalDivider(),
          Text("BPM: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(selectedTrack!.tempo.isEmpty ? "UNK" : selectedTrack!.tempo),
          VerticalDivider(),
          Text("Genre: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(selectedTrack!.genre.isEmpty ? "UNK" : selectedTrack!.genre),
        ],
      ),
    );
  }

  Widget buildSearchListView(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: getTrackList(context),
    );
  }

  Widget buildTrackListView(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: getTrackList(context),
    );
  }

  Widget buildPairListView(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: getPairList(context),
    );
  }

  Widget buildSidePanel(BuildContext context, Widget Function() search,
      Widget Function(BuildContext) list) {
    return SingleChildScrollView(
        child: list(context),
    );
  }

  void showRemovePairDialog(Track track, BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            scrollable: true,
            content: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                child: Column(
                  children: <Widget>[
                    Text("Are you sure you want to unpair track?"),
                    Text("${track.title} - ${track.artists}"),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context), child: Text("No")),
              TextButton(
                  onPressed: () {
                    setState(() {
                      db.RemovePair(selectedTrack!, track);
                    });
                    saveData(context);
                    Navigator.pop(context);
                  },
                  child: Text("Yes")),
            ],
          );
        });
  }

  void showAddSongDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          var titleController = TextEditingController();
          var artistController = TextEditingController();
          var albumController = TextEditingController();
          var keyController = TextEditingController();
          var tempoController = TextEditingController();
          var genreController = TextEditingController();

          return AlertDialog(
            scrollable: true,
            content: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller:titleController,
                      decoration: InputDecoration(
                        labelText: "Title",
                        hintText: "Title",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller:artistController,
                      decoration: InputDecoration(
                        labelText: "Artists",
                        hintText: "Artists",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller:albumController,
                      decoration: InputDecoration(
                        labelText: "Album",
                        hintText: "Album",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: keyController,
                      decoration: InputDecoration(
                        // label: Text(track.key),
                        labelText: "Key",
                        hintText: "Key",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: tempoController,
                      decoration: InputDecoration(
                        labelText: "Tempo",
                        hintText: "Tempo",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: genreController,
                      decoration: InputDecoration(
                        labelText: "Genre",
                        hintText: "Genre",
                        enabled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    var track = new Track(
                        titleController.text,
                        artistController.text,
                        albumController.text,
                        keyController.text,
                        tempoController.text,
                        genreController.text
                    );

                    setState(() {
                      db.AddTrack(track);
                    });

                    saveData(context);
                    Navigator.pop(context);
                  },
                  child: Text("Save")),
            ],
          );
        });
  }

  void showEditDialog(Track track, BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          var albumController = TextEditingController();
          albumController.text = track.album;
          var keyController = TextEditingController();
          keyController.text = track.key;
          var tempoController = TextEditingController();
          tempoController.text = track.tempo;
          var genreController = TextEditingController();
          genreController.text = track.genre;

          return AlertDialog(
            scrollable: true,
            content: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      decoration: InputDecoration(
                        label: Text(track.title),
                        hintText: "Title",
                        enabled: false,
                      ),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        label: Text(track.artists),
                        enabled: false,
                      ),
                    ),
                    TextFormField(
                      controller: albumController,
                      decoration: InputDecoration(
                        // label: Text(track.key),
                        labelText: "Album",
                        hintText: "Album",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: keyController,
                      decoration: InputDecoration(
                        // label: Text(track.key),
                        labelText: "Key",
                        hintText: "Key",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: tempoController,
                      decoration: InputDecoration(
                        labelText: "Tempo",
                        hintText: "Tempo",
                        enabled: true,
                      ),
                    ),
                    TextFormField(
                      controller: genreController,
                      decoration: InputDecoration(
                        labelText: "Genre",
                        hintText: "Genre",
                        enabled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    track.album = albumController.text;
                    track.key = keyController.text;
                    track.tempo = tempoController.text;
                    track.genre = genreController.text;

                    setState(() {
                      db.UpdateTrack(track);
                    });

                    saveData(context);
                    Navigator.pop(context);
                  },
                  child: Text("Save")),
            ],
          );
        });
  }

  void showAddPairTrackDialog(BuildContext context) {
    var tracks = _tracks;
    var textFilter = "";
    var textController = TextEditingController();

    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            scrollable: true,
            content: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                child: Column(
                  children: <Widget>[
                    SearchAnchor(
                      viewOnChanged: (s) {
                        setState(() {
                          newPairSearchFilter = s;
                        });
                      },
                      builder: (BuildContext ctx, SearchController controller) {
                        return SearchBar(
                          controller: controller,
                          padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16.0)),
                          leading: const Icon(Icons.search),
                          onTap: () {
                            controller.openView();
                          },
                        );
                      },
                      suggestionsBuilder:
                          (BuildContext ctx, SearchController controller) {
                        List<ListTile> out = [];
                        for (var i in tracks) {
                          if (i.getId() != selectedTrack?.getId() &&
                              (i.artists.toLowerCase().contains(newPairSearchFilter.toLowerCase()) ||
                                  i.title.toLowerCase().contains(newPairSearchFilter.toLowerCase()))) {
                            out.add(ListTile(
                                title: Text("${i.title} - ${i.artists}"),
                                onTap: () {
                                  setState(() {
                                    db.PairTracks(
                                        selectedTrack!.getId(), i.getId());
                                    newPairSearchFilter = "";
                                    controller.closeView(i.title);
                                  });
                                  saveData(context);
                                  Navigator.pop(context);
                                }));
                          }
                        }
                        return out;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [],
          );
        });
  }

  @override
  void initState() {
    // setUpPermission();
    loadData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [displaySelectedTrack(context)],
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          // child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: buildSearchTrackList(),
                ),
                Row(
                  children: [
                    Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    showAddSongDialog(context);
                                  },
                                  icon: Icon(Icons.add),
                                ),
                                IconButton(
                                  onPressed: () {
                                    scanFolder(context);
                                  },
                                  icon: Icon(Icons.drive_folder_upload),
                                ),
                                IconButton(
                                  onPressed: () {
                                    loadJson(context);
                                  },
                                  icon: Icon(Icons.code),
                                ),
                              ],
                            )
                          ],
                        )),
                    Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (selectedTrack != null) {
                                      showAddPairTrackDialog(context);
                                    }
                                  },
                                  icon: Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        )),
                  ],
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: buildTrackListView(context),
                            )
                          ],
                        )
                      ),
                      Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: buildPairListView(context),
                              )
                            ],
                          )
                      ),
                    ]
                  )
                ),
              ],
            ),
          // ),
        ),
      ),
    );
  }
}
