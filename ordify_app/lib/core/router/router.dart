import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ordify_app/core/auth/auth_notifier.dart';

import 'package:ordify_app/presentation/screens/splash_screen.dart';
import 'package:ordify_app/presentation/screens/login_screen.dart';
import 'package:ordify_app/presentation/screens/register_screen.dart';

import 'package:ordify_app/presentation/workspace/workspace_shell.dart';
import 'package:ordify_app/presentation/workspace/dashboard_screen.dart';
import 'package:ordify_app/presentation/workspace/orders_screen.dart';
import 'package:ordify_app/presentation/workspace/order_detail_screen.dart';
import 'package:ordify_app/presentation/workspace/inventory_screen.dart';
import 'package:ordify_app/presentation/workspace/customers_screen.dart';
import 'package:ordify_app/presentation/workspace/ai_tools_screen.dart';
import 'package:ordify_app/presentation/workspace/dm_inbox_screen.dart';

import 'package:ordify_app/presentation/workspace/payments_screen.dart';
import 'package:ordify_app/presentation/workspace/invoice_share_screen.dart';
import 'package:ordify_app/presentation/workspace/notifications_screen.dart';
import 'package:ordify_app/presentation/workspace/activity_screen.dart';
import 'package:ordify_app/presentation/workspace/analytics_screen.dart';
import 'package:ordify_app/presentation/workspace/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/';
      final isGoingToAuth = location == '/login' || location == '/register';

      if (authState is AuthInitial) {
        return isSplash ? null : '/';
      }

      if (authState is AuthError) {
        return isGoingToAuth ? null : '/login';
      }

      if (authState is AuthSuccess) {
        if (isSplash || isGoingToAuth) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/instagram-dms',
        builder: (context, state) => const DMInboxScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/:orderId/payments',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return PaymentsScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/:orderId/invoice-share',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return InvoiceShareScreen(orderId: orderId);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return WorkspaceShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-tools',
                builder: (context, state) => const AiToolsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});