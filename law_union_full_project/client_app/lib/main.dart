import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() {
  runApp(const LawUnionApp());
}

class LawUnionApp extends StatelessWidget {
  const LawUnionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إتحاد طلبة كلية القانون',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const LoginScreen(),
    );
  }
}
