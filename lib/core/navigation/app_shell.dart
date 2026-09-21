import 'package:flutter/material.dart';
import '../../features/gallery/presentation/home_screen.dart';
import '../../features/deletion/presentation/review_screen.dart';

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
      const Center(key: Key('settings-page'), child: Text('Settings')),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.delete_outline), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
