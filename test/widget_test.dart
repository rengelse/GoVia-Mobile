import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/widgets/govia_widgets.dart';

void main() {
  testWidgets('GoVia logo renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoViaLogo(),
        ),
      ),
    );

    expect(find.text('GoVia'), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
  });
}
