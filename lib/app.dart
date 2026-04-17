import 'package:flutter/material.dart';
import 'core/theme.dart';

class NivoApp extends StatelessWidget {
  const NivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nivo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Center(child: Text('Nivo App')),
      ),
    );
  }
}
