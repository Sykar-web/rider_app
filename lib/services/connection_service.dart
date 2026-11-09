import 'connection_probe_mobile.dart'
    if (dart.library.html) 'connection_probe_web.dart'
    as probe;

/// Checks that the device can actually reach the internet, rather than only
/// checking whether Wi-Fi or mobile data is switched on.
class ConnectionService {
  Future<bool> hasInternet() => probe.hasInternetConnection();
}
