import 'package:flutter/material.dart';
import 'package:wordless/wordlen/views/wordlen_screen.dart';

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordlES',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home:  const WordlenScreen(),
    );
  }
}
