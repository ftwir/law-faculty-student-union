import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'theme.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

Future<void> _loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('language_code');
  if (code == 'en' || code == 'ar') appLocale.value = Locale(code!);
}

Future<void> setAppLocale(Locale locale) async {
  if (locale.languageCode != 'ar' && locale.languageCode != 'en') return;
  appLocale.value = locale;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language_code', locale.languageCode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadSavedLocale();
  runApp(const LawUnionApp());
}

class LawUnionApp extends StatelessWidget {
  const LawUnionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        final isArabic = locale.languageCode == 'ar';
        return MaterialApp(
          title: 'Law Faculty Student Union',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (deviceLocale != null) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == deviceLocale.languageCode) return supported;
              }
            }
            return const Locale('ar');
          },
          builder: (context, child) => Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}
