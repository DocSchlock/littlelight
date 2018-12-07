import 'package:flutter/material.dart';
import 'package:little_light/screens/initial.screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(new LittleLight());

class LittleLight extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        backgroundColor: Colors.blueGrey.shade900,
        primarySwatch: Colors.lightBlue,
        primaryColor: Colors.lightBlue,
        brightness: Brightness.dark,
      ),
      home: new InitialScreen(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'), // English
        const Locale('fr'), // French
        const Locale('es'), // Spanish
        const Locale('de'), // German
        const Locale('it'), // Italian
        const Locale('ja'), // Japan
        const Locale('pt', 'BR'), // Brazillian Portuguese
        const Locale('es', 'MX'), // Mexican Spanish
        const Locale('ru'), // Russian
        const Locale('pl'), // Polish
        const Locale('ko'), // Korean
        const Locale('zh-cht'), // Chinese
      ],
    );
  }
}