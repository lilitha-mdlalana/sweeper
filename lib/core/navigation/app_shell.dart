import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/gallery/presentation/home_screen.dart';
import '../../features/deletion/presentation/deletion_providers.dart';
import '../../features/deletion/presentation/review_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goToReview() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onReviewDeletions: _goToReview),
      const ReviewScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final count = ref.watch(deletionQueueProvider).length;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Home'),
              NavigationDestination(
                icon: count > 0
                    ? Badge(label: Text('$count'), child: const Icon(Icons.delete_outline))
                    : const Icon(Icons.delete_outline),
                label: 'Review',
              ),
              const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          );
        },
      ),
    );
  }
}
