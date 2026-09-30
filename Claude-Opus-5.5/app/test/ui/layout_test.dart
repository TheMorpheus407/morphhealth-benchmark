import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/model/enums.dart';

import '../support/ui_harness.dart';
import '../support/ui_seed.dart';

/// Every screen must lay out without overflow in German and English, with
/// normal and enlarged system font sizes (real Roboto metrics, 1080×2400 px
/// at 420 dpi). Layout errors fail the test automatically.
void main() {
  setUpAll(loadRealFonts);

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('all screens lay out (${language.json}, text ×$scale)', (tester) async {
        await pumpMorphHealth(
          tester,
          seed: (r) => seedData(r, language: language),
          textScale: scale,
        );
        final visited = <String>[];
        await screenTour(tester, (screen) async {
          visited.add(screen);
          expect(tester.takeException(), isNull, reason: screen);
        });
        expect(visited, hasLength(13));
      });
    }
  }
}
