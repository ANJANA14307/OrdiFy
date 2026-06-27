import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';

import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/register_screen.dart';

import '../../presentation/workspace/workspace_shell.dart';
import '../../presentation/workspace/dashboard_screen.dart';
import '../../presentation/workspace/orders_screen.dart';
import '../../presentation/workspace/inventory_screen.dart';
import '../../presentation/workspace/customers_screen.dart';
import '../../presentation/workspace/ai_tools_screen.dart';
import '../../presentation/workspace/dm_inbox_screen.dart';

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
        if (isSplash || isGoingToAuth) return '/dashboard';
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