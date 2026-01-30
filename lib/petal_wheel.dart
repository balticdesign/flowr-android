import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class PetalWheel extends StatefulWidget {
  final String selectedKey;
  final bool isMinor;
  final bool useParallelLayout;
  final bool hapticsEnabled;
  final Function(String key, bool isMinor) onKeySelected;

  const PetalWheel({
    super.key,
    required this.selectedKey,
    required this.isMinor,
    this.useParallelLayout = false,
    this.hapticsEnabled = true,
    required this.onKeySelected,
  });

  // Circle of fifths order for MAJOR keys
  static const List<Map<String, dynamic>> majorKeys = [
    {'note': 'C', 'color': Color(0xFFE74C3C)},
    {'note': 'G', 'color': Color(0xFFE67E22)},
    {'note': 'D', 'color': Color(0xFFF39C12)},
    {'note': 'A', 'color': Color(0xFFF1C40F)},
    {'note': 'E', 'color': Color(0xFF2ECC71)},
    {'note': 'B', 'color': Color(0xFF1ABC9C)},
    {'note': 'F♯', 'color': Color(0xFF3498DB)},
    {'note': 'D♭', 'color': Color(0xFF5DADE2)},
    {'note': 'A♭', 'color': Color(0xFF9B59B6)},
    {'note': 'E♭', 'color': Color(0xFFAF7AC5)},
    {'note': 'B♭', 'color': Color(0xFFEC407A)},
    {'note': 'F', 'color': Color(0xFFEF5350)},
  ];

  // Relative minors - positioned under their relative major
  static const List<String> relativeMinors = [
    'A',   // relative minor of C
    'E',   // relative minor of G
    'B',   // relative minor of D
    'F♯',  // relative minor of A
    'C♯',  // relative minor of E
    'G♯',  // relative minor of B
    'D♯',  // relative minor of F♯
    'B♭',  // relative minor of D♭
    'F',   // relative minor of A♭
    'C',   // relative minor of E♭
    'G',   // relative minor of B♭
    'D',   // relative minor of F
  ];

  @override
  State<PetalWheel> createState() => _PetalWheelState();
}

class _PetalWheelState extends State<PetalWheel> {
  String? _lastSelectedKey;
  bool? _lastSelectedMinor;

  void _handleTouch(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Ignore touches too close to center
    if (distance < size * 0.05) return;

    // Calculate angle (0 = top, clockwise)
    var angle = math.atan2(dx, -dy) * 180 / math.pi;
    if (angle < 0) angle += 360;

    final petalIndex = ((angle + 15) / 30).floor() % 12;
    
    // Inner vs outer based on distance
    final innerOuterThreshold = size * 0.28;
    final tappedOuter = distance > innerOuterThreshold;
    
    String note;
    bool isMinor;
    
    if (widget.useParallelLayout) {
      // Parallel layout: outer = major, inner = minor version of same note
      note = PetalWheel.majorKeys[petalIndex]['note'] as String;
      isMinor = !tappedOuter;  // inner ring = minor
    } else {
      // True circle of 5ths: OUTER = major, INNER = relative minor
      if (tappedOuter) {
        note = PetalWheel.majorKeys[petalIndex]['note'] as String;
        isMinor = false;
      } else {
        note = PetalWheel.relativeMinors[petalIndex];
        isMinor = true;
      }
    }

    // Only update if changed
    if (note != _lastSelectedKey || isMinor != _lastSelectedMinor) {
      _lastSelectedKey = note;
      _lastSelectedMinor = isMinor;
      
      // Haptic feedback
      if (widget.hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }
      
      widget.onKeySelected(note, isMinor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: GestureDetector(
              onPanStart: (details) => _handleTouch(details.localPosition, size),
              onPanUpdate: (details) => _handleTouch(details.localPosition, size),
              onTapDown: (details) => _handleTouch(details.localPosition, size),
              child: Stack(
                children: [
                  for (int i = 0; i < 12; i++) ...[
                    // Outer petal (MAJOR in true CoF, MAJOR in parallel)
                    _buildPetal(
                      index: i,
                      size: size,
                      scale: 1.0,
                      isOuter: true,
                    ),
                    // Inner petal (RELATIVE MINOR in true CoF, MINOR in parallel)
                    _buildPetal(
                      index: i,
                      size: size,
                      scale: 0.6,
                      isOuter: false,
                    ),
                  ],
                  Center(
                    child: Container(
                      width: size * 0.15,
                      height: size * 0.15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.selectedKey}${widget.isMinor ? 'm' : ''}',
                          style: TextStyle(
                            fontSize: size * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPetal({
    required int index,
    required double size,
    required double scale,
    required bool isOuter,
  }) {
    final majorKeyData = PetalWheel.majorKeys[index];
    final color = majorKeyData['color'] as Color;
    final angle = index * 30.0;
    
    // Determine what this petal represents
    String petalNote;
    bool petalIsMinor;
    
    if (widget.useParallelLayout) {
      // Parallel: both rings use same note, inner is minor
      petalNote = majorKeyData['note'] as String;
      petalIsMinor = !isOuter;  // inner = minor
    } else {
      // True circle of 5ths: OUTER = major, INNER = relative minor
      if (isOuter) {
        petalNote = majorKeyData['note'] as String;
        petalIsMinor = false;
      } else {
        petalNote = PetalWheel.relativeMinors[index];
        petalIsMinor = true;
      }
    }
    
    final isSelected = widget.selectedKey == petalNote && widget.isMinor == petalIsMinor;

    final petalHeight = size * 0.42 * scale;
    final petalWidth = size * 0.13 * scale;

    final radians = (angle) * math.pi / 180;
    
    final distanceFromCenter = size * 0.08 + (petalHeight * 0.4);
    final offsetX = size / 2 + math.sin(radians) * distanceFromCenter - petalWidth / 2;
    final offsetY = size / 2 - math.cos(radians) * distanceFromCenter - petalHeight / 2;

    return Positioned(
      left: offsetX,
      top: offsetY,
      child: Transform.rotate(
        angle: radians,
        child: SizedBox(
          width: petalWidth,
          height: petalHeight,
          child: SvgPicture.asset(
            'assets/petal.svg',
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.white : color,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}