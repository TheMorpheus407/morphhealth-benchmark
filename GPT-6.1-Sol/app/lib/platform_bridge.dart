import 'dart:convert';
import 'package:flutter/services.dart';
import 'core/nutrients.dart';

class PlatformBridge {
  static const channel = MethodChannel('de.themorpheus.morphhealth/vault');
  static Future<Json> vault() async =>
      Map<String, dynamic>.from(await channel.invokeMethod('vault') as Map);
  static Future<bool> saveDocument(
    String name,
    List<int> bytes,
    String mime,
  ) async =>
      await channel.invokeMethod<bool>('saveDocument', {
        'name': name,
        'bytes': Uint8List.fromList(bytes),
        'mime': mime,
      }) ??
      false;
  static Future<Uint8List?> openDocument() =>
      channel.invokeMethod<Uint8List>('openDocument');
  static Future<void> resetStorage() => channel.invokeMethod('resetStorage');
  static Future<bool> saveJson(String name, Json document) => saveDocument(
    name,
    utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
    'application/json',
  );
}
