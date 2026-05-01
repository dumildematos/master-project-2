import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ble_provider.dart';
import 'providers/sentio_provider.dart';
import 'screens/onboarding_screen.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SentioRoot());
}

class SentioRoot extends StatelessWidget {
  const SentioRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BleProvider>(
          create: (_) => BleProvider(),
        ),
        ChangeNotifierProvider<SentioProvider>(
          create: (_) => SentioProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'SENTIO',
        debugShowCheckedModeBanner: false,
        theme: SentioTheme.dark(),
        home: const OnboardingScreen(),
      ),
    );
  }
}