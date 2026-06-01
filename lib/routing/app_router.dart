import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/screens/add_edit_address_screen.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/screens/address_list_screen.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/screens/phone_entry_screen.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/screens/categories_screen.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/screens/category_products_screen.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/screens/home_screen.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/screens/location_unavailable_screen.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/screens/notification_preferences_screen.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/screens/order_success_screen.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_screen.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cafe/presentation/screens/cafe_screen.dart';
import 'package:bakaloo_flutter_app/features/off_zone/presentation/screens/off_zone_screen.dart';
import 'package:bakaloo_flutter_app/features/super_mall/presentation/screens/super_mall_screen.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/screens/search_screen.dart';
import 'package:bakaloo_flutter_app/features/splash/splash_screen.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/screens/order_tracking_screen.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/screens/topup_screen.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/screens/wishlist_screen.dart';
import 'package:bakaloo_flutter_app/routing/route_guards.dart';
import 'package:bakaloo_flutter_app/routing/route_access.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_bottom_nav.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> _homeBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
final GlobalKey<NavigatorState> _ordersBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ordersBranch');
final GlobalKey<NavigatorState> _categoriesBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'categoriesBranch');
final GlobalKey<NavigatorState> _profileBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileBranch');

@riverpod
UserEntity? currentUser(Ref ref) {
  final authState = ref.watch(authStateProvider);
  return switch (authState) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
}

@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(authStateProvider) is AuthAuthenticated;
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authGuard = ref.watch(authGuardProvider.notifier);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: authGuard,
    redirect: (BuildContext context, GoRouterState state) {
      final authenticated = ref.read(isAuthenticatedProvider);
      final pendingIntent = ref.read(pendingAuthIntentProvider);
      final location = state.matchedLocation;
      final onboardingValue = HiveService.settingsBox.get(
        StorageKeys.onboardingShown,
      );
      final onboardingShown = onboardingValue is bool ? onboardingValue : false;
      final isAuthRoute =
          location == RouteNames.phone || location == RouteNames.otp;
      final isSplashRoute = location == RouteNames.splash;
      final isOnboardingRoute = location == RouteNames.onboarding;

      if (onboardingShown && isOnboardingRoute) {
        return RouteNames.home;
      }

      if (!authenticated &&
          !isAuthRoute &&
          !isSplashRoute &&
          !isOnboardingRoute &&
          RouteAccess.isProtectedLocation(location)) {
        ref
            .read(authGateControllerProvider)
            .rememberRouteIntent(state.uri.toString());
        return RouteNames.phone;
      }

      if (authenticated && isAuthRoute && pendingIntent == null) {
        return RouteNames.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: RouteNames.phone,
        builder: (BuildContext context, GoRouterState state) {
          return const PhoneEntryScreen();
        },
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (BuildContext context, GoRouterState state) {
          return OtpVerifyScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RouteNames.search,
        builder: (BuildContext context, GoRouterState state) {
          return const SearchScreen();
        },
      ),
      GoRoute(
        path: RouteNames.locationUnavailable,
        builder: (BuildContext context, GoRouterState state) {
          return const LocationUnavailableScreen();
        },
      ),
      GoRoute(
        path: '/product/:productId',
        builder: (BuildContext context, GoRouterState state) {
          return ProductDetailScreen(
            id: state.pathParameters['productId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const _RoutePlaceholderScreen('OnboardingScreen');
        },
      ),
      GoRoute(
        path: '/orders/success/:orderId',
        builder: (BuildContext context, GoRouterState state) {
          return OrderSuccessScreen(
            orderId: state.pathParameters['orderId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RouteNames.cart,
        builder: (BuildContext context, GoRouterState state) {
          return const CartScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'checkout',
            builder: (BuildContext context, GoRouterState state) {
              return const CheckoutScreen();
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'payment',
                builder: (BuildContext context, GoRouterState state) {
                  return const _RoutePlaceholderScreen('PaymentScreen');
                },
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(
            navigationShell: navigationShell,
            branchNavigatorKeys: <GlobalKey<NavigatorState>>[
              _homeBranchNavigatorKey,
              _ordersBranchNavigatorKey,
              _categoriesBranchNavigatorKey,
              _profileBranchNavigatorKey,
            ],
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.home,
                builder: (BuildContext context, GoRouterState state) {
                  return const HomeScreen();
                },
              ),
              GoRoute(
                path: RouteNames.offZone,
                builder: (BuildContext context, GoRouterState state) {
                  return const OffZoneScreen();
                },
              ),
              GoRoute(
                path: RouteNames.superMall,
                builder: (BuildContext context, GoRouterState state) {
                  return const SuperMallScreen();
                },
              ),
              GoRoute(
                path: RouteNames.cafe,
                builder: (BuildContext context, GoRouterState state) {
                  return const CafeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _ordersBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.orders,
                builder: (BuildContext context, GoRouterState state) {
                  return const OrdersScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: ':orderId',
                    builder: (BuildContext context, GoRouterState state) {
                      return OrderDetailScreen(
                        id: state.pathParameters['orderId'] ?? '',
                      );
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'track',
                        builder: (BuildContext context, GoRouterState state) {
                          return OrderTrackingScreen(
                            id: state.pathParameters['orderId'] ?? '',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _categoriesBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.categories,
                builder: (BuildContext context, GoRouterState state) {
                  return const CategoriesScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: ':categoryId/products',
                    builder: (BuildContext context, GoRouterState state) {
                      return CategoryProductsScreen(
                        id: state.pathParameters['categoryId'] ?? '',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileBranchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profile,
                builder: (BuildContext context, GoRouterState state) {
                  return const ProfileScreen();
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (BuildContext context, GoRouterState state) {
                      return const EditProfileScreen();
                    },
                  ),
                  GoRoute(
                    path: 'wallet',
                    builder: (BuildContext context, GoRouterState state) {
                      return const WalletScreen();
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'topup',
                        builder: (BuildContext context, GoRouterState state) {
                          return const TopupScreen();
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'wishlist',
                    builder: (BuildContext context, GoRouterState state) {
                      return const WishlistScreen();
                    },
                  ),
                  GoRoute(
                    path: 'addresses',
                    builder: (BuildContext context, GoRouterState state) {
                      return const AddressListScreen();
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'add',
                        builder: (BuildContext context, GoRouterState state) {
                          return AddEditAddressScreen(
                            initialAddress: state.extra as AddressEntity?,
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (BuildContext context, GoRouterState state) {
                      return const NotificationsScreen();
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'preferences',
                        builder: (BuildContext context, GoRouterState state) {
                          return const NotificationPreferencesScreen();
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reviews',
                    builder: (BuildContext context, GoRouterState state) {
                      return const ReviewsScreen();
                    },
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (BuildContext context, GoRouterState state) {
                      return const _RoutePlaceholderScreen('SettingsScreen');
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _RoutePlaceholderScreen extends StatelessWidget {
  const _RoutePlaceholderScreen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label),
      ),
    );
  }
}
