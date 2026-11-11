import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ordify_app/core/auth/auth_notifier.dart';
import 'package:ordify_app/core/router/router.dart';
import 'package:ordify_app/main.dart';

void main() {
  testWidgets('app renders its configured router', (WidgetTester tester) async {
    final testRouter = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('OrdiFy')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(testRouter)],
        child: const OrdiFyApp(),
      ),
    );

    expect(find.text('OrdiFy'), findsOneWidget);
  });

  testWidgets('unknown routes show the custom not-found page', (
    WidgetTester tester,
  ) async {
    final router = createAppRouter(AuthError(''));
    addTearDown(router.dispose);
    router.go('/missing-route');

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('This page could not be found.'), findsOneWidget);
  });
}
