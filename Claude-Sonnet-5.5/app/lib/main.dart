import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Die Semantik-Struktur steht immer bereit (Screenreader, Automatisierung).
  SemanticsBinding.instance.ensureSemantics();
  await initializeDateFormatting('de');
  await initializeDateFormatting('en');
  runApp(MorphHealthApp(boot: boot()));
}
