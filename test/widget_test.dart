import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/widgets/govia_widgets.dart';

void main() {
  test('Desktop GoVia brand asset uses the canonical source path', () {
    expect(GoViaLogo.assetPath, 'assets/brand/govia-logo-horizontal.png');
    final file = File(GoViaLogo.assetPath);
    expect(file.existsSync(), isTrue,
        reason: 'The canonical Desktop GoVia logo asset must exist in the repository.');
    expect(file.lengthSync(), greaterThan(0));
  });
}
