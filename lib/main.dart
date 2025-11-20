import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/elo_screen.dart';
import 'providers/app_provider.dart';
import 'themes/app_theme.dart';

class EloApp extends StatelessWidget {
  const EloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EloAppTheme.lightTheme;

    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: MaterialApp(
        title: 'Elo Rankings',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const HomeScreen(),
        routes: {
          '/elo': (context) => const EloScreen(),
          '/home': (context) => const HomeScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/elo':
              return MaterialPageRoute(builder: (_) => const EloScreen());
            default:
              return MaterialPageRoute(builder: (_) => const HomeScreen());
          }
        },
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style for better integration
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EloApp());
}
