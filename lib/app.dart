import 'package:flutter/material.dart';
import 'package:jv/src/screens/sales_screen.dart';
import 'package:provider/provider.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/machine_provider.dart';
import 'src/screens/splash_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/device_setup_screen.dart';
import 'src/screens/history_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MachineProvider()),
      ],
      child: MaterialApp(
        title: 'Edge Feeder',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/dashboard': (_) => const DashboardScreen(),
          '/device-setup': (_) => const DeviceSetupScreen(),
          '/history': (_) => const HistoryScreen(),
          '/sales': (_) => const SalesScreen(),

        },
      ),
    );
  }
}
