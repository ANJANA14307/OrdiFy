import 'package:flutter/material.dart';
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
import 'package:ordify_app/features/catalog_share/catalog_share_screen.dart';
import 'package:ordify_app/features/catalog_share/catalog_preview_screen.dart';
import 'package:ordify_app/features/whatsapp_orders/whatsapp_setup_screen.dart';
import 'package:ordify_app/features/whatsapp_orders/message_templates_screen.dart';
import 'package:ordify_app/features/whatsapp_orders/social_orders_inbox_screen.dart';
import 'package:ordify_app/features/whatsapp_orders/social_order_detail_screen.dart';
import 'package:ordify_app/features/instagram_redirect/instagram_tools_screen.dart';
import 'package:ordify_app/features/returns/return_detail_screen.dart';
import 'package:ordify_app/features/returns/return_policy_screen.dart';
import 'package:ordify_app/features/returns/return_request_screen.dart';
import 'package:ordify_app/features/returns/returns_list_screen.dart';
import 'package:ordify_app/features/shared_catalog/catalog_search_screen.dart';
import 'package:ordify_app/features/shared_catalog/create_listing_screen.dart';
import 'package:ordify_app/features/shared_catalog/my_listings_screen.dart';
import 'package:ordify_app/features/shared_catalog/suggest_catalog_product_screen.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => createAppRouter(ref.watch(authProvider)),
);

GoRouter createAppRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => _notFoundPage(context),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/';
      final isGoingToAuth = location == '/login' || location == '/register';
      final isPublicCatalog = location.startsWith('/catalog/');
      final isNotFound =
          location == '/not-found' || (state.fullPath?.isEmpty ?? true);

      if (authState is AuthInitial) {
        return isSplash || isPublicCatalog || isNotFound ? null : '/';
      }

      if (authState is AuthError) {
        if (isPublicCatalog || isNotFound) return null;
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
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/not-found',
        builder: (context, state) => _notFoundPage(context),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
        path: '/catalog-share',
        builder: (context, state) => const CatalogShareScreen(),
      ),
      GoRoute(
        path: '/catalog/:slug',
        builder: (context, state) => CatalogPreviewScreen(
          slug: state.pathParameters['slug']!,
          productId: state.uri.queryParameters['product'],
        ),
      ),
      GoRoute(
        path: '/whatsapp-ordering',
        builder: (context, state) => const WhatsAppSetupScreen(),
      ),
      GoRoute(
        path: '/whatsapp-ordering/templates',
        builder: (context, state) => const MessageTemplatesScreen(),
      ),
      GoRoute(
        path: '/whatsapp-orders',
        builder: (context, state) => const SocialOrdersInboxScreen(),
      ),
      GoRoute(
        path: '/whatsapp-orders/:socialOrderId',
        builder: (context, state) => SocialOrderDetailScreen(
          orderId: state.pathParameters['socialOrderId']!,
        ),
      ),
      GoRoute(
        path: '/instagram-tools',
        builder: (context, state) => const InstagramToolsScreen(),
      ),
      GoRoute(
        path: '/return-policy',
        builder: (context, state) => const ReturnPolicyScreen(),
      ),
      GoRoute(
        path: '/returns',
        builder: (context, state) => const ReturnsListScreen(),
      ),
      GoRoute(
        path: '/returns/request/:orderId',
        builder: (context, state) =>
            ReturnRequestScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/returns/:returnId',
        builder: (context, state) =>
            ReturnDetailScreen(returnId: state.pathParameters['returnId']!),
      ),
      GoRoute(
        path: '/shared-catalog/search',
        builder: (context, state) => const CatalogSearchScreen(),
      ),
      GoRoute(
        path: '/shared-catalog/suggest',
        builder: (context, state) => const SuggestCatalogProductScreen(),
      ),
      GoRoute(
        path: '/shared-catalog/listings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/shared-catalog/listing/:catalogProductId',
        builder: (context, state) => CreateListingScreen(
          catalogProductId: state.pathParameters['catalogProductId']!,
          initialProduct: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
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
}

Widget _notFoundPage(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('This page could not be found.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Go to home'),
          ),
        ],
      ),
    ),
  );
}
