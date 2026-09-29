import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import 'hub_list_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });


  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}


class _LoginScreenState
    extends State<LoginScreen> {

  final ApiClient _api = ApiClient();

  final TextEditingController _usernameCtrl =
      TextEditingController();

  final TextEditingController _passwordCtrl =
      TextEditingController();


  bool _loading = false;

  String? _error;


  bool get _isArabic =>
      Localizations.localeOf(context).languageCode ==
      'ar';


  String _text(
    String ar,
    String en,
  ) {
    return _isArabic ? ar : en;
  }


  Future<void> _submit() async {
    final username =
        _usernameCtrl.text.trim();

    final password =
        _passwordCtrl.text;


    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = _text(
          'أدخل اسم المستخدم وكلمة المرور.',
          'Enter your username and password.',
        );
      });

      return;
    }


    setState(() {
      _loading = true;
      _error = null;
    });


    try {
      await _api.login(
        username,
        password,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              const HubListScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error
            .toString()
            .replaceFirst(
              'ApiException: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 32,
            ),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.balance,
                    size: 78,
                    color: AppColors.neonViolet,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _text(
                      'اتحاد طلبة كلية القانون',
                      'Law Faculty Student Union',
                    ),

                    textAlign: TextAlign.center,

                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _text(
                      'بوابة المجتمع الطلابي',
                      'Student community portal',
                    ),

                    textAlign: TextAlign.center,

                    style: const TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  TextField(
                    controller:
                        _usernameCtrl,

                    textInputAction:
                        TextInputAction.next,

                    autocorrect: false,

                    decoration:
                        InputDecoration(
                      hintText: _text(
                        'اسم المستخدم',
                        'Username',
                      ),

                      prefixIcon:
                          const Icon(
                        Icons.person_outline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller:
                        _passwordCtrl,

                    obscureText: true,

                    onSubmitted: (_) =>
                        _loading
                            ? null
                            : _submit(),

                    decoration:
                        InputDecoration(
                      hintText: _text(
                        'كلمة المرور',
                        'Password',
                      ),

                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(
                        12,
                      ),

                      decoration:
                          BoxDecoration(
                        color: Colors.red
                            .withOpacity(
                          0.10,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child: Text(
                        _error!,

                        textAlign:
                            TextAlign.center,

                        style:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width:
                        double.infinity,

                    child:
                        ElevatedButton(
                      onPressed:
                          _loading
                              ? null
                              : _submit,

                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : Text(
                              _text(
                                'دخول',
                                'Sign in',
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _text(
                      'العربية / English',
                      'العربية / English',
                    ),

                    style:
                        const TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
