import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:muzic/constants/assets_constants.dart';
import 'package:muzic/constants/theme_constants.dart';
import 'package:muzic/core/screen_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    // Wait for splash animation
    await Future.delayed(const Duration(milliseconds: 1000));
    // Check if the widget is still mounted (good practice)
    if (!mounted) return;
    // FirebaseAuth persists the signed-in session on-device already — no
    // SharedPreferences needed. currentUser is non-null here if Firebase
    // still has a valid persisted session from a previous launch.
    final alreadySignedIn = FirebaseAuth.instance.currentUser != null;
    context.goNamed(alreadySignedIn ? ScreenNames.mainScreen : ScreenNames.loginScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: ThemeConstants.foregroundColor,
          image: DecorationImage(image: AssetImage(AssetsConstants.splashLogo)),
        ),
      ),
    );
  }
}
