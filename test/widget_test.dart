import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/widgets/govia_widgets.dart';

void main() {
  testWidgets('Desktop GoVia brand asset renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoViaLogo(),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
