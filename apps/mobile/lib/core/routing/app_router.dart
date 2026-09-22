import 'package:flutter/material.dart';
import '../../features/mapping/presentation/screens/ai_chat_screen.dart';
import '../../features/mapping/presentation/screens/building_overview_screen.dart';
import '../../features/mapping/presentation/screens/buildings_screen.dart';
import '../../features/mapping/presentation/screens/creator_editor_screen.dart';
import '../../features/mapping/presentation/screens/creator_mapping_screen.dart';
import '../../features/mapping/presentation/screens/creator_preview_screen.dart';
import '../../features/mapping/presentation/screens/creator_publish_screen.dart';
import '../../features/mapping/presentation/screens/home_screen.dart';
import '../../features/mapping/presentation/screens/home_shell_screen.dart';
import '../../features/mapping/presentation/screens/login_screen.dart';
import '../../features/mapping/presentation/screens/map_view_screen.dart';
import '../../features/mapping/presentation/screens/navigation_screen.dart';
import '../../features/mapping/presentation/screens/profile_screen.dart';
import '../../features/mapping/presentation/screens/register_screen.dart';
import '../../features/mapping/presentation/screens/settings_screen.dart';
import '../../features/mapping/presentation/screens/splash_screen.dart';
import '../../features/mapping/presentation/screens/version_history_screen.dart';
import '../../features/mapping/presentation/screens/visitor_screen.dart';
import 'invalid_route_screen.dart';

/// Centralized Application Router
/// Owner: Nishant (Phase 2 — Application Routing)
abstract final class AppRouter {
  // Navigation key for programmatic transitions
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Major Destinations
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String auth = '/auth';

  static const String home = '/';
  static const String homeShell = '/home-shell';
  static const String dashboard = '/dashboard';

  static const String buildings = '/buildings';
  static const String buildingOverview = '/buildings/overview';
  static const String creator = '/creator';
  static const String creatorEditor = '/creator/editor';
  static const String creatorPreview = '/creator/preview';
  static const String creatorPublish = '/creator/publish';
  static const String visitor = '/visitor';

  static const String map = '/map';
  static const String mapView = '/map-view';

  static const String navigation = '/navigation';

  static const String aiAssistant = '/ai-assistant';
  static const String aiChat = '/ai-chat';

  static const String versionHistory = '/version-history';
  static const String versioning = '/versioning';

  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String settingsRoute = '/settings';

  /// Generates application routes based on incoming [routeSettings]
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SplashScreen(),
        );

      case login:
      case auth:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LoginScreen(),
        );

      case register:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const RegisterScreen(),
        );

      case home:
      case homeShell:
        final tabIndex =
            routeSettings.arguments is int ? routeSettings.arguments as int : 0;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => HomeShellScreen(initialTabIndex: tabIndex),
        );

      case dashboard:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const HomeScreen(),
        );

      case buildings:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const BuildingsScreen(),
        );

      case buildingOverview:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const BuildingOverviewScreen(),
        );

      case creator:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const CreatorMappingScreen(),
        );

      case creatorEditor:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const CreatorEditorScreen(),
        );

      case creatorPreview:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const CreatorPreviewScreen(),
        );

      case creatorPublish:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const CreatorPublishScreen(),
        );

      case visitor:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const VisitorScreen(),
        );

      case map:
      case mapView:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const MapViewScreen(),
        );

      case navigation:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NavigationScreen(),
        );

      case aiAssistant:
      case aiChat:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AiChatScreen(),
        );

      case versionHistory:
      case versioning:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const VersionHistoryScreen(),
        );

      case profile:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const ProfileScreen(),
        );

      case settings:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SettingsScreen(),
        );

      default:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => InvalidRouteScreen(routeName: routeSettings.name),
        );
    }
  }
}
