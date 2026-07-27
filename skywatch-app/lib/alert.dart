// Alert Details Page - Enhanced with Professional Animations
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui';

// Full Screen Video Page with Controls
class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController videoController;

  const FullScreenVideoPage({super.key, required this.videoController});

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _controlsVisible = true;
  late AnimationController _fadeController;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.videoController.value.isPlaying;
    widget.videoController.addListener(_updatePlayState);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_controlsVisible && mounted) {
        setState(() {
          _controlsVisible = false;
          _fadeController.reverse();
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _fadeController.forward();
        _startHideControlsTimer();
      } else {
        _fadeController.reverse();
      }
    });
  }

  void _updatePlayState() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.videoController.value.isPlaying;
      });
    }
  }

  void _playPause() {
    setState(() {
      if (_isPlaying) {
        widget.videoController.pause();
      } else {
        widget.videoController.play();
      }
      _isPlaying = !_isPlaying;
    });
    _startHideControlsTimer();
  }

  void _replay() {
    widget.videoController.seekTo(Duration.zero);
    if (!_isPlaying) {
      widget.videoController.play();
      setState(() {
        _isPlaying = true;
      });
    }
    _startHideControlsTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _fadeController.dispose();
    widget.videoController.removeListener(_updatePlayState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: AspectRatio(
                aspectRatio: widget.videoController.value.aspectRatio,
                child: VideoPlayer(widget.videoController),
              ),
            ),
            
            // Controls Overlay
            FadeTransition(
              opacity: _fadeController,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.videocam,
                                      color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(
                                        widget.videoController.value.position),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  const Text(" / ",
                                      style: TextStyle(color: Colors.white70)),
                                  Text(
                                    _formatDuration(
                                        widget.videoController.value.duration),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Bottom Controls
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress Slider
                            Row(
                              children: [
                                Text(
                                  _formatDuration(widget
                                      .videoController.value.position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: widget.videoController.value.position
                                        .inSeconds
                                        .toDouble(),
                                    min: 0,
                                    max: widget.videoController.value.duration
                                        .inSeconds
                                        .toDouble(),
                                    activeColor: Colors.blueAccent,
                                    inactiveColor: Colors.white30,
                                    onChanged: (value) {
                                      widget.videoController.seekTo(
                                          Duration(seconds: value.toInt()));
                                      _startHideControlsTimer();
                                    },
                                  ),
                                ),
                                Text(
                                  _formatDuration(widget
                                      .videoController.value.duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildControlButton(
                                  icon: Icons.replay,
                                  onTap: _replay,
                                  size: 40,
                                ),
                                const SizedBox(width: 30),
                                _buildControlButton(
                                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                  onTap: _playPause,
                                  size: 56,
                                  isPrimary: true,
                                ),
                                const SizedBox(width: 30),
                                _buildControlButton(
                                  icon: Icons.close,
                                  onTap: () => Navigator.pop(context),
                                  size: 40,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Big Play Button (when paused)
            if (!_isPlaying && !_controlsVisible)
              Center(
                child: AnimatedScale(
                  scale: _controlsVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 40),
                      onPressed: _playPause,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.blueAccent
            : Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class AlertDetailsPage extends StatefulWidget {
  final Map<String, dynamic> alert;
  const AlertDetailsPage({super.key, required this.alert});

  @override
  State<AlertDetailsPage> createState() => _AlertDetailsPageState();
}

class _AlertDetailsPageState extends State<AlertDetailsPage>
    with TickerProviderStateMixin {
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Navigation related variables
  LatLng? _currentPosition;
  bool _isGettingLocation = false;
  Map<String, double>? _cachedCoords;

  // Video related variables
  String? _videoUrl;
  bool _isVideoLoading = true;
  bool _hasVideoError = false;
  final bool _isRetryingVideo = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Extract video URL from alert
    _extractVideoUrl();

    // Initialize video player with network URL
    _initializeVideoPlayer();

    _cachedCoords = _parseCoordinates();
    print("📊 Alert Details - Full alert data: ${widget.alert}");
    print("📊 Parsed coordinates: $_cachedCoords");
    print("📹 Video URL: $_videoUrl");
  }

  void _extractVideoUrl() {
    bool hasVideo = false;

    if (widget.alert.containsKey('has_video')) {
      hasVideo = widget.alert['has_video'] == true;
    }

    if (!hasVideo) {
      print("⚠️ Alert has no video (has_video: false)");
      _videoUrl = null;
      return;
    }

    if (widget.alert.containsKey('video_url') &&
        widget.alert['video_url'] != null) {
      String rawUrl = widget.alert['video_url'].toString();

      if (rawUrl.contains('cloudinary.com')) {
        rawUrl = rawUrl.replaceAll('/v1/', '/');
        if (rawUrl.contains('/upload/')) {
          _videoUrl = rawUrl.replaceFirst(
              '/upload/', '/upload/c_scale,h_360,w_640,f_mp4,q_auto/');
          print("✅ Fixed Cloudinary URL: $_videoUrl");
        } else {
          _videoUrl = rawUrl;
        }
      } else {
        _videoUrl = rawUrl;
      }
    } else if (widget.alert.containsKey('video') &&
        widget.alert['video'] is Map) {
      var videoObj = widget.alert['video'] as Map;
      if (videoObj.containsKey('url') && videoObj['url'] != null) {
        String rawUrl = videoObj['url'].toString();
        if (rawUrl.contains('cloudinary.com')) {
          rawUrl = rawUrl.replaceAll('/v1/', '/');
          if (rawUrl.contains('/upload/')) {
            _videoUrl = rawUrl.replaceFirst(
                '/upload/', '/upload/c_scale,h_360,w_640,f_mp4,q_auto/');
          } else {
            _videoUrl = rawUrl;
          }
        } else {
          _videoUrl = rawUrl;
        }
      }
    } else if (widget.alert.containsKey('video_public_id') &&
        widget.alert['video_public_id'] != null) {
      String publicId = widget.alert['video_public_id'].toString();
      publicId = publicId.replaceAll('v1773004379/', '');
      publicId = publicId.replaceAll('v1773004379', '');
      publicId = publicId.replaceAll('.mp4', '');
      publicId = publicId.replaceAll('.m3u8', '');
      _videoUrl =
          'https://res.cloudinary.com/dsnpjwaly/video/upload/c_scale,h_360,w_640,f_mp4,q_auto/$publicId.mp4';
    } else if (hasVideo && widget.alert.containsKey('id')) {
      String alertId = widget.alert['id'].toString();
      _videoUrl =
          'https://res.cloudinary.com/dsnpjwaly/video/upload/c_scale,h_360,w_640/iov_alerts/alert_$alertId.mp4';
    }
  }

  Future<bool> _isVideoUrlValid(String url) async {
    try {
      print("🔍 Checking video URL: $url");
      final response = await http.head(Uri.parse(url));
      bool isValid = response.statusCode >= 200 && response.statusCode < 400;
      print("📡 URL check result: ${response.statusCode} - ${isValid ? '✅ Valid' : '❌ Invalid'}");
      return isValid;
    } catch (e) {
      print("❌ Error checking video URL: $e");
      return false;
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoUrl == null || _videoUrl!.isEmpty) {
      print("⚠️ No video URL found");
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _isVideoLoading = false;
        });
      }
      return;
    }

    try {
      setState(() {
        _isVideoLoading = true;
        _hasVideoError = false;
      });

      print("🎥 Initializing network video player with: $_videoUrl");

      bool urlValid = await _isVideoUrlValid(_videoUrl!);
      if (!urlValid) {
        print("❌ Video URL is not accessible: $_videoUrl");
        await _tryFallbackUrls();
        return;
      }

      final controller = VideoPlayerController.network(
        _videoUrl!,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      _videoController = controller;

      controller.addListener(() {
        if (controller.value.hasError) {
          print("❌ Video player error: ${controller.value.errorDescription}");
          if (mounted) {
            setState(() {
              _hasVideoError = true;
              _isVideoLoading = false;
            });
          }
        }
      });

      await controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Video initialization timed out");
        },
      );

      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _hasVideoError = false;
        });
        print("✅ Network video player initialized successfully");
      }

      controller.addListener(() {
        if (!mounted) return;
        if (controller.value.isPlaying != _isVideoPlaying) {
          setState(() {
            _isVideoPlaying = controller.value.isPlaying;
          });
        }
        if (controller.value.position == controller.value.duration &&
            controller.value.isInitialized) {
          setState(() {
            _isVideoPlaying = false;
          });
        }
      });
    } catch (e) {
      print("❌ Error initializing network video player: $e");
      if (e.toString().contains('format') || e.toString().contains('codec')) {
        await _tryAlternativeFormat();
      } else if (e.toString().contains('network') || e.toString().contains('timeout')) {
        await _tryLowerQuality();
      } else {
        if (mounted) {
          setState(() {
            _hasVideoError = true;
            _isVideoLoading = false;
          });
        }
        _showVideoErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _tryFallbackUrls() async {
    if (_videoUrl == null) return;

    List<String> fallbackUrls = [
      _videoUrl!.replaceAll('c_scale,h_360,w_640', 'c_scale,h_240,w_320'),
      _videoUrl!.replaceAll('.mp4', '.webm'),
      _videoUrl!.replaceAll('c_scale,h_360,w_640,f_mp4,q_auto/', ''),
    ];

    for (String url in fallbackUrls) {
      print("🔄 Trying fallback URL: $url");
      bool isValid = await _isVideoUrlValid(url);
      if (isValid) {
        print("✅ Found working fallback URL: $url");
        _videoUrl = url;
        await _initializeVideoPlayer();
        return;
      }
    }

    if (mounted) {
      setState(() {
        _hasVideoError = true;
        _isVideoLoading = false;
      });
    }
  }

  Future<void> _tryAlternativeFormat() async {
    if (_videoUrl == null) return;

    String webmUrl = _videoUrl!.replaceAll('.mp4', '.webm');
    print("🔄 Trying WebM format: $webmUrl");
    
    try {
      final controller = VideoPlayerController.network(webmUrl);
      await controller.initialize().timeout(const Duration(seconds: 15));
      _videoController = controller;
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _hasVideoError = false;
        });
      }
      print("✅ WebM format initialized successfully");
    } catch (e) {
      print("❌ WebM format also failed: $e");
      await _tryLowerQuality();
    }
  }

  Future<void> _tryLowerQuality() async {
    if (_videoUrl == null) return;

    String lowQualityUrl = _videoUrl!.replaceAll('c_scale,h_360,w_640', 'c_scale,h_180,w_240');
    print("🔄 Trying lower quality: $lowQualityUrl");
    
    try {
      final controller = VideoPlayerController.network(lowQualityUrl);
      await controller.initialize().timeout(const Duration(seconds: 15));
      _videoController = controller;
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _hasVideoError = false;
        });
      }
      print("✅ Lower quality initialized successfully");
    } catch (e) {
      print("❌ Lower quality also failed: $e");
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _isVideoLoading = false;
        });
      }
      _showVideoErrorSnackBar("All video formats failed.");
    }
  }

  void _showVideoErrorSnackBar([String? errorDetails]) {
    String message = 'Video unavailable. The recording may still be processing.';
    
    if (errorDetails != null) {
      if (errorDetails.contains('404')) {
        message = 'Video not found. It may have been deleted.';
      } else if (errorDetails.contains('timed out')) {
        message = 'Video loading timed out. Check your connection.';
      } else if (errorDetails.contains('format') || errorDetails.contains('codec')) {
        message = 'Video format not supported. Trying alternatives...';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            if (mounted) {
              setState(() {
                _isVideoLoading = true;
                _hasVideoError = false;
              });
              _initializeVideoPlayer();
            }
          },
        ),
      ),
    );
  }

  void _showVideoInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Video Information',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              'URL: $_videoUrl',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 8),
            const Text(
              'The video may still be processing. Please try again in a few moments.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isVideoLoading = true;
                  _hasVideoError = false;
                });
                _initializeVideoPlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _playVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.play();
      setState(() => _isVideoPlaying = true);
    }
  }

  void _pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() => _isVideoPlaying = false);
    }
  }

  void _replayVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.seekTo(Duration.zero);
      if (!_videoController!.value.isPlaying) {
        _playVideo();
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String? _getVideoThumbnail() {
    if (widget.alert.containsKey('video_thumbnail') &&
        widget.alert['video_thumbnail'] != null) {
      return widget.alert['video_thumbnail'].toString();
    } else if (widget.alert.containsKey('video') &&
        widget.alert['video'] is Map) {
      var videoObj = widget.alert['video'] as Map;
      if (videoObj.containsKey('thumbnail') && videoObj['thumbnail'] != null) {
        return videoObj['thumbnail'].toString();
      }
    } else if (_videoUrl != null && _videoUrl!.contains('cloudinary')) {
      return _videoUrl!.replaceAll(RegExp(r'\.(mp4|webm|mov|m3u8)$'), '.jpg');
    }
    return null;
  }

  Color _getPriorityColor() {
    String priority = widget.alert['priority'] ?? 'Medium';
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Map<String, double>? _parseCoordinates() {
    try {
      print("🔍 Parsing coordinates from alert...");

      if (widget.alert.containsKey('coordinates')) {
        var coords = widget.alert['coordinates'];
        if (coords != null) {
          if (coords is Map) {
            double? lat = _toDouble(coords['lat']);
            double? lng = _toDouble(coords['lng']);
            if (lat != null && lng != null) {
              return {'lat': lat, 'lng': lng};
            }
          }
          if (coords is String) {
            return _parseStringCoordinates(coords);
          }
        }
      }

      if (widget.alert.containsKey('location')) {
        var loc = widget.alert['location'];
        if (loc != null && loc is Map) {
          double? lat = _toDouble(loc['lat']);
          double? lng = _toDouble(loc['lng']);
          if (lat != null && lng != null) {
            return {'lat': lat, 'lng': lng};
          }
        }
      }

      return null;
    } catch (e) {
      print("❌ Error parsing coordinates: $e");
      return null;
    }
  }

  Map<String, double>? _parseStringCoordinates(String str) {
    try {
      String clean = str.replaceAll('[', '').replaceAll(']', '').trim();
      if (clean.contains(',')) {
        List<String> parts = clean.split(',');
        if (parts.length >= 2) {
          double? lat = double.tryParse(parts[0].trim());
          double? lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            return {'lat': lat, 'lng': lng};
          }
        }
      }
    } catch (e) {
      print("Error parsing string coordinates: $e");
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    try {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) {
        String cleaned = value.trim().replaceAll(RegExp(r'[^\d.-]'), '');
        return double.tryParse(cleaned);
      }
      if (value is num) return value.toDouble();
    } catch (e) {
      print("Error converting to double: $value");
    }
    return null;
  }

  String _getLocationName() {
    if (widget.alert.containsKey('Area') && widget.alert['Area'] != null) {
      return widget.alert['Area'].toString();
    }
    if (widget.alert.containsKey('location') &&
        widget.alert['location'] is Map &&
        widget.alert['location']['address'] != null) {
      return widget.alert['location']['address'].toString();
    }
    if (widget.alert.containsKey('location') &&
        widget.alert['location'] is String) {
      return widget.alert['location'].toString();
    }
    if (widget.alert.containsKey('area') && widget.alert['area'] != null) {
      return widget.alert['area'].toString();
    }
    return 'Unknown location';
  }

  String _getCameraName() {
    if (widget.alert.containsKey('camera_name') &&
        widget.alert['camera_name'] != null) {
      return widget.alert['camera_name'].toString();
    }
    if (widget.alert.containsKey('camera_id') &&
        widget.alert['camera_id'] != null) {
      return 'CAM-${widget.alert['camera_id']}';
    }
    return 'CAM-001';
  }

  String _getReportedTime() {
    if (widget.alert.containsKey('time') && widget.alert['time'] != null) {
      return widget.alert['time'].toString();
    }
    if (widget.alert.containsKey('timestamp') &&
        widget.alert['timestamp'] != null) {
      try {
        int timestamp = widget.alert['timestamp'] is int
            ? widget.alert['timestamp']
            : int.tryParse(widget.alert['timestamp'].toString()) ?? 0;
        if (timestamp > 0) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        print("Error parsing timestamp: $e");
      }
    }
    return 'Just now';
  }

  String _getDescription() {
    if (widget.alert.containsKey('description') &&
        widget.alert['description'] != null) {
      return widget.alert['description'].toString();
    }
    String type = widget.alert['type']?.toString() ?? 'Unknown threat';
    String confidence = '';
    if (widget.alert.containsKey('confidence')) {
      var confidenceVal = widget.alert['confidence'];
      if (confidenceVal != null) {
        try {
          double conf = confidenceVal is double
              ? confidenceVal
              : double.tryParse(confidenceVal.toString()) ?? 0.0;
          if (conf > 0) {
            confidence = '${(conf * 100).toStringAsFixed(0)}% confidence';
          }
        } catch (e) {
          print("Error parsing confidence: $e");
        }
      }
    }
    if (confidence.isNotEmpty) {
      return '$type detected with $confidence. ${_getCameraName()} camera.';
    }
    return '$type detected by ${_getCameraName()} camera.';
  }

  String _getWeaponClass() {
    if (widget.alert.containsKey('weapon_class') &&
        widget.alert['weapon_class'] != null) {
      return widget.alert['weapon_class'].toString().toUpperCase();
    }
    if (widget.alert.containsKey('type') && widget.alert['type'] != null) {
      return widget.alert['type'].toString().toUpperCase();
    }
    return 'UNKNOWN';
  }

  String _getConfidenceText() {
    if (widget.alert.containsKey('confidence')) {
      var confidenceVal = widget.alert['confidence'];
      if (confidenceVal != null) {
        try {
          double conf = confidenceVal is double
              ? confidenceVal
              : double.tryParse(confidenceVal.toString()) ?? 0.0;
          if (conf > 0) {
            return '${(conf * 100).toStringAsFixed(1)}%';
          }
        } catch (e) {
          print("Error formatting confidence: $e");
        }
      }
    }
    return 'N/A';
  }

  String _getFrameCount() {
    if (widget.alert.containsKey('frame_count') &&
        widget.alert['frame_count'] != null) {
      return widget.alert['frame_count'].toString();
    }
    return '0';
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return Container(
        color: Colors.black45,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasVideoError) {
      return Container(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.red.shade300, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Video temporarily unavailable',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'The recording may still be processing',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isVideoLoading = true;
                        _hasVideoError = false;
                      });
                      _initializeVideoPlayer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _showVideoInfoDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Video player
          SizedBox(
            width: double.infinity,
            height: 180,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),

          // Gradient overlay for better control visibility
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),

          // Video controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: _videoController!.value.isPlaying
                        ? _pauseVideo
                        : _playVideo,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration
                  Text(
                    '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const Spacer(),
                  // Fullscreen button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenVideoPage(
                            videoController: _videoController!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Progress bar
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LinearProgressIndicator(
                value: _videoController!.value.position.inSeconds /
                    _videoController!.value.duration.inSeconds,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                minHeight: 2,
              ),
            ),
          ),

          // Big play button overlay (when paused)
          if (!_videoController!.value.isPlaying)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: _playVideo,
                  child: AnimatedScale(
                    scale: 1,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      color: Colors.black45,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.white38, size: 48),
            SizedBox(height: 8),
            Text(
              'Video not available',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNavigation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Please enable location services');
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied');
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied');
        setState(() => _isGettingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isGettingLocation = false;
      });

      _cachedCoords ??= _parseCoordinates();

      if (_cachedCoords == null) {
        _showErrorSnackBar('Alert location coordinates not found');
        return;
      }

      double destLat = _cachedCoords!['lat']!;
      double destLng = _cachedCoords!['lng']!;

      _launchGoogleMapsNavigation(
        position.latitude,
        position.longitude,
        destLat,
        destLng,
      );
    } catch (e) {
      _showErrorSnackBar('Error: $e');
      setState(() => _isGettingLocation = false);
    }
  }

  void _launchGoogleMapsNavigation(
    double currentLat,
    double currentLng,
    double destLat,
    double destLng,
  ) async {
    String googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
        "&origin=$currentLat,$currentLng"
        "&destination=$destLat,$destLng"
        "&travelmode=driving";

    try {
      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSuccessSnackBar('Opening Google Maps...');
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      _showErrorSnackBar('Error launching maps: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 16),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showAmbulanceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital,
                              color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Available Ambulance Services',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Location info
                  if (_cachedCoords != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_cachedCoords!['lat']?.toStringAsFixed(6)}°, ${_cachedCoords!['lng']?.toStringAsFixed(6)}°',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Available users list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: '1122')
                          .where('isAvailable', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade300, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading services',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_hospital_outlined,
                                    color: Colors.white38, size: 60),
                                const SizedBox(height: 16),
                                const Text(
                                  'No ambulance services available',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All services are currently busy',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    _showAllAmbulanceServices(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                        color: Colors.red.withOpacity(0.5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Show All Services'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var userDoc = snapshot.data!.docs[index];
                            var userData =
                                userDoc.data() as Map<String, dynamic>;

                            return _buildAmbulanceUserTile(
                              userId: userDoc.id,
                              userData: userData,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllAmbulanceServices(BuildContext context) {
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.local_hospital, color: Colors.red, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'All Ambulance Services',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: '1122')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.white)));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No ambulance services registered',
                                style: TextStyle(color: Colors.white70)),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var userDoc = snapshot.data!.docs[index];
                            var userData =
                                userDoc.data() as Map<String, dynamic>;
                            return _buildAmbulanceUserTile(
                              userId: userDoc.id,
                              userData: userData,
                              showAvailability: true,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAmbulanceUserTile({
    required String userId,
    required Map<String, dynamic> userData,
    bool showAvailability = false,
  }) {
    bool isAvailable = userData['isAvailable'] ?? true;
    String userName = userData['fullName'] ?? userData['name'] ?? 'Unknown Service';
    String? vehicleNumber = userData['vehicleNumber'];
    double? distance = userData['currentDistance'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (isAvailable ? Colors.red : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isAvailable ? Colors.red : Colors.grey).withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable
              ? () => _sendAlertToAmbulance(userId, userData)
              : () => _showUserInfo(userData),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isAvailable ? Colors.red : Colors.grey).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: isAvailable ? Colors.red : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showAvailability)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAvailable ? 'Available' : 'Busy',
                                style: TextStyle(
                                  color: isAvailable ? Colors.green : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (vehicleNumber != null && vehicleNumber.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.directions_bus,
                                color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              vehicleNumber,
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      if (distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.white38, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Action button
                if (isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: Colors.white38, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendAlertToAmbulance(
      String userId, Map<String, dynamic> userData) async {
    if (_cachedCoords == null) {
      _showErrorSnackBar('Alert location not available');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(color: Colors.red),
                ),
                SizedBox(height: 16),
                Text(
                  'Sending alert...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      Map<String, dynamic> ambulanceRequest = {
        'alertId': widget.alert['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'ambulanceUserId': userId,
        'ambulanceName': userData['fullName'] ?? userData['name'] ?? 'Unknown Service',
        'alertLocation': {
          'lat': _cachedCoords!['lat'],
          'lng': _cachedCoords!['lng'],
        },
        'alertLocationName': _getLocationName(),
        'alertDetails': {
          'type': widget.alert['type'] ?? 'Unknown',
          'priority': widget.alert['priority'] ?? 'Medium',
          'cameraName': _getCameraName(),
          'description': _getDescription(),
        },
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'videoUrl': _videoUrl,
      };

      if (_getVideoThumbnail() != null) {
        ambulanceRequest['videoThumbnail'] = _getVideoThumbnail();
      }

      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('ambulance_requests')
          .add(ambulanceRequest);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('assigned_alerts')
          .doc(docRef.id)
          .set({
        ...ambulanceRequest,
        'requestId': docRef.id,
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAvailable': false,
        'currentAssignment': docRef.id,
        'lastAssignedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(userData, docRef.id);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar('Failed to send alert: $e');
      print('Error sending ambulance alert: $e');
    }
  }

  void _showSuccessDialog(Map<String, dynamic> userData, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Alert Sent!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ambulance service notified:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              userData['fullName'] ?? userData['name'] ?? 'Ambulance Service',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            if (userData['vehicleNumber'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vehicle: ${userData['vehicleNumber']}',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The ambulance has been notified and will respond shortly.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close',
                style: TextStyle(color: Colors.blueAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _trackAmbulance(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Track Ambulance'),
          ),
        ],
      ),
    );
  }

  void _showUserInfo(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Service Information',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${userData['fullName'] ?? userData['name'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.white)),
            if (userData['contactNumber'] != null)
              Text('Contact: ${userData['contactNumber']}',
                  style: const TextStyle(color: Colors.white70)),
            if (userData['vehicleNumber'] != null)
              Text('Vehicle: ${userData['vehicleNumber']}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            const Text('Status: Currently busy',
                style: TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _trackAmbulance(String requestId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmbulanceTrackingPage(requestId: requestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    var coords = _cachedCoords ?? _parseCoordinates();

    if (_cachedCoords == null && coords != null) {
      _cachedCoords = coords;
    }

    String locationName = _getLocationName();
    String cameraName = _getCameraName();
    String reportedTime = _getReportedTime();
    String description = _getDescription();
    String confidenceText = _getConfidenceText();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: priorityColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: priorityColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.alert['type']?.toString().toUpperCase() ?? 'ALERT',
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
              onPressed: () {
                // Share functionality
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image with Blur
          Image.asset(
            'assets/log.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // Dark Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Blur Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Video Section
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.blueAccent
                                            .withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: _buildVideoPlayer(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Video info badge
                            if (_videoUrl != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.video_library,
                                        color: Colors.green, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Evidence video available',
                                      style: TextStyle(color: Colors.green, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Alert Info Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.03),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: priorityColor.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with info cards
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (confidenceText != 'N/A')
                                        _buildInfoCard(
                                          Icons.analytics,
                                          'Confidence',
                                          confidenceText,
                                        ),
                                      _buildInfoCard(
                                        Icons.location_on,
                                        'Area',
                                        locationName,
                                      ),
                                      _buildInfoCard(
                                        Icons.access_time,
                                        'Time',
                                        reportedTime,
                                      ),
                                      _buildInfoCard(
                                        Icons.videocam,
                                        'Camera',
                                        cameraName,
                                      ),
                                      _buildInfoCard(
                                        Icons.route,
                                        'Distance',
                                        widget.alert['distance'] ?? '0.5 km',
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Description
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.description,
                                                color: Colors.white54, size: 14),
                                            const SizedBox(width: 8),
                                            const Text('Description:',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 13),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Acknowledged status
                                  if (widget.alert.containsKey('acknowledged'))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: widget.alert[
                                                          'acknowledged'] ==
                                                      true
                                                  ? Colors.green
                                                      .withOpacity(0.2)
                                                  : Colors.orange
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Icon(
                                              widget.alert['acknowledged'] ==
                                                      true
                                                  ? Icons.check_circle
                                                  : Icons.pending,
                                              color: widget.alert[
                                                          'acknowledged'] ==
                                                      true
                                                  ? Colors.green
                                                  : Colors.orange,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            widget.alert['acknowledged'] == true
                                                ? 'Acknowledged'
                                                : 'Pending Acknowledgment',
                                            style: TextStyle(
                                              color: widget.alert[
                                                          'acknowledged'] ==
                                                      true
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Map Placeholder
                            GestureDetector(
                              onTap: coords != null ? _startNavigation : null,
                              child: Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: coords != null
                                        ? Colors.blueAccent.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: coords != null
                                          ? Colors.blueAccent.withOpacity(0.1)
                                          : Colors.transparent,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            coords != null
                                                ? Icons.map
                                                : Icons.location_off,
                                            color: coords != null
                                                ? Colors.blueAccent.withOpacity(0.5)
                                                : Colors.red.withOpacity(0.5),
                                            size: 40,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            coords != null
                                                ? 'Tap to Navigate'
                                                : 'Location not available',
                                            style: TextStyle(
                                              color: coords != null
                                                  ? Colors.white70
                                                  : Colors.red.shade200,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (coords != null)
                                            Flexible(
                                              child: Text(
                                                '${coords['lat']?.toStringAsFixed(4)}°, ${coords['lng']?.toStringAsFixed(4)}°',
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.red,
                                          Colors.redAccent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (coords != null &&
                                              !_isGettingLocation)
                                          ? _startNavigation
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: _isGettingLocation
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.navigation,
                                                    color: Colors.white,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text('Navigate',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14)),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [Colors.red, Colors.redAccent]),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _showAmbulanceOptions(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.local_hospital,
                                              color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text('Ambulance',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Info Card Widget - MOVED OUTSIDE BUILD METHOD
  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class AmbulanceTrackingPage extends StatelessWidget {
  final String requestId;

  const AmbulanceTrackingPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ambulance'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ambulance_requests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Request not found',
                  style: TextStyle(color: Colors.white)),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String status = data['status'] ?? 'pending';

          Map<String, dynamic> statusInfo = {
            'pending': {
              'icon': Icons.pending,
              'color': Colors.orange,
              'title': 'Pending',
              'message': 'Waiting for ambulance confirmation...',
            },
            'accepted': {
              'icon': Icons.check_circle,
              'color': Colors.blue,
              'title': 'Accepted',
              'message': 'Ambulance is preparing to depart...',
            },
            'enroute': {
              'icon': Icons.directions_car,
              'color': Colors.green,
              'title': 'En Route',
              'message': 'Ambulance is on the way!',
            },
            'arrived': {
              'icon': Icons.location_on,
              'color': Colors.green,
              'title': 'Arrived',
              'message': 'Ambulance has arrived at the location!',
            },
            'completed': {
              'icon': Icons.check_circle,
              'color': Colors.green,
              'title': 'Completed',
              'message': 'Service completed',
            },
          };

          var currentStatus = statusInfo[status] ?? statusInfo['pending'];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0A1A),
                  const Color(0xFF1A1A2E),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: (currentStatus['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentStatus['icon'] as IconData,
                        color: currentStatus['color'] as Color,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      currentStatus['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentStatus['message'] as String,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_hospital,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                data['ambulanceName'] ?? 'Ambulance',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (data['alertLocationName'] != null)
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['alertLocationName'],
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (status == 'enroute')
                      const CircularProgressIndicator(color: Colors.red),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}