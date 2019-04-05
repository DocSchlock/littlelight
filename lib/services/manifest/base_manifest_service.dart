import 'package:bungie_api/models/destiny_class_definition.dart';
import 'package:bungie_api/models/destiny_inventory_bucket_definition.dart';
import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:bungie_api/models/destiny_manifest.dart';
import 'package:bungie_api/models/destiny_race_definition.dart';
import 'package:bungie_api/models/destiny_stat_definition.dart';
import 'package:bungie_api/models/destiny_talent_grid_definition.dart';
import 'package:bungie_api/responses/destiny_manifest_response.dart';
import 'package:little_light/services/bungie_api/bungie_api.service.dart';
import 'package:little_light/services/translate/translate.service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Type DownloadProgress(int downloaded, int total);

abstract class BaseManifestService {
  static const String _manifestVersionKey = "manifestVersion";
  DestinyManifest _manifestInfo;
  final BungieApiService _api = new BungieApiService();
  
  bool isLoaded<T>(int hash);

  T getDefinitionFromCache<T>(int hash);

  Future<DestinyManifest> loadManifestInfo() async {
    if (_manifestInfo != null) {
      return _manifestInfo;
    }
    DestinyManifestResponse response = await _api.getManifest();
    _manifestInfo = response.response;
    return _manifestInfo;
  }

  Future<List<String>> getAvailableLanguages() async {
    DestinyManifest manifestInfo = await loadManifestInfo();
    List<String> availableLanguages =
        manifestInfo.mobileWorldContentPaths.keys.toList();
    return availableLanguages;
  }

  Future<bool> needsUpdate() async {
    DestinyManifest manifestInfo = await loadManifestInfo();
    String currentVersion = await getSavedVersion();
    String language = await new TranslateService().getLanguage();
    return currentVersion != manifestInfo.mobileWorldContentPaths[language];
  }

  Future<bool> download({DownloadProgress onProgress});
  Future<bool> test();

  Future<String> getSavedVersion() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    String version = _prefs.getString(_manifestVersionKey);
    if (version == null) {
      return null;
    }
    return version;
  }

  Future<void> saveManifestVersion(String version) async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    _prefs.setString(_manifestVersionKey, version);
  }

  Future<DestinyInventoryItemDefinition> getItemDefinition(int hash);

  Future<DestinyStatDefinition> getStatDefinition(int hash);

  Future<DestinyTalentGridDefinition> getTalentGridDefinition(int hash);

  Future<DestinyInventoryBucketDefinition> getBucketDefinition(int hash);

  Future<DestinyClassDefinition> getClassDefinition(int hash);

  Future<DestinyRaceDefinition> getRaceDefinition(int hash);

  Future<Map<int, T>> getDefinitions<T>(Iterable<int> hashes,
      [dynamic identity(Map<String, dynamic> json)]);

  Future<T> getDefinition<T>(int hash,
      [dynamic identity(Map<String, dynamic> json)]);
}