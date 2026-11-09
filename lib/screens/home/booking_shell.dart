import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../profile/profile_screen.dart';
import '../account/customer_pages.dart';
import 'home_screen.dart';
import 'activity_screen.dart';

class BookingShell extends StatefulWidget {
  const BookingShell({super.key});
  @override
  State<BookingShell> createState() => _BookingShellState();
}

class _BookingShellState extends State<BookingShell> {
  int _index = 0, _revision = 0;
  final Set<int> _visited = {0};
  void _select(int index) => setState(() {
    _index = index;
    _visited.add(index);
    if (index == 1) _revision++;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _index,
      children: [
        TickerMode(
          enabled: _index == 0,
          child: HomeScreen(onProfile: () => _select(3)),
        ),
        if (_visited.contains(1))
          ActivityScreen(
            refreshRevision: _revision,
            onBookRide: () => _select(0),
          )
        else
          const SizedBox.shrink(),
        if (_visited.contains(2))
          const WalletScreen()
        else
          const SizedBox.shrink(),
        if (_visited.contains(3))
          const ProfileScreen()
        else
          const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );
}
