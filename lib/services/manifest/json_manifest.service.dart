import 'dart:convert';

import 'package:bungie_api/models/destiny_inventory_bucket_definition.dart';
import 'package:bungie_api/models/destiny_manifest.dart';
import 'package:bungie_api/models/destiny_stat_definition.dart';
import 'package:bungie_api/models/destiny_class_definition.dart';
import 'package:bungie_api/models/destiny_race_definition.dart';
import 'package:bungie_api/models/destiny_talent_grid_definition.dart';
import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:little_light/services/bungie_api/bungie_api.service.dart';
import 'package:little_light/services/bungie_api/enums/definition_table_names.enum.dart';
import 'package:little_light/services/manifest/base_manifest_service.dart';
import 'package:little_light/services/translate/translate.service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JSONManifestService extends BaseManifestService {
  Map<String, dynamic> _json;
  final Map<String, dynamic> _cached = Map();
  static const String _manifestFilename = "manifest.json";

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  @override
  Future<bool> download({DownloadProgress onProgress}) async {
    DestinyManifest info = await loadManifestInfo();
    String language = await new TranslateService().getLanguage();
    String path = info.mobileWorldContentPaths[language];
    String url = BungieApiService.url(path);
    String localPath = await _localPath;
    HttpClient httpClient = new HttpClient();
    HttpClientRequest req = await httpClient.getUrl(Uri.parse(url));
    HttpClientResponse res = await req.close();
    File manifestFile = File("$localPath/$_manifestFilename");
    IOSink sink = manifestFile.openWrite();
    int totalSize = res.contentLength;
    int loaded = 0;
    Stream<List<int>> stream = res.asBroadcastStream();
    await for (var data in stream) {
      loaded += data.length;
      sink.add(data);
      if (onProgress != null) {
        onProgress(loaded, totalSize);
      }
    }
    await sink.flush();
    await sink.close();

    bool success = await test();
    if (!success) return false;

    await saveManifestVersion(path);
    _cached.clear();
    return success;
  }

  @override
  Future<DestinyInventoryBucketDefinition> getBucketDefinition(int hash) async {
    var res = await getDefinition<DestinyInventoryBucketDefinition>(
        hash, DestinyInventoryBucketDefinition.fromMap);
    return res;
  }

  @override
  Future<DestinyClassDefinition> getClassDefinition(int hash) async {
    var res = await getDefinition<DestinyClassDefinition>(
        hash, DestinyClassDefinition.fromMap);
    return res;
  }

  Future<T> getDefinition<T>(int hash,
      [dynamic identity(Map<String, dynamic> json)]) async {
    String type = DefinitionTableNames.fromClass[T];
    try {
      var cached = _cached["${type}_$hash"];
      if (cached != null) {
        return cached;
      }
    } catch (e) {}

    if (identity == null) {
      identity = DefinitionTableNames.identities[T];
    }
    if (identity == null) {
      throw "missing identity for $T";
    }
    Map<String,dynamic> json = await _openJson();
    try {
      String resultString = json[type]["$hash"];
      var def = identity(jsonDecode(resultString));
      _cached["${type}_$hash"] = def;
      return def;
    } catch (e) {
    }
    return null;
  }

  T getDefinitionFromCache<T>(int hash) {
    var type = DefinitionTableNames.fromClass[T];
    return _cached["${type}_$hash"];
  }

  Future<Map<int, T>> getDefinitions<T>(Iterable<int> hashes,
      [dynamic identity(Map<String, dynamic> json)]) async {
    Set<int> hashesSet = hashes.toSet();
    var type = DefinitionTableNames.fromClass[T];
    if (identity == null) {
      identity = DefinitionTableNames.identities[T];
    }
    Map<int, T> defs = new Map();
    hashesSet.removeWhere((hash) {
      if (_cached.keys.contains("${type}_$hash")) {
        defs[hash] = _cached["${type}_$hash"];
        return true;
      }
      return false;
    });

    if (hashesSet.length == 0) {
      return defs;
    }
    
    Map<String, dynamic> jsonFile = await _openJson();

    List<Map<String, dynamic>> results = [];
    for(var hash in hashesSet){
      results.add(jsonFile[type]["$hash"]);
    }
    try {
      results.forEach((res) {
        int id = res['id'];
        int hash = id < 0 ? id + 4294967296 : id;
        String resultString = res['json'];
        var def = identity(jsonDecode(resultString));
        _cached["${type}_$hash"] = def;
        defs[hash] = def;
      });
    } catch (e) {}
    return defs.cast<int, T>();
  }

  @override
  Future<DestinyInventoryItemDefinition> getItemDefinition(int hash) async {
    var res = await getDefinition<DestinyInventoryItemDefinition>(
        hash, DestinyInventoryItemDefinition.fromMap);
    return res;
  }

  @override
  Future<DestinyRaceDefinition> getRaceDefinition(int hash) async {
    DestinyRaceDefinition res = await getDefinition<DestinyRaceDefinition>(
        hash, DestinyRaceDefinition.fromMap);
    return res;
  }

  @override
  Future<DestinyStatDefinition> getStatDefinition(int hash) async {
    var res = await getDefinition<DestinyStatDefinition>(
        hash, DestinyStatDefinition.fromMap);
    return res;
  }

  @override
  Future<DestinyTalentGridDefinition> getTalentGridDefinition(int hash) async {
    var res = await getDefinition<DestinyTalentGridDefinition>(
        hash, DestinyTalentGridDefinition.fromMap);
    return res;
  }

  @override
  bool isLoaded<T>(int hash) {
    var type = DefinitionTableNames.fromClass[T];
    return _cached.keys.contains("${type}_$hash");
  }

  @override
  Future<bool> test() async {
    Map<String, dynamic> jsonFile = await _openJson();
    return jsonFile.keys.length > 0;
  }

  Future<Map<String, dynamic>> _openJson() async {
    if(_json != null){
      return _json;
    }
    String localPath = await _localPath;
    String file = await File("$localPath/$_manifestFilename").readAsString();
    _json = jsonDecode(file);
    return _json;
  }
}
