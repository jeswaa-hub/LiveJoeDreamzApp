import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/network/network_status_service.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class NetworkStatusBanner extends StatefulWidget {
  final Widget child;

  const NetworkStatusBanner({super.key, required this.child});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  bool _showBanner = false;
  bool _isOnline = true;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    NetworkStatusService.instance.isOnlineNotifier.addListener(_onNetworkChange);
  }

  void _onNetworkChange() {
    final online = NetworkStatusService.instance.isOnlineNotifier.value;
    if (!mounted) return;

    if (!online) {
      _dismissTimer?.cancel();
      setState(() {
        _isOnline = false;
        _showBanner = true;
      });
      _animController.forward();
    } else if (NetworkStatusService.instance.wasOffline) {
      // Just reconnected!
      setState(() {
        _isOnline = true;
        _showBanner = true;
      });
      _animController.forward();

      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) setState(() => _showBanner = false);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    NetworkStatusService.instance.isOnlineNotifier.removeListener(_onNetworkChange);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizeTransition(
              sizeFactor: _slideAnimation,
              alignment: Alignment.topCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isOnline
                        ? [
                            const Color(0xFF00E676).withValues(alpha: 0.95),
                            const Color(0xFF00B0FF).withValues(alpha: 0.95),
                          ]
                        : [
                            const Color(0xFFFF5252).withValues(alpha: 0.95),
                            const Color(0xFFFF7A00).withValues(alpha: 0.95),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isOnline ? const Color(0xFF00E676) : const Color(0xFFFF5252))
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline
                            ? 'Back Online · Synced with JoeDreamz'
                            : 'No Connection · Reconnecting to server...',
                        style: AppColors.geistBold(11).copyWith(
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
