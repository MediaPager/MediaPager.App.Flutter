import 'package:flutter/material.dart';

import 'services/server_store.dart';
import 'screens/connections_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ServerStore();
  await store.load();
  runApp(MediaPagerApp(store: store));
}

class MediaPagerApp extends StatelessWidget {
  const MediaPagerApp({super.key, required this.store});

  final ServerStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaPager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff45a8ff),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ConnectionsScreen(store: store),
    );
  }
}
