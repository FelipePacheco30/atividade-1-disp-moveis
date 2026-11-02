import 'package:flutter/material.dart';

import 'features/localizacoes/presentation/screens/tela_coleta.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localizações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF22594C)),
      home: const TelaColeta(),
    );
  }
}
