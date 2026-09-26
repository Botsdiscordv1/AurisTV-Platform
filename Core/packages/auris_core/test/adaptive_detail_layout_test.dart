import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  testWidgets('AdaptiveDetailLayout renders successfully with box widget content (Column)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdaptiveDetailLayout(
          backdrop: Placeholder(),
          content: Column(
            children: [
              Text('Item 1'),
              Text('Item 2'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AdaptiveDetailLayout), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets('AdaptiveDetailLayout renders successfully with sliver widget content (SliverList)', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveDetailLayout(
          backdrop: const Placeholder(),
          content: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Text('Sliver Item $index'),
              childCount: 3,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AdaptiveDetailLayout), findsOneWidget);
    expect(find.text('Sliver Item 0'), findsOneWidget);
  });
}
