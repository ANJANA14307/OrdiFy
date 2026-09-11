import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ordify_app/core/router/router.dart';
import 'package:ordify_app/main.dart';

void main() {
  testWidgets('app renders its configured router', (WidgetTester tester) async {
    final testRouter = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('OrdiFy'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const OrdiFyApp(),
      ),
    );

    expect(find.text('OrdiFy'), findsOneWidget);
  });
}
