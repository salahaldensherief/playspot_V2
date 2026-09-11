import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper widget to compose multiple [BlocProvider]s at the ShellRoute level.
class AppProviderScope extends StatelessWidget {
  final List<dynamic> providers;
  final Widget child;

  const AppProviderScope({
    super.key,
    required this.providers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers.cast(),
      child: child,
    );
  }
}
