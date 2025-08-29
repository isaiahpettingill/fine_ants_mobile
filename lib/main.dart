import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'src/pages/account_setup_page.dart';
import 'src/pages/home_page.dart';
import 'src/services/account_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appSupportDir = await getApplicationSupportDirectory();
  await AccountStore.initialize(appSupportDir.path);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    // Cache the load future so it isn't recreated on every build.
    _loadFuture = AccountStore.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    // Light pink theme (mostly white with a hint of red)
    const seed = Color(0xFFFFE4EC); // very light pink
    return MaterialApp(
      title: 'Fine Ants',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final hasAccount = AccountStore.instance.accounts.isNotEmpty;
          if (!hasAccount) {
            return const AccountSetupPage();
          }
          return HomePage(account: AccountStore.instance.accounts.first);
        },
      ),
    );
  }
}
