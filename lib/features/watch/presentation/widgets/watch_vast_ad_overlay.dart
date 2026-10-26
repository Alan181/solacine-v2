import 'dart:async';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ads/application/vast_ad_service.dart';

class WatchVastAdOverlay extends StatefulWidget {
  const WatchVastAdOverlay({
    super.key,
    required this.adData,
    this.onFinished,
    this.onAdClosed,
  });

  final VastAdData adData;
  final VoidCallback? onFinished;
  final ValueChanged<bool>? onAdClosed;

  @override
  State<WatchVastAdOverlay> createState() => _WatchVastAdOverlayState();
}

class _WatchVastAdOverlayState extends State<WatchVastAdOverlay> {
  BetterPlayerController? _betterPlayerController;
  Timer? _ticker;
  Timer? _safetyTimeout;
  late int _remainingSkipSeconds;
  bool _canSkip = false;
  bool _muted = false;
  bool _finished = false;
  bool _loadFailed = false;
  bool _isInitialized = false;
  final Set<String> _firedPings = <String>{};

  @override
  void initState() {
    super.initState();
    _remainingSkipSeconds = widget.adData.skipSeconds;
    _canSkip = _remainingSkipSeconds <= 0;

    // 1. Start skip timer immediately
    _startSkipTimer();

    // 2. Safety timeout: if ad video fails to load within 8 seconds, dismiss safely
    _safetyTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted || _finished) return;
      if (!_isInitialized) {
        debugPrint('[WatchVastAdOverlay] Safety timeout triggered: ad video took too long to load');
        setState(() => _loadFailed = true);
        _finishAd(completed: false);
      }
    });

    // 3. Initialize BetterPlayer for VAST ad
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final cleanUrl = widget.adData.mediaUrl.trim();
      if (cleanUrl.isEmpty) {
        _finishAd(completed: false);
        return;
      }

      final betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 9 / 16,
        fit: BoxFit.cover,
        autoPlay: true,
        looping: false,
        muted: _muted,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // Custom controls handled by overlay
        ),
        eventsListener: (event) {
          if (!mounted) return;
          
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            setState(() {
              _isInitialized = true;
            });
            // Fire impression & start tracking
            if (!_firedPings.contains('start')) {
              _firedPings.add('start');
              VastAdService.sendPings(widget.adData.impressions);
              final startUrls = widget.adData.trackingEvents['start'];
              if (startUrls != null) VastAdService.sendPings(startUrls);
            }
          }

          if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
            if (!_finished) {
              if (!_firedPings.contains('complete')) {
                _firedPings.add('complete');
                final completeUrls = widget.adData.trackingEvents['complete'];
                if (completeUrls != null) VastAdService.sendPings(completeUrls);
              }
              _finishAd(completed: true);
            }
          }

          if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
            final position = _betterPlayerController?.videoPlayerController?.value.position;
            final duration = _betterPlayerController?.videoPlayerController?.value.duration;
            if (position != null && duration != null && duration > Duration.zero) {
              _handleTrackingProgress(position, duration);
            }
          }
        },
      );

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        cleanUrl,
        videoFormat: BetterPlayerVideoFormat.hls,
      );

      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      await _betterPlayerController?.setupDataSource(dataSource);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[WatchVastAdOverlay] Failed to initialize video: $e');
      if (mounted && !_finished) {
        setState(() => _loadFailed = true);
        _finishAd(completed: false);
      }
    }
  }

  void _handleTrackingProgress(Duration pos, Duration dur) {
    final progress = pos.inMilliseconds / dur.inMilliseconds;
    if (progress >= 0.25 && !_firedPings.contains('firstQuartile')) {
      _firedPings.add('firstQuartile');
      final urls = widget.adData.trackingEvents['firstquartile'];
      if (urls != null) VastAdService.sendPings(urls);
    }
    if (progress >= 0.50 && !_firedPings.contains('midpoint')) {
      _firedPings.add('midpoint');
      final urls = widget.adData.trackingEvents['midpoint'];
      if (urls != null) VastAdService.sendPings(urls);
    }
    if (progress >= 0.75 && !_firedPings.contains('thirdQuartile')) {
      _firedPings.add('thirdQuartile');
      final urls = widget.adData.trackingEvents['thirdquartile'];
      if (urls != null) VastAdService.sendPings(urls);
    }
  }

  void _startSkipTimer() {
    _ticker?.cancel();
    if (_canSkip) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      if (_remainingSkipSeconds > 1) {
        setState(() => _remainingSkipSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _remainingSkipSeconds = 0;
          _canSkip = true;
        });
      }
    });
  }

  void _finishAd({bool completed = false}) {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    _safetyTimeout?.cancel();
    try {
      _betterPlayerController?.pause();
      _betterPlayerController?.dispose();
    } catch (_) {}
    _betterPlayerController = null;
    widget.onFinished?.call();
    widget.onAdClosed?.call(completed);
  }

  void _onSkipPressed() {
    if (!_canSkip && !_loadFailed) return;
    if (!_firedPings.contains('skip')) {
      _firedPings.add('skip');
      final skipUrls = widget.adData.trackingEvents['skip'];
      if (skipUrls != null) VastAdService.sendPings(skipUrls);
    }
    _finishAd(completed: false);
  }

  Future<void> _onClickThrough() async {
    final raw = widget.adData.clickThroughUrl.trim();
    if (raw.isEmpty) return;
    VastAdService.sendPings(widget.adData.clickTrackingUrls);
    try {
      final uri = Uri.parse(raw);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[WatchVastAdOverlay] Failed to launch clickthrough: $e');
    }
  }

  void _toggleMute() {
    final controller = _betterPlayerController;
    if (controller == null) return;
    setState(() {
      _muted = !_muted;
      controller.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _safetyTimeout?.cancel();
    try {
      _betterPlayerController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _betterPlayerController;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ad Video Player using BetterPlayer
          if (_isInitialized && controller != null)
            Positioned.fill(
              child: BetterPlayer(controller: controller),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.amber,
              ),
            ),

          // Top Bar (AD badge + Remaining timer + Mute button)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isInitialized && controller != null)
                  Builder(
                    builder: (context) {
                      final pos = controller.videoPlayerController?.value.position ?? Duration.zero;
                      final total = controller.videoPlayerController?.value.duration ?? Duration.zero;
                      final remaining = total > pos ? total - pos : Duration.zero;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Text(
                          _formatDuration(remaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar (Click-Through Learn More + Skip Ad button)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                if (widget.adData.clickThroughUrl.isNotEmpty)
                  GestureDetector(
                    onTap: _onClickThrough,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Learn More',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: (_canSkip || _loadFailed) ? _onSkipPressed : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_canSkip || _loadFailed) ? Colors.black87 : Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_canSkip || _loadFailed) ? Colors.white70 : Colors.white24,
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (_canSkip || _loadFailed) ? 'Skip Ad' : 'Skip in ${_remainingSkipSeconds}s',
                          style: TextStyle(
                            color: (_canSkip || _loadFailed) ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_canSkip || _loadFailed) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
