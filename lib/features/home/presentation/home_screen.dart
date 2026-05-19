import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/di.dart';
import 'package:playspot/features/auth/data/repos/auth_repos.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await sl<AuthRepository>().signOut();
              if (context.mounted) {
                context.goNamed(RouterKeys.signIn);
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to PlaySpot!'),
      ),
    );
  }
}
