import 'package:bungie_api/models/destiny_inventory_bucket_definition.dart';
import 'package:bungie_api/models/destiny_manifest.dart';
import 'package:bungie_api/models/destiny_stat_definition.dart';
import 'package:bungie_api/models/destiny_class_definition.dart';
import 'package:bungie_api/models/destiny_race_definition.dart';
import 'package:bungie_api/models/destiny_talent_grid_definition.dart';
import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:flutter/foundation.dart';
import 'package:little_light/services/manifest/base_manifest_service.dart';
import 'package:little_light/services/manifest/json_manifest.service.dart';
import 'package:little_light/services/manifest/sqlitemanifest.service.dart';

typedef Type DownloadProgress(int downloaded, int total);

class ManifestService {
  BaseManifestService _service;
  static final ManifestService _singleton = new ManifestService._internal();

  factory ManifestService() {
    return _singleton;
  }
  ManifestService._internal() {
    if (_service != null) return;
    if(debugDefaultTargetPlatformOverride == TargetPlatform.fuchsia){
      _service = JSONManifestService();
    }else{
      _service = SQLiteManifestService();
    }
  }

  bool isLoaded<T>(int hash) {
    return _service.isLoaded(hash);
  }

  T getDefinitionFromCache<T>(int hash) {
    return _service.getDefinitionFromCache<T>(hash);
  }

  Future<DestinyManifest> loadManifestInfo() async {
    return _service.loadManifestInfo();
  }

  Future<List<String>> getAvailableLanguages() async {
    return _service.getAvailableLanguages();
  }

  Future<bool> needsUpdate() async {
    return _service.needsUpdate();
  }

  Future<bool> download({DownloadProgress onProgress}) async {
    return _service.download();
  }

  Future<bool> test() async {
    return _service.test();
  }

  Future<String> getSavedVersion() async {
    return _service.getSavedVersion();
  }

  Future<void> saveManifestVersion(String version) async {
    return _service.saveManifestVersion(version);
  }

  Future<DestinyInventoryItemDefinition> getItemDefinition(int hash) async {
    return _service.getItemDefinition(hash);
  }

  Future<DestinyStatDefinition> getStatDefinition(int hash) async {
    return _service.getStatDefinition(hash);
  }

  Future<DestinyTalentGridDefinition> getTalentGridDefinition(int hash) async {
    return _service.getTalentGridDefinition(hash);
  }

  Future<DestinyInventoryBucketDefinition> getBucketDefinition(int hash) async {
    return _service.getBucketDefinition(hash);
  }

  Future<DestinyClassDefinition> getClassDefinition(int hash) async {
    return _service.getClassDefinition(hash);
  }

  Future<DestinyRaceDefinition> getRaceDefinition(int hash) async {
    return _service.getRaceDefinition(hash);
  }

  Future<Map<int, T>> getDefinitions<T>(Iterable<int> hashes,
      [dynamic identity(Map<String, dynamic> json)]) async {
    return _service.getDefinitions<T>(hashes, identity);
  }

  Future<T> getDefinition<T>(int hash,
      [dynamic identity(Map<String, dynamic> json)]) async {
    return _service.getDefinition<T>(hash, identity);
  }
}
