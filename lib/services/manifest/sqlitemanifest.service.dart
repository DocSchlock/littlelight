import 'dart:convert';

import 'package:bungie_api/models/destiny_inventory_bucket_definition.dart';
import 'package:bungie_api/models/destiny_manifest.dart';
import 'package:bungie_api/models/destiny_stat_definition.dart';
import 'package:bungie_api/models/destiny_class_definition.dart';
import 'package:bungie_api/models/destiny_race_definition.dart';
import 'package:bungie_api/models/destiny_talent_grid_definition.dart';
import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:flutter/foundation.dart';
import 'package:little_light/services/bungie_api/bungie_api.service.dart';
import 'package:little_light/services/bungie_api/enums/definition_table_names.enum.dart';
import 'package:little_light/services/manifest/base_manifest_service.dart';
import 'package:little_light/services/translate/translate.service.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class SQLiteManifestService extends BaseManifestService {
  final Map<String, dynamic> _cached = Map();
  static const String _manifestFilename = "manifest.db";
  sqflite.Database _db;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<sqflite.Database> _openDb() async {
    if (_db?.isOpen ?? false != false) {
      return _db;
    }
    String localPath = await _localPath;
    sqflite.Database database =
        await sqflite.openDatabase("$localPath/$_manifestFilename");
    _db = database;
    return _db;
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
    File zipFile = new File("$localPath/manifest_temp.zip");
    IOSink sink = zipFile.openWrite();
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

    File manifestFile = await File("$localPath/$_manifestFilename").create();
    List<int> unzippedData = await compute(_extractFromZip, zipFile);
    manifestFile = await manifestFile.writeAsBytes(unzippedData);

    await zipFile.delete();

    await _openDb();

    bool success = await test();
    if (!success) return false;

    await saveManifestVersion(path);
    _cached.clear();
    return success;
  }

  static List<int> _extractFromZip(dynamic zipFile) {
    List<int> unzippedData;
    List<int> bytes = zipFile.readAsBytesSync();
    ZipDecoder decoder = new ZipDecoder();
    Archive archive = decoder.decodeBytes(bytes);
    for (ArchiveFile file in archive) {
      if (file.isFile) {
        unzippedData = file.content;
      }
    }
    return unzippedData;
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
    int searchHash = hash > 2147483648 ? hash - 4294967296 : hash;
    sqflite.Database db = await _openDb();
    try {
      List<Map<String, dynamic>> results = await db.query(type,
          columns: ['json'], where: "id=?", whereArgs: [searchHash]);
      if (results.length < 1) {
        return null;
      }
      String resultString = results.first['json'];
      var def = identity(jsonDecode(resultString));
      _cached["${type}_$hash"] = def;
      return def;
    } catch (e) {
      if (e is sqflite.DatabaseException && e.isDatabaseClosedError()) {
        _db = null;
        return getDefinition(hash, identity);
      }
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
    List<int> searchHashes = hashesSet
        .map((hash) => hash > 2147483648 ? hash - 4294967296 : hash)
        .toList();
    String idList = "(" + List.filled(hashesSet.length, '?').join(',') + ")";

    sqflite.Database db = await _openDb();

    List<Map<String, dynamic>> results = await db.query(type,
        columns: ['id', 'json'],
        where: "id in $idList",
        whereArgs: searchHashes);
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
    sqflite.Database db = await _openDb();
    List<Map<String, dynamic>> results =
        await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    return results.length > 0;
  }
}
