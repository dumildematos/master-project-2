import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ble_provider.dart';
import 'providers/sentio_provider.dart';
import 'app.dart';
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
        ChangeNotifierProvider(create: (_) => BleProvider()),
        ChangeNotifierProvider(create: (_) => SentioProvider()),
      ],
      child: MaterialApp(
        title:         'Sentio',
        theme:         sentioTheme,
        debugShowCheckedModeBanner: false,
        home:          const SentioApp(),
      ),
    );
  }
}
