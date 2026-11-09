import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/connection_service.dart';

/// Prevents network-backed screens from loading until a connection is ready.
class ConnectionGate extends StatefulWidget {
  final Widget child;
  const ConnectionGate({super.key, required this.child});

  @override
  State<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<ConnectionGate> {
  final _connection = ConnectionService();
  bool? _online;
  Timer? _connectionTimer;
  bool _checking = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _checkConnection(silent: true),
    );
  }

  Future<void> _checkConnection({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() => _online = null);
    final online = await _connection.hasInternet();
    _checking = false;
    if (mounted) {
      setState(() {
        _online = online;
        _opened = _opened || online;
      });
    }
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_opened)
          Offstage(
            offstage: _online != true,
            child: TickerMode(enabled: _online == true, child: widget.child),
          ),
        if (_online != true)
          Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _online == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 18),
                          Text('Checking your connection…'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F3F7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.blueDeep,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Unable to connect',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Check Wi-Fi or mobile data and try again. The service may also be temporarily unavailable.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 26),
                          FilledButton.icon(
                            onPressed: _checkConnection,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
