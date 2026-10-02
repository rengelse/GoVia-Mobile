import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/theme/govia_theme.dart';

void main() {
  test('app themes retain GoVia accent and provide opposite surface brightness', () {
    final light = buildGoViaTheme(brightness: Brightness.light);
    final dark = buildGoViaTheme();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, GoViaColors.orange);
    expect(dark.colorScheme.primary, GoViaColors.orange);
    expect(light.colorScheme.surface.computeLuminance(), greaterThan(.5));
    expect(dark.colorScheme.surface.computeLuminance(), lessThan(.2));
    expect(light.colorScheme.onSurface.computeLuminance(), lessThan(.2));
    expect(dark.colorScheme.onSurface.computeLuminance(), greaterThan(.5));
  });
}
