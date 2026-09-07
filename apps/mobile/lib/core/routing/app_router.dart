import 'package:flutter/material.dart';
import '../../features/mapping/presentation/screens/ai_chat_screen.dart';
import '../../features/mapping/presentation/screens/creator_mapping_screen.dart';
import '../../features/mapping/presentation/screens/home_screen.dart';
import '../../features/mapping/presentation/screens/map_view_screen.dart';
import '../../features/mapping/presentation/screens/navigation_screen.dart';
import '../../features/mapping/presentation/screens/version_history_screen.dart';

/// Centralized Router
/// Owner: Nishant (Presentation Shell)
abstract final class AppRouter {
  static const String home = '/';
  static const String mapView = '/map-view';
  static const String creator = '/creator';
  static const String navigation = '/navigation';
  static const String aiChat = '/ai-chat';
  static const String versioning = '/versioning';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case mapView:
        return MaterialPageRoute(builder: (_) => const MapViewScreen());
      case creator:
        return MaterialPageRoute(builder: (_) => const CreatorMappingScreen());
      case navigation:
        return MaterialPageRoute(builder: (_) => const NavigationScreen());
      case aiChat:
        return MaterialPageRoute(builder: (_) => const AiChatScreen());
      case versioning:
        return MaterialPageRoute(builder: (_) => const VersionHistoryScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
