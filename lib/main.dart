import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:localflix/src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(
    options: {
      'platforms': ['windows', 'linux'],
    },
  );
  runApp(const App());
}
