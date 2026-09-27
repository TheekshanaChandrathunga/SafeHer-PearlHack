import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'root_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FirebaseService.instance.ensureSignedIn().timeout(const Duration(seconds: 8));
      await FirebaseService.instance.registerPushToken().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Continue to the demo UI when Firebase is not configured.
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RootShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110, height: 110,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.purple),
              child: const Icon(Icons.shield, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 20),
            const Text.rich(TextSpan(children: [
              TextSpan(text: 'Safe', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.purple2)),
              TextSpan(text: 'Her', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.magenta)),
            ])),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: AppColors.purple),
          ],
        ),
      ),
    );
  }
}
