import 'package:flutter/material.dart';

import 'core/l10n/format.dart';
import 'ui/app.dart';

/// MorphHealth – personal nutrition, cycle, weight and symptom diary.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFormatting();
  runApp(const MorphHealthApp());
}
