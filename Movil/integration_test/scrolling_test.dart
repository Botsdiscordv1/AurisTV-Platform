import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:auristv_mobile/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Performance profiling test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AurisApp()));

    // Esperar a que el splash (/splash -> /) navegue al home y las
    // secciones carguen de red (schedule/trending).
    final scrollableFinder = find.byKey(const ValueKey('home_scrollable'));
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (scrollableFinder.evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
    }
    if (scrollableFinder.evaluate().isEmpty) {
      final types = tester.allWidgets
          .take(50)
          .map((w) => w.runtimeType.toString())
          .toList();
      // ignore: avoid_print
      print('DIAG pantalla actual (50 widgets): $types');
    }
    expect(
      scrollableFinder,
      findsOneWidget,
      reason: 'El home no cargó en 30s (splash o red)',
    );

    // Dar un margen extra para que las primeras secciones pueblen la lista.
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();

    await binding.traceAction(() async {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('target_item')),
        500.0,
        scrollable: scrollableFinder,
      );
    }, reportKey: 'scrolling_timeline');
  });
}
