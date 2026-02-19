import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hume/main.dart';

void main() {
  testWidgets('App loads with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const HumeApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
  });
}
