import 'package:firebase_auth/firebase_auth.dart';
import 'package:muzic/constants/assets_constants.dart';
import 'package:muzic/core/screen_names.dart';
import 'package:muzic/core/services/auth_services.dart';
import 'package:muzic/core/theme/app_pallete.dart';
import 'package:muzic/features/helper_widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Single entry point for both sign-in and account creation — no separate
/// "sign up" screen. See AuthService.signInOrSignUpWithEmail for how the
/// email/password box decides which case it is.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    final message = e is FirebaseAuthException ? (e.message ?? e.code) : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Pallete.errorColor));
  }

  Future<void> _continueWithEmail() async {
    try {
      final userCredential = await _authService.signInOrSignUpWithEmail(_emailController.text.trim(), _passwordController.text);
      if (!mounted) return;
      if (userCredential != null) {
        context.pushNamed(ScreenNames.mainScreen);
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _continueWithGoogle() async {
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (userCredential != null) {
        context.pushNamed(ScreenNames.mainScreen);
      }
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(AssetsConstants.appLogo, width: 140, height: 140, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Muzic',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Pallete.whiteColor, fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to start listening',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Pallete.subtitleText, fontSize: 18, fontFamily: 'HN', fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 56),

                // Google keeps its own white-background brand style — more
                // recognizable to users than forcing it into the dark theme.
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _continueWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Pallete.whiteColor,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(AssetsConstants.googleIconPng, width: 20, height: 20),
                        const SizedBox(width: 12),
                        const Text("Continue with Google", style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 36),
                Row(
                  children: [
                    Expanded(child: Divider(color: Pallete.borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "or",
                        style: TextStyle(color: Pallete.subtitleText, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Divider(color: Pallete.borderColor)),
                  ],
                ),
                const SizedBox(height: 36),

                CustomTextField(hintText: "Email", controller: _emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline),
                const SizedBox(height: 20),
                CustomTextField(hintText: "Password", controller: _passwordController, obscureText: true, prefixIcon: Icons.lock_outline),
                const SizedBox(height: 30),

                // Brand gradient (Pallete.gradient1/2/3) — defined for the
                // whole app but unused until now. This is the one primary
                // action on the screen, so it's the natural place for it.
                SizedBox(
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [Pallete.gradient1, Pallete.gradient2, Pallete.gradient3]),
                    ),
                    child: ElevatedButton(
                      onPressed: _continueWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Pallete.whiteColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
