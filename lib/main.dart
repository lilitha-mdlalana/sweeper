import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_shell.dart';
import 'features/settings/presentation/permission_screen.dart';
import 'features/settings/presentation/permission_providers.dart';
import 'features/settings/presentation/privacy_screen.dart';

void main() {
  runApp(const ProviderScope(child: SweepApp()));
}

class SweepApp extends ConsumerWidget {
  const SweepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionStatusProvider);

    return MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: permission.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, StackTrace stackTrace) =>
            const Scaffold(body: Center(child: Text('Something went wrong.'))),
        data: (state) {
          switch (state) {
            case PermissionState.granted:
              return const AppShell();
            case PermissionState.permanentlyDenied:
              return PermissionScreen(
                permanentlyDenied: true,
                onAllowPressed: () =>
                    ref.read(permissionStatusProvider.notifier).openSettings(),
                onPrivacyPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              );
            case PermissionState.unknown:
            case PermissionState.denied:
              return PermissionScreen(
                onAllowPressed: () =>
                    ref.read(permissionStatusProvider.notifier).request(),
                onPrivacyPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              );
          }
        },
      ),
    );
  }
}
