import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'theme.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const LawUnionApp(),
  );
}


class LawUnionApp extends StatelessWidget {
  const LawUnionApp({
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Law Faculty Student Union',

      debugShowCheckedModeBanner: false,

      theme: buildAppTheme(),

      locale: const Locale('ar'),

      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      localeResolutionCallback: (
        locale,
        supportedLocales,
      ) {
        if (locale == null) {
          return const Locale('ar');
        }

        for (final supported in supportedLocales) {
          if (supported.languageCode ==
              locale.languageCode) {
            return supported;
          }
        }

        return const Locale('ar');
      },

      builder: (
        context,
        child,
      ) {
        final locale = Localizations.localeOf(
          context,
        );

        final isArabic =
            locale.languageCode == 'ar';

        return Directionality(
          textDirection: isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const LoginScreen(),
    );
  }
}
