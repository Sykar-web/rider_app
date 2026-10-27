import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/profile_photo.dart';
import '../../app/theme.dart';

class HomeServiceCarousel extends StatefulWidget {
  const HomeServiceCarousel({
    super.key,
    required this.onProfile,
    required this.onNotifications,
    required this.onService,
  });
  final VoidCallback onProfile, onNotifications;
  final void Function(String vehicle, bool delivery) onService;

  @override
  State<HomeServiceCarousel> createState() => _HomeServiceCarouselState();
}

class _HomeServiceCarouselState extends State<HomeServiceCarousel> {
  static const _slides = [
    (
      'car',
      false,
      'car',
      'Your everyday ride',
      'Travel comfortably, your way.',
    ),
    (
      'motorcycle',
      false,
      'local',
      'Beat the everyday rush',
      'Book a moto for your next trip.',
    ),
    (
      'tuktuk',
      false,
      'local',
      'Around town, together',
      'Find your next tuk-tuk ride.',
    ),
    (
      'bicycle',
      false,
      'local',
      'A lighter way to move',
      'Choose a bicycle for local journeys.',
    ),
    (
      'van',
      false,
      'van',
      'More room for everyone',
      'Vans for your group and luggage.',
    ),
    (
      'bus',
      false,
      'bus',
      'Your next journey awaits',
      'Choose a bus and reserve your seats.',
    ),
    (
      'motorcycle',
      true,
      'delivery',
      'Send it with FastRide',
      'Book a courier for your package.',
    ),
  ];
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted ||
          !_pages.hasClients ||
          _dragging ||
          !TickerMode.valuesOf(context).enabled ||
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context) ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _pages.animateToPage(
        (_index + 1) % _slides.length,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 260 + MediaQuery.paddingOf(context).top,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event is ScrollStartNotification && event.dragDetails != null) {
                _dragging = true;
              }
              if (event is ScrollEndNotification) _dragging = false;
              return false;
            },
            child: PageView.builder(
              key: const Key('home-service-slideshow'),
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                final slide = _slides[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/branding/service_${slide.$3}.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(.35, 0),
                      excludeFromSemantics: true,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.navy.withValues(alpha: .92),
                            AppColors.navy.withValues(alpha: .08),
                          ],
                          stops: const [0, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 70,
                      top: 76 + MediaQuery.paddingOf(context).top,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slide.$4,
                            maxLines: 2,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slide.$5,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                widget.onService(slide.$1, slide.$2),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.blueDeep,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            child: Text(
                              slide.$2
                                  ? 'Send a package →'
                                  : 'Book ${slide.$1 == 'motorcycle'
                                        ? 'a moto'
                                        : slide.$1 == 'bus'
                                        ? 'a bus'
                                        : slide.$1 == 'van'
                                        ? 'a van'
                                        : slide.$1 == 'bicycle'
                                        ? 'a bicycle'
                                        : slide.$1 == 'tuktuk'
                                        ? 'a tuk-tuk'
                                        : 'a car'} →',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 2,
            left: 8,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: widget.onProfile,
                    tooltip: 'Open profile',
                    icon: const ProfilePhoto(radius: 17),
                  ),
                  IconButton(
                    onPressed: widget.onNotifications,
                    tooltip: 'Notifications',
                    icon: const CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.blueDeep,
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 25,
            child: Row(
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Semantics(
                    label: 'Service slide ${i + 1} of ${_slides.length}',
                    selected: _index == i,
                    button: true,
                    child: GestureDetector(
                      onTap: () => _pages.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      ),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _index == i ? 18 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

