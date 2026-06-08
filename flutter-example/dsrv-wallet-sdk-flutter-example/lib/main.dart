import 'package:flutter/material.dart';

import 'screens/root_screen.dart';

void main() => runApp(const DSRVWalletExampleApp());

class DSRVWalletExampleApp extends StatelessWidget {
  const DSRVWalletExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSRV Wallet Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      home: const RootScreen(),
    );
  }
}
