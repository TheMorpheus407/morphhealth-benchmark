// MorphHealth — Einstieg der Android-App (SPEC P09).
library;

import 'package:flutter/material.dart';

import 'src/ui/app.dart';
import 'src/ui/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Bootstrap bootstrap = await bootstrapApp();
  runApp(MorphHealthApp(bootstrap: bootstrap));
}
