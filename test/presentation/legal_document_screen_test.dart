import 'package:baganetic_mobile/presentation/screens/legal/legal_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legal document screen shows the provided title and body', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(
          title: 'Privacy Policy',
          body: 'Guest mode does not require an account.',
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(
      find.textContaining('Guest mode does not require an account.'),
      findsOneWidget,
    );
  });
}
