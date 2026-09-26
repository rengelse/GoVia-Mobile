import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/widgets/govia_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Desktop GoVia brand asset is bundled at the canonical path', () async {
    expect(GoViaLogo.assetPath, 'assets/brand/govia-logo-horizontal.png');
    final data = await rootBundle.load(GoViaLogo.assetPath);
    expect(data.lengthInBytes, greaterThan(0));
  });
}
