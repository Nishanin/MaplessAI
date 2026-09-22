import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MapLessApp(initialRoute: AppRouter.splash),
    ),
  );
}

/// Root Application Widget
/// Owner: Nishant (Complete Flutter UI/UX & Shell)
class MapLessApp extends StatelessWidget {
  final String initialRoute;

  const MapLessApp({
    super.key,
    this.initialRoute = AppRouter.home,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: AppRouter.navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
