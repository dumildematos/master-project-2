import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/sentio_provider.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart'; // LogoWidget (static, no animation)
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart' hide LogoWidget;
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SentioRoot());
}

class SentioRoot extends StatelessWidget {
  const SentioRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<BleProvider>(create: (_) => BleProvider()),
        ChangeNotifierProvider<SentioProvider>(create: (_) => SentioProvider()),
        ChangeNotifierProvider<SessionProvider>(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'SENTIO',
        debugShowCheckedModeBanner: false,
        theme: SentioTheme.dark(),
        home: const _RootNavigator(),
      ),
    );
  }
}

// Watches AuthProvider and renders the correct root screen.
class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  @override
  void initState() {
    super.initState();
    // Kick off session check after the first frame so the provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) return const _LoadingSplash();
    if (auth.isAuthenticated) return const MainShell();
    return const OnboardingScreen();
  }
}

// Minimal branded loading screen shown while the session check runs.
class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF02080D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoWidget(size: 88),
            SizedBox(height: 36),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Color(0xFF00D9FF),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
