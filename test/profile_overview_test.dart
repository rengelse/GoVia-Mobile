import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/theme/govia_theme.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/profile/presentation/profile_overview.dart';

void main() {
  const profile = UserProfile(id: 'test', email: 'test@example.com',
    displayName: 'Testbruker', bio: 'Detaljert bio', preferredTransport: StageTransport.cycling);

  testWidgets('overview shows identity and five destinations without editing controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: ProfileOverview(profile: profile, onOpen: (_) {})))));
    expect(find.text('Testbruker'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Detaljert bio'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining(transportLabel(StageTransport.cycling)), findsOneWidget);
  });

  testWidgets('each menu choice opens its own destination with working back navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => SingleChildScrollView(
      child: ProfileOverview(profile: profile, onOpen: (section) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: Text(section.title)),
          body: Text('side:${section.name}'))))))))));
    for (final section in ProfileSection.values) {
      final tile = find.byKey(ValueKey(section));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('side:${section.name}'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileOverview), findsOneWidget);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('overview supports $brightness on a narrow screen with larger text', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: buildGoViaTheme(brightness: brightness),
        home: MediaQuery(data: const MediaQueryData(size: Size(320, 720), textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(18),
            child: ProfileOverview(profile: profile, onOpen: (_) {})))))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final tile = tester.widget<ListTile>(find.byKey(const ValueKey(ProfileSection.settings)));
      final context = tester.element(find.byType(ProfileOverview));
      expect((tile.leading! as Icon).color, Theme.of(context).colorScheme.primary);
    });
  }
}
