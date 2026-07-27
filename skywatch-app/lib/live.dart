import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class LiveRadarScreen extends StatefulWidget {
  const LiveRadarScreen({super.key});

  @override
  State<LiveRadarScreen> createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends State<LiveRadarScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _blipController;

  final List<RadarBlip> _blips = [];
  final List<Map<String, dynamic>> _liveAlerts = [
    {
      'title': 'Suspicious Movement',
      'location': 'Sector 7, Zone A',
      'time': 'Just now',
      'type': 'movement',
      'priority': 'high',
    },
    {
      'title': 'Vehicle Detected',
      'location': 'Checkpost 3',
      'time': '2 min ago',
      'type': 'vehicle',
      'priority': 'medium',
    },
    {
      'title': 'Theft Alert',
      'location': 'Building 42',
      'time': '5 min ago',
      'type': 'theft',
      'priority': 'high',
    },
    {
      'title': 'Temperature Spike',
      'location': 'Server Room',
      'time': '8 min ago',
      'type': 'fire',
      'priority': 'critical',
    },
    {
      'title': 'Unauthorized Access',
      'location': 'Gate 2',
      'time': '12 min ago',
      'type': 'security',
      'priority': 'medium',
    },
  ];

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Generate random radar blips
    _generateBlips();
  }

  void _generateBlips() {
    final random = math.Random();
    for (int i = 0; i < 8; i++) {
      _blips.add(
        RadarBlip(
          angle: random.nextDouble() * 2 * math.pi,
          distance: 0.2 + random.nextDouble() * 0.6,
          size: 4 + random.nextDouble() * 4,
          speed: 1 + random.nextDouble() * 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _blipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image with Blur
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/log.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: Text(
                              'Background image not found',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Back Button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Live Radar Surveillance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(
                                        0.5 + _pulseController.value * 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(
                                            0.3 + _pulseController.value * 0.3,
                                          ),
                                          blurRadius:
                                              5 + _pulseController.value * 5,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Radar Section
                    Container(
                      height: 350,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            // Radar Animation
                            AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: RadarPainter(
                                    radarValue: _radarController.value,
                                    pulseValue: _pulseController.value,
                                    blips: _blips,
                                    blipValue: _blipController.value,
                                  ),
                                  size: const Size(double.infinity, 350),
                                );
                              },
                            ),

                            // Center Logo
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.security,
                                    color: Colors.blueAccent,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),

                            // Radar Labels
                            Positioned(
                              bottom: 20,
                              left: 20,
                              child: Text(
                                'Range: 2km',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              right: 20,
                              child: Text(
                                '${_blips.length} targets',
                                style: TextStyle(
                                  color: Colors.greenAccent.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatsCard(
                            'Active Threats',
                            _liveAlerts
                                .where((a) => a['priority'] == 'high')
                                .length
                                .toString(),
                            Icons.warning,
                            Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatsCard(
                            'Tracked Objects',
                            _blips.length.toString(),
                            Icons.radar,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatsCard(
                            'Scanning',
                            '360°',
                            Icons.rotate_right,
                            Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Live Alerts Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Live Alerts Feed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_liveAlerts.length} new',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Live Alerts List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _liveAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _liveAlerts[index];
                        return _buildAlertItem(alert);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Control Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildControlButton(
                            'Zoom In',
                            Icons.zoom_in,
                            () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildControlButton(
                            'Zoom Out',
                            Icons.zoom_out,
                            () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Security Features
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildChip('Theft', Icons.shield),
                        const SizedBox(width: 8),
                        _buildChip('FighNerg', Icons.security),
                        const SizedBox(width: 8),
                        _buildChip('AI', Icons.auto_awesome),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    Color color;
    IconData icon;

    switch (alert['type']) {
      case 'movement':
        color = Colors.orange;
        icon = Icons.person_outline;
        break;
      case 'vehicle':
        color = Colors.blue;
        icon = Icons.directions_car;
        break;
      case 'theft':
        color = Colors.red;
        icon = Icons.lock_outline;
        break;
      case 'fire':
        color = Colors.deepOrange;
        icon = Icons.whatshot;
        break;
      default:
        color = Colors.purple;
        icon = Icons.security;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: alert['priority'] == 'critical'
              ? Colors.red.withOpacity(0.5)
              : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white.withOpacity(0.3),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      alert['location'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withOpacity(0.3),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      alert['time'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: alert['priority'] == 'critical'
                  ? Colors.red
                  : alert['priority'] == 'high'
                  ? Colors.orange
                  : Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      (alert['priority'] == 'critical'
                              ? Colors.red
                              : alert['priority'] == 'high'
                              ? Colors.orange
                              : Colors.blue)
                          .withOpacity(0.5),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback onTap) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: MaterialButton(
        onPressed: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class RadarBlip {
  final double angle;
  final double distance;
  final double size;
  final double speed;

  RadarBlip({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
  });
}

class RadarPainter extends CustomPainter {
  final double radarValue;
  final double pulseValue;
  final List<RadarBlip> blips;
  final double blipValue;

  RadarPainter({
    required this.radarValue,
    required this.pulseValue,
    required this.blips,
    required this.blipValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw radar circles
    final circlePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, circlePaint);
    }

    // Draw cross lines
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      circlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      circlePaint,
    );

    // Draw rotating radar line
    final radarPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final angle = radarValue * 2 * math.pi;
    final lineEnd = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas.drawLine(center, lineEnd, radarPaint);

    // Draw radar sweep (semi-transparent triangle)
    final sweepPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final sweepPath = Path();
    sweepPath.moveTo(center.dx, center.dy);
    sweepPath.lineTo(
      center.dx + math.cos(angle - 0.3) * radius,
      center.dy + math.sin(angle - 0.3) * radius,
    );
    sweepPath.lineTo(
      center.dx + math.cos(angle + 0.3) * radius,
      center.dy + math.sin(angle + 0.3) * radius,
    );
    sweepPath.close();
    canvas.drawPath(sweepPath, sweepPaint);

    // Draw radar blips
    for (var blip in blips) {
      final blipAngle = blip.angle + blipValue * blip.speed;
      final distance = blip.distance * radius;
      final x = center.dx + math.cos(blipAngle) * distance;
      final y = center.dy + math.sin(blipAngle) * distance;

      // Blip glow
      final glowPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.3 + pulseValue * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(Offset(x, y), blip.size + 2, glowPaint);

      // Blip core
      final blipPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.8 + pulseValue * 0.2);

      canvas.drawCircle(Offset(x, y), blip.size, blipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
