import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/model/enums.dart';

import '../support/ui_harness.dart';
import '../support/ui_seed.dart';

/// Android accessibility guidelines on every screen: tap targets of at least
/// 48×48 dp, labelled tap targets and WCAG text contrast. (Runs with the
/// default block test font, which the contrast check is designed for.)
void main() {
  Future<void> guidelines(String screen, WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: screen);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: screen);
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: screen);
  }

  testWidgets('onboarding meets the accessibility guidelines', (tester) async {
    await pumpMorphHealth(tester, onboardingDone: false, realFonts: false);
    await guidelines('onboarding', tester);
  });

  for (final language in AppLanguage.values) {
    testWidgets('all screens meet the accessibility guidelines (${language.json})', (tester) async {
      await pumpMorphHealth(
        tester,
        seed: (r) => seedData(r, language: language),
        realFonts: false,
      );
      await screenTour(tester, (screen) => guidelines(screen, tester));
    });
  }
}
