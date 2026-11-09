// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Browsers enforce cross-origin rules, so probing an API before startup can
/// incorrectly report an offline state even when the page has internet access.
/// The browser's own network state prevents FastRide from being trapped on its
/// loading screen; individual API calls still report their genuine failures.
Future<bool> hasInternetConnection() async =>
    html.window.navigator.onLine == true;
