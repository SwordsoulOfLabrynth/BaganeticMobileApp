import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baganetic_mobile/presentation/widgets/pagoda_image_widget.dart';

void main() {
  testWidgets('PagodaImageWidget handles double.infinity width without crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PagodaImageWidget(
            imageUrl: 'assets/images/stitch/ananda_postcard.jpg',
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
