import 'package:baganetic_mobile/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('onboarding completion is stored locally', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await OnboardingPreference.hasCompleted(), isFalse);

    await OnboardingPreference.markCompleted();

    expect(await OnboardingPreference.hasCompleted(), isTrue);
  });

  testWidgets('onboarding moves through the approved product flow', (
    tester,
  ) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onFinished: () async => finished = true),
      ),
    );

    expect(find.text('Find places worth the stop.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Make the route yours.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Useful notes from fellow travelers.'), findsOneWidget);
    await tester.tap(find.text('START EXPLORING'));
    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets('onboarding does not navigate when swiped like a gallery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(onFinished: _noop)),
    );

    await tester.dragFrom(const Offset(300, 400), const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(find.text('Find places worth the stop.'), findsOneWidget);
    expect(find.text('Make the route yours.'), findsNothing);
  });
}

Future<void> _noop() async {}
