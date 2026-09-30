import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/service/morphhealth_service.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/util/clock.dart';
import 'package:http/http.dart' as http;

/// Temporary directories are created inside the project (build/test_tmp),
/// never in the system temp directory.
Future<Directory> createTempDir(String prefix) async {
  final base = Directory('build/test_tmp');
  await base.create(recursive: true);
  return base.createTemp(prefix);
}

Uint8List testKey([int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
}

FixedClock clockAt(String rfc3339) => FixedClock.parseRfc3339(rfc3339);

Future<(MorphHealthService, Repository, Directory)> openService({
  String now = '2026-09-23T10:00:00+02:00',
  http.Client? httpClient,
  Directory? dir,
  Uint8List? key,
}) async {
  final directory = dir ?? await createTempDir('svc');
  final clock = clockAt(now);
  final repo = await Repository.open(
    directory: directory,
    masterKey: key ?? testKey(),
    clock: clock,
  );
  final service = MorphHealthService(
    repo: repo,
    clock: clock,
    defaultFoodApi: FoodApiConfig('https://food.example.test', 'MorphHealthTest/1.0'),
    httpClient: httpClient,
  );
  return (service, repo, directory);
}
