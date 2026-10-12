import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  Future<bool> _hasToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('api_token')?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(snapshot.data! ? '/areas' : '/login');
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({required this.child, super.key});

  Future<bool> _hasToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('api_token')?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.data!) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return child;
      },
    );
  }
}
