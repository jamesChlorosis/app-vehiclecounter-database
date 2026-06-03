import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.bootstrap();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const QuarryGateApp(),
    ),
  );
}
