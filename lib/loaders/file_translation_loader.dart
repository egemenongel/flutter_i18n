import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/loaders/decoders/base_decode_strategy.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_i18n/loaders/decoders/xml_decode_strategy.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:flutter_i18n/loaders/decoders/toml_decode_strategy.dart';
import 'package:flutter_i18n/loaders/file_content.dart';
import 'package:flutter_i18n/loaders/translation_loader.dart';

import '../utils/message_printer.dart';

/// Loads translation files from JSON, YAML or XML format
class FileTranslationLoader extends TranslationLoader implements IFileContent {
  final String fallbackFile;
  final String basePath;
  final bool useCountryCode;
  final bool useScriptCode;
  AssetBundle assetBundle = rootBundle;

  Map<dynamic, dynamic> _decodedMap = Map();
  late List<BaseDecodeStrategy> _decodeStrategies;

  set decodeStrategies(List<BaseDecodeStrategy>? decodeStrategies) =>
      _decodeStrategies = decodeStrategies ??
          [JsonDecodeStrategy(), YamlDecodeStrategy(), XmlDecodeStrategy(), TomlDecodeStrategy()];

  FileTranslationLoader(
      {this.fallbackFile = "en",
      this.basePath = "assets/flutter_i18n",
      this.useCountryCode = false,
      this.useScriptCode = false,
      forcedLocale,
      decodeStrategies}) {
    this.forcedLocale = forcedLocale;
    this.decodeStrategies = decodeStrategies;
  }

  /// Return the translation Map
  Future<Map> load() async {
    _decodedMap = Map();
    await _loadCurrentTranslation();
    await _loadFallback();
    return _decodedMap;
  }

  /// Load the file using the AssetBundle rootBundle
  @override
  Future<String> loadString(final String fileName, final String extension) {
    return assetBundle.loadString('$basePath/$fileName.$extension',
        cache: false);
  }

  Future _loadCurrentTranslation() async {
    try {
      this.locale = locale ?? await findDeviceLocale();
      MessagePrinter.info("The current locale is ${this.locale}");
      _decodedMap.addAll(await loadFile(composeFileName()));
    } catch (e) {
      MessagePrinter.debug('Error loading translation $e');
    }
  }

  Future _loadFallback() async {
    try {
      final Map fallbackMap = await loadFile(fallbackFile);
      _decodedMap = {...fallbackMap, ..._decodedMap};
    } catch (e) {
      MessagePrinter.debug('Error loading translation fallback $e');
    }
  }

  /// Load the fileName using one of the strategies provided
  @protected
  Future<Map> loadFile(final String fileName) async {
    final List<Future<Map?>> strategiesFutures = _executeStrategies(fileName);
    final Stream<Map?> strategiesStream = Stream.fromFutures(strategiesFutures);
    return await strategiesStream.firstWhere((map) => map != null,
            orElse: null) ??
        Map();
  }

  List<Future<Map?>> _executeStrategies(final String fileName) {
    return _decodeStrategies
        .map((decodeStrategy) => decodeStrategy.decode(fileName, this))
        .toList();
  }

  /// Compose the file name using the format languageCode_countryCode
  @protected
  String composeFileName() {
    return "${locale!.languageCode}${_composeSuffixCode()}";
  }

  /// Return the country code to attach to the file name, if required
  @protected
  String _composeSuffixCode() {
    String countryCode = "";
    if(useScriptCode && locale!.scriptCode != null) {
      countryCode = "${countryCode}_${locale!.scriptCode}";
    }
    if (useCountryCode && locale!.countryCode != null) {
      countryCode = "${countryCode}_${locale!.countryCode}";
    }
    return countryCode;
  }
}
