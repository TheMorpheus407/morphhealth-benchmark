import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/state/app_state.dart';

/// Entry point of MorphHealth.
///
/// The app opens the encrypted local store, prepares the product services and
/// shows the overview. Everything works offline; only the optional food lookup
/// needs the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState state = await AppState.bootstrap();
  runApp(MorphHealthApp(state: state));
}
