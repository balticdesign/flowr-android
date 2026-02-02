import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;
import 'petal_wheel.dart';
import 'midi_service.dart';

// v2.0 imports
import 'models/models.dart';
import 'services/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const PetalsApp());
  });
}

class PetalsApp extends StatelessWidget {
  const PetalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      ),
      home: const PetalsHome(),
    );
  }
}

class PetalsHome extends StatefulWidget {
  const PetalsHome({super.key});

  @override
  State<PetalsHome> createState() => _PetalsHomeState();
}

class _PetalsHomeState extends State<PetalsHome> {
  // === V1.0 STATE (Explorer/Parallel modes) ===
  String _selectedKey = 'C';
  bool _isMinor = false;
  
  // === V2.0 STATE (Songwriter mode) ===
  late final FlowrState _flowrState;
  
  // === SHARED STATE ===
  bool _showSettings = false;
  bool _showMidiDebug = false;
  bool _showMidiTooltip = false;
  bool _hapticsEnabled = true;
  
  // Play mode: 'songwriter' (v2.0), 'explorer' (v1.0 circle of 5ths), 'parallel' (v1.0 parallel)
  String _playMode = 'explorer';  // Default to v1.0 for backwards compatibility
  
  // XY Pad CC assignments
  int _xAxisCC = 1;
  int _yAxisCC = 74;
  
  // Gyroscope settings
  bool _gyroEnabled = false;
  int _gyroXCC = 16;
  int _gyroYCC = 17;
  int _gyroZCC = 18;
  
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  final MidiService _midiService = MidiService();
  
  // MIDI output mode
  MidiOutputMode _midiOutputMode = MidiOutputMode.apps;
  
  final List<String> _midiLog = [];
  static const int _maxLogEntries = 5;

  // v1.0 button colors and chord types
  final List<Color> _buttonColors = [
    const Color(0xFF8B0A50),
    const Color(0xFFDC143C),
    const Color(0xFFFF6B35),
    const Color(0xFFFFEB00),
    const Color(0xFF32CD32),
    const Color(0xFF008B8B),
    const Color(0xFF0047AB),
    const Color(0xFF4169E1),
    const Color(0xFFDA70D6),
  ];

  final List<Map<String, dynamic>> _chordTypes = [
    {'label': 'sus2', 'suffix': 'sus2', 'intervals': [0, 2, 7]},
    {'label': 'sus4', 'suffix': 'sus4', 'intervals': [0, 5, 7]},
    {'label': 'add9', 'suffix': 'add9', 'intervals': [0, 4, 7, 14]},
    {'label': 'maj7', 'suffix': 'maj7', 'intervals': [0, 4, 7, 11]},
    {'label': '', 'suffix': '', 'intervals': [0, 4, 7]},
    {'label': 'm(add9)', 'suffix': 'm(add9)', 'intervals': [0, 3, 7, 14]},
    {'label': '7', 'suffix': '7', 'intervals': [0, 4, 7, 10]},
    {'label': '9', 'suffix': '9', 'intervals': [0, 4, 7, 10, 14]},
    {'label': 'm7', 'suffix': 'm7', 'intervals': [0, 3, 7, 10]},
  ];

  static const List<Map<String, dynamic>> ccOptions = [
    {'value': 1, 'label': '1 - Mod Wheel'},
    {'value': 2, 'label': '2 - Breath'},
    {'value': 7, 'label': '7 - Volume'},
    {'value': 10, 'label': '10 - Pan'},
    {'value': 11, 'label': '11 - Expression'},
    {'value': 16, 'label': '16 - GP 1'},
    {'value': 17, 'label': '17 - GP 2'},
    {'value': 18, 'label': '18 - GP 3'},
    {'value': 19, 'label': '19 - GP 4'},
    {'value': 71, 'label': '71 - Resonance'},
    {'value': 74, 'label': '74 - Cutoff'},
    {'value': 75, 'label': '75 - GP 6'},
    {'value': 76, 'label': '76 - GP 7'},
    {'value': 77, 'label': '77 - GP 8'},
    {'value': 91, 'label': '91 - Reverb'},
    {'value': 93, 'label': '93 - Chorus'},
  ];

  @override
  void initState() {
    super.initState();
    _initFlowrState();
    _initMidi();
  }
  
  void _initFlowrState() {
    _flowrState = FlowrState();
    
    // Wire up MIDI output
    _flowrState.onMidiNote = (note, velocity, noteOn) {
      if (noteOn) {
        _midiService.sendNoteOn(note, velocity);
      } else {
        _midiService.sendNoteOff(note);
      }
    };
    
    _flowrState.onMidiCC = (cc, value) {
      _midiService.sendCC(cc, value);
    };
    
    // Listen for state changes
    _flowrState.addListener(_onFlowrStateChanged);
  }
  
  void _onFlowrStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initMidi() async {
    await _checkMidiConnection();
    setState(() {});
  }

  @override
  void dispose() {
    _flowrState.removeListener(_onFlowrStateChanged);
    _gyroSubscription?.cancel();
    _midiService.dispose();
    super.dispose();
  }

  void _toggleGyroscope(bool enabled) {
    setState(() {
      _gyroEnabled = enabled;
    });
    
    if (enabled) {
      _startGyroscope();
    } else {
      _stopGyroscope();
    }
  }

  void _startGyroscope() {
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((GyroscopeEvent event) {
      final xCC = _gyroToCC(event.x);
      final yCC = _gyroToCC(event.y);
      final zCC = _gyroToCC(event.z);
      
      _midiService.sendCC(_gyroXCC, xCC);
      _midiService.sendCC(_gyroYCC, yCC);
      _midiService.sendCC(_gyroZCC, zCC);
    });
  }

  void _stopGyroscope() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
  }

  int _gyroToCC(double value) {
    const maxRadPerSec = 5.0;
    final normalized = (value / maxRadPerSec).clamp(-1.0, 1.0);
    return ((normalized + 1) * 63.5).round().clamp(0, 127);
  }

  Future<void> _checkMidiConnection() async {
    await _midiService.checkConnection();
    setState(() {});
  }

  void _onMidiTap() async {
    await _checkMidiConnection();
    setState(() {
      _showMidiTooltip = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showMidiTooltip = false;
        });
      }
    });
  }

  String _getMidiStatusText() {
    return _midiService.connectionStatusText;
  }
  
  void _setMidiOutputMode(MidiOutputMode mode) {
    setState(() {
      _midiOutputMode = mode;
      _midiService.setOutputMode(mode);
    });
  }

  void _logMidi(String message) {
    setState(() {
      _midiLog.insert(0, message);
      if (_midiLog.length > _maxLogEntries) {
        _midiLog.removeLast();
      }
    });
  }

  // v1.0 chord note calculation
  int _noteToMidi(String note) {
    const noteMap = {
      'C': 60, 'D': 62, 'E': 64, 'F': 65, 'G': 67, 'A': 69, 'B': 71,
      'C♯': 61, 'D♭': 61, 'D♯': 63, 'E♭': 63, 'F♯': 66, 
      'G♯': 68, 'A♭': 68, 'A♯': 70, 'B♭': 70,
    };
    return noteMap[note] ?? 60;
  }

  List<int> _getChordNotes(List<int> baseIntervals) {
    final rootNote = _noteToMidi(_selectedKey);
    List<int> intervals = List.from(baseIntervals);
    if (_isMinor) {
      intervals = intervals.map((i) => i == 4 ? 3 : i).toList();
    }
    return intervals.map((i) => rootNote + i).toList();
  }

  String _getChordName(int index) {
    final suffix = _chordTypes[index]['suffix'] as String;
    final base = '$_selectedKey${_isMinor ? 'm' : ''}';
    return suffix.isEmpty ? base : '$base $suffix';
  }

  void _openSettings() {
    setState(() {
      _showSettings = true;
    });
  }

  void _closeSettings() {
    setState(() {
      _showSettings = false;
    });
  }
  
  void _setPlayMode(String mode) {
    setState(() {
      _playMode = mode;
    });
    
    // Panic to release any held notes when switching modes
    _flowrState.panic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content - switch based on play mode
          _playMode == 'songwriter' 
              ? _buildSongwriterMode()
              : _buildExplorerMode(),
          
          // Settings icon
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _openSettings,
                child: SvgPicture.asset(
                  'assets/settings.svg',
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    Colors.grey,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),

          // FLOWR logo (top-left)
          Positioned(
            top: 10,
            left: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('F', style: GoogleFonts.syncopate(color: const Color(0xFFBF0000), fontSize: 14, fontWeight: FontWeight.w400)),
                const SizedBox(width: 6),
                Text('L', style: GoogleFonts.syncopate(color: const Color(0xFFFF7C00), fontSize: 14, fontWeight: FontWeight.w400)),
                const SizedBox(width: 6),
                Text('O', style: GoogleFonts.syncopate(color: const Color(0xFFD9FF00), fontSize: 14, fontWeight: FontWeight.w400)),
                const SizedBox(width: 6),
                Text('W', style: GoogleFonts.syncopate(color: const Color(0xFF008A6D), fontSize: 14, fontWeight: FontWeight.w400)),
                const SizedBox(width: 6),
                Text('R', style: GoogleFonts.syncopate(color: const Color(0xFFD57CFF), fontSize: 14, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          
          // Mode indicator (bottom-left, above GYRO if present)
          Positioned(
            bottom: _gyroEnabled ? 38 : 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _playMode == 'songwriter' 
                    ? Colors.purple.withOpacity(0.8)
                    : Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _playMode == 'songwriter' 
                    ? 'SONGWRITER' 
                    : _playMode == 'parallel' ? 'PARALLEL' : 'EXPLORER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // MIDI indicator
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: _showMidiTooltip ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _midiService.isConnected 
                            ? Colors.green.withOpacity(0.9)
                            : Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getMidiStatusText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _onMidiTap,
                    child: SvgPicture.asset(
                      'assets/midi_connected.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        _midiService.isConnected ? Colors.green : Colors.grey,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Gyro indicator (bottom-left)
          if (_gyroEnabled)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.white, size: 11),
                    SizedBox(width: 3),
                    Text(
                      'GYRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Debug overlay
          if (_showMidiDebug)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MIDI Debug:',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._midiLog.map((msg) => Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    )),
                    if (_midiLog.isEmpty)
                      const Text(
                        'No messages yet',
                        style: TextStyle(color: Color(0xFF66BB6A), fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          
          // Settings overlay
          if (_showSettings)
            SettingsOverlay(
              showMidiDebug: _showMidiDebug,
              playMode: _playMode,
              midiOutputMode: _midiOutputMode,
              hapticsEnabled: _hapticsEnabled,
              xAxisCC: _xAxisCC,
              yAxisCC: _yAxisCC,
              gyroEnabled: _gyroEnabled,
              gyroXCC: _gyroXCC,
              gyroYCC: _gyroYCC,
              gyroZCC: _gyroZCC,
              ccOptions: ccOptions,
              onMidiDebugChanged: (value) {
                setState(() {
                  _showMidiDebug = value;
                });
              },
              onPlayModeChanged: _setPlayMode,
              onMidiOutputModeChanged: _setMidiOutputMode,
              onHapticsChanged: (value) {
                setState(() {
                  _hapticsEnabled = value;
                });
                if (value) {
                  HapticFeedback.mediumImpact();
                }
              },
              onXAxisCCChanged: (value) {
                setState(() {
                  _xAxisCC = value;
                });
              },
              onYAxisCCChanged: (value) {
                setState(() {
                  _yAxisCC = value;
                });
              },
              onGyroEnabledChanged: _toggleGyroscope,
              onGyroXCCChanged: (value) {
                setState(() {
                  _gyroXCC = value;
                });
              },
              onGyroYCCChanged: (value) {
                setState(() {
                  _gyroYCC = value;
                });
              },
              onGyroZCCChanged: (value) {
                setState(() {
                  _gyroZCC = value;
                });
              },
              onClose: _closeSettings,
            ),
        ],
      ),
    );
  }
  
  // === V1.0 EXPLORER/PARALLEL MODE ===
  Widget _buildExplorerMode() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: PetalWheel(
                selectedKey: _selectedKey,
                isMinor: _isMinor,
                useParallelLayout: _playMode == 'parallel',
                hapticsEnabled: _hapticsEnabled,
                onKeySelected: (key, minor) {
                  setState(() {
                    _selectedKey = key;
                    _isMinor = minor;
                  });
                  _logMidi('KEY: $key${minor ? 'm' : ''}');
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ChordButtonGrid(
              buttonColors: _buttonColors,
              chordTypes: _chordTypes,
              selectedKey: _selectedKey,
              isMinor: _isMinor,
              getChordNotes: _getChordNotes,
              getChordName: _getChordName,
              midiService: _midiService,
              logMidi: _logMidi,
              xAxisCC: _xAxisCC,
              yAxisCC: _yAxisCC,
            ),
          ),
        ),
      ],
    );
  }
  
  // === V2.0 SONGWRITER MODE ===
  Widget _buildSongwriterMode() {
    return Row(
      children: [
        // Petal wheel for chord type selection
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: SongwriterPetalWheel(
                flowrState: _flowrState,
                hapticsEnabled: _hapticsEnabled,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Degree pads
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SongwriterPadGrid(
              flowrState: _flowrState,
              midiService: _midiService,
              xAxisCC: _xAxisCC,
              yAxisCC: _yAxisCC,
              hapticsEnabled: _hapticsEnabled,
              logMidi: _logMidi,
            ),
          ),
        ),
      ],
    );
  }
}

// ============== SONGWRITER PETAL WHEEL (v2.0) ==============
// Uses the same beautiful SVG petals as Explorer mode, but for chord type selection

class SongwriterPetalWheel extends StatefulWidget {
  final FlowrState flowrState;
  final bool hapticsEnabled;

  const SongwriterPetalWheel({
    super.key,
    required this.flowrState,
    this.hapticsEnabled = true,
  });

  // Rainbow colors matching the existing wheel
  static const List<Color> petalColors = [
    Color(0xFFE74C3C),   // 0: Major - Red
    Color(0xFFE67E22),   // 1: Maj7 - Orange  
    Color(0xFFF39C12),   // 2: Maj9 - Yellow-Orange
    Color(0xFFF1C40F),   // 3: Add9 - Yellow
    Color(0xFF2ECC71),   // 4: 6 - Green
    Color(0xFF1ABC9C),   // 5: Sus2 - Teal
    Color(0xFF3498DB),   // 6: m7 - Blue
    Color(0xFF5DADE2),   // 7: m9 - Light Blue
    Color(0xFF9B59B6),   // 8: Sus4 - Purple
    Color(0xFFAF7AC5),   // 9: Dom7 (7) - Light Purple
    Color(0xFFEC407A),   // 10: Dim - Pink
    Color(0xFFEF5350),   // 11: Aug - Red-Pink
  ];
  
  // Labels for each petal position (matching ChordRecipes.petalOrder)
  static const List<String> petalLabels = [
    'Maj', 'maj7', 'maj9', 'add9', '6', 'sus2',
    'm7', 'm9', 'sus4', '7', 'dim', 'aug',
  ];

  @override
  State<SongwriterPetalWheel> createState() => _SongwriterPetalWheelState();
}

class _SongwriterPetalWheelState extends State<SongwriterPetalWheel> {
  int? _lastPetalIndex;
  bool? _lastIsOuter;

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
    final isOuter = distance > innerOuterThreshold;

    // Check if petal changed
    if (_lastPetalIndex != petalIndex || _lastIsOuter != isOuter) {
      _lastPetalIndex = petalIndex;
      _lastIsOuter = isOuter;
      
      if (widget.hapticsEnabled) {
        HapticFeedback.lightImpact();
      }
      
      final ring = isOuter ? PetalRing.outer : PetalRing.inner;
      final petal = PetalLayout.getPetal(ring, petalIndex);
      
      if (widget.flowrState.functionHeld) {
        // Key selection mode - use chromatic order
        final newKey = MusicalKeys.byPetalChromatic(petalIndex, inner: !isOuter);
        widget.flowrState.setKey(newKey);
      } else {
        // Chord type override
        widget.flowrState.onPetalDown(petal);
      }
    }
  }

  void _handleTouchEnd() {
    _lastPetalIndex = null;
    _lastIsOuter = null;
    if (!widget.flowrState.functionHeld) {
      widget.flowrState.onPetalUp();
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
              onPanEnd: (_) => _handleTouchEnd(),
              onTapDown: (details) => _handleTouch(details.localPosition, size),
              onTapUp: (_) => _handleTouchEnd(),
              onTapCancel: _handleTouchEnd,
              child: Stack(
                children: [
                  // Draw all 24 petals using SVG
                  for (int i = 0; i < 12; i++) ...[
                    // Outer petal
                    _buildPetal(
                      index: i,
                      size: size,
                      scale: 1.0,
                      isOuter: true,
                    ),
                    // Inner petal
                    _buildPetal(
                      index: i,
                      size: size,
                      scale: 0.6,
                      isOuter: false,
                    ),
                  ],
                  // Center circle with current key
                  Center(
                    child: Container(
                      width: size * 0.15,
                      height: size * 0.15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: widget.flowrState.functionHeld 
                              ? Colors.orange 
                              : Colors.white24, 
                          width: widget.flowrState.functionHeld ? 3 : 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.flowrState.currentKey.name,
                          style: TextStyle(
                            fontSize: size * 0.04,
                            fontWeight: FontWeight.bold,
                            color: widget.flowrState.functionHeld 
                                ? Colors.orange 
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chord type labels on outer petals
                  for (int i = 0; i < 12; i++)
                    _buildPetalLabel(i, size),
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
    final color = SongwriterPetalWheel.petalColors[index];
    final angle = index * 30.0;
    
    // Check if this petal is active
    final activePetal = widget.flowrState.activePetal;
    final isActive = activePetal != null &&
        activePetal.index == index &&
        ((isOuter && activePetal.ring == PetalRing.outer) ||
         (!isOuter && activePetal.ring == PetalRing.inner));

    final petalHeight = size * 0.42 * scale;
    final petalWidth = size * 0.13 * scale;

    final radians = angle * math.pi / 180;
    
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
              isActive ? Colors.white : color,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPetalLabel(int index, double size) {
    final label = SongwriterPetalWheel.petalLabels[index];
    final angle = index * 30.0;
    final radians = angle * math.pi / 180;
    
    // Position label on outer petal area
    final labelDistance = size * 0.38;
    final offsetX = size / 2 + math.sin(radians) * labelDistance;
    final offsetY = size / 2 - math.cos(radians) * labelDistance;
    
    // Check if active
    final activePetal = widget.flowrState.activePetal;
    final isActive = activePetal != null && activePetal.index == index;

    return Positioned(
      left: offsetX - 20,
      top: offsetY - 8,
      child: SizedBox(
        width: 40,
        height: 16,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ============== SONGWRITER PAD GRID (v2.0) ==============

class SongwriterPadGrid extends StatelessWidget {
  final FlowrState flowrState;
  final MidiService midiService;
  final int xAxisCC;
  final int yAxisCC;
  final bool hapticsEnabled;
  final Function(String) logMidi;

  const SongwriterPadGrid({
    super.key,
    required this.flowrState,
    required this.midiService,
    required this.xAxisCC,
    required this.yAxisCC,
    this.hapticsEnabled = true,
    required this.logMidi,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: row == 0 ? 0 : 6,
                bottom: row == 2 ? 0 : 6,
              ),
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: col == 0 ? 0 : 6,
                          right: col == 2 ? 0 : 6,
                        ),
                        child: SongwriterPad(
                          key: ValueKey('pad_${row * 3 + col}'),
                          index: row * 3 + col,
                          flowrState: flowrState,
                          midiService: midiService,
                          xAxisCC: xAxisCC,
                          yAxisCC: yAxisCC,
                          hapticsEnabled: hapticsEnabled,
                          logMidi: logMidi,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SongwriterPad extends StatefulWidget {
  final int index;
  final FlowrState flowrState;
  final MidiService midiService;
  final int xAxisCC;
  final int yAxisCC;
  final bool hapticsEnabled;
  final Function(String) logMidi;

  const SongwriterPad({
    super.key,
    required this.index,
    required this.flowrState,
    required this.midiService,
    required this.xAxisCC,
    required this.yAxisCC,
    this.hapticsEnabled = true,
    required this.logMidi,
  });

  @override
  State<SongwriterPad> createState() => _SongwriterPadState();
}

class _SongwriterPadState extends State<SongwriterPad> {
  bool get _isActive => widget.flowrState.activePadIndex == widget.index;
  bool _sustainHeld = false;  // Local state for sustain pedal
  
  PadConfig get _padConfig => PadLayout.getPad(widget.index);
  
  String get _label {
    final pad = _padConfig;
    
    if (pad.type == PadType.function) {
      return widget.flowrState.functionHeld ? 'KEY' : 'FUNC';
    } else if (pad.type == PadType.sustain) {
      return _sustainHeld ? 'SUS ●' : 'SUS';
    } else if (pad.degree != null) {
      // Show chord name
      final chord = widget.flowrState.currentChord;
      if (_isActive && chord != null) {
        return chord.name;
      }
      // Show diatonic chord name for this degree
      final key = widget.flowrState.currentKey;
      final degree = pad.degree!.number;
      final root = key.degreeRoot(degree);
      final recipe = key.diatonicRecipe(degree);
      final rootName = _pitchClassName(root);
      return '$rootName${recipe.symbol}';
    }
    return '';
  }
  
  String _pitchClassName(int pitchClass) {
    const names = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
    return names[pitchClass % 12];
  }
  
  Color get _color {
    final pad = _padConfig;
    
    if (pad.type == PadType.function) {
      return _isActive ? Colors.orange : Colors.orange.shade900;
    } else if (pad.type == PadType.sustain) {
      return _sustainHeld 
          ? Colors.purple 
          : Colors.purple.shade900;
    } else {
      // Degree pad - use colour based on degree
      final degreeColors = [
        const Color(0xFF32CD32),  // I - Green (tonic)
        const Color(0xFF4169E1),  // ii - Blue
        const Color(0xFF9B59B6),  // iii - Purple
        const Color(0xFFFFEB00),  // IV - Yellow
        const Color(0xFFE74C3C),  // V - Red (dominant)
        const Color(0xFF008B8B),  // vi - Teal
        const Color(0xFFEC407A),  // vii° - Pink
      ];
      final degree = pad.degree?.number ?? 1;
      final baseColor = degreeColors[(degree - 1) % 7];
      return _isActive ? baseColor : baseColor.withOpacity(0.6);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    
    final pad = _padConfig;
    
    // Handle sustain pad specially - send MIDI CC64
    if (pad.type == PadType.sustain) {
      setState(() => _sustainHeld = true);
      widget.midiService.sendSustainOn();
      widget.logMidi('SUSTAIN ON');
      return;
    }
    
    widget.flowrState.onPadDown(widget.index);
    
    final chord = widget.flowrState.currentChord;
    if (chord != null) {
      widget.logMidi('ON: ${chord.name}');
    }
    
    _sendCC(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Only send CC for degree pads
    if (_padConfig.type == PadType.degree) {
      _sendCC(details.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _release();
  }

  void _onPanCancel() {
    _release();
  }

  void _sendCC(Offset localPosition) {
    if (_padConfig.type != PadType.degree) return;
    
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;

    final ccX = (localPosition.dx / size.width * 127).clamp(0, 127).toInt();
    final ccY = (127 - (localPosition.dy / size.height * 127)).clamp(0, 127).toInt();

    widget.midiService.sendCC(widget.xAxisCC, ccX);
    widget.midiService.sendCC(widget.yAxisCC, ccY);
  }

  void _release() {
    final pad = _padConfig;
    
    // Handle sustain pad specially
    if (pad.type == PadType.sustain) {
      setState(() => _sustainHeld = false);
      widget.midiService.sendSustainOff();
      widget.logMidi('SUSTAIN OFF');
      return;
    }
    
    final chord = widget.flowrState.currentChord;
    widget.flowrState.onPadUp(widget.index);
    
    if (chord != null && pad.type == PadType.degree) {
      widget.logMidi('OFF: ${chord.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // For sustain pad, use local _sustainHeld state for visual
    final isVisuallyActive = _padConfig.type == PadType.sustain 
        ? _sustainHeld 
        : _isActive;
        
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: CustomPaint(
        painter: ButtonPainter(
          index: widget.index,
          color: _color,
          isFilled: isVisuallyActive,
        ),
        child: Center(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isActive ? Colors.white : _color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ============== SETTINGS OVERLAY ==============

class SettingsOverlay extends StatefulWidget {
  final bool showMidiDebug;
  final String playMode;
  final MidiOutputMode midiOutputMode;
  final bool hapticsEnabled;
  final int xAxisCC;
  final int yAxisCC;
  final bool gyroEnabled;
  final int gyroXCC;
  final int gyroYCC;
  final int gyroZCC;
  final List<Map<String, dynamic>> ccOptions;
  final Function(bool) onMidiDebugChanged;
  final Function(String) onPlayModeChanged;
  final Function(MidiOutputMode) onMidiOutputModeChanged;
  final Function(bool) onHapticsChanged;
  final Function(int) onXAxisCCChanged;
  final Function(int) onYAxisCCChanged;
  final Function(bool) onGyroEnabledChanged;
  final Function(int) onGyroXCCChanged;
  final Function(int) onGyroYCCChanged;
  final Function(int) onGyroZCCChanged;
  final VoidCallback onClose;

  const SettingsOverlay({
    super.key,
    required this.showMidiDebug,
    required this.playMode,
    required this.midiOutputMode,
    required this.hapticsEnabled,
    required this.xAxisCC,
    required this.yAxisCC,
    required this.gyroEnabled,
    required this.gyroXCC,
    required this.gyroYCC,
    required this.gyroZCC,
    required this.ccOptions,
    required this.onMidiDebugChanged,
    required this.onPlayModeChanged,
    required this.onMidiOutputModeChanged,
    required this.onHapticsChanged,
    required this.onXAxisCCChanged,
    required this.onYAxisCCChanged,
    required this.onGyroEnabledChanged,
    required this.onGyroXCCChanged,
    required this.onGyroYCCChanged,
    required this.onGyroZCCChanged,
    required this.onClose,
  });

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  bool _showAbout = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: _showAbout 
            ? AboutModal(onClose: () => setState(() => _showAbout = false))
            : _buildSettingsPanel(),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return GestureDetector(
      onTap: () {}, // Prevent tap-through
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FLOWR logo at top
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showAbout = true),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('F', style: GoogleFonts.syncopate(color: const Color(0xFFBF0000), fontSize: 22, fontWeight: FontWeight.w400)),
                        const SizedBox(width: 12),
                        Text('L', style: GoogleFonts.syncopate(color: const Color(0xFFFF7C00), fontSize: 22, fontWeight: FontWeight.w400)),
                        const SizedBox(width: 12),
                        Text('O', style: GoogleFonts.syncopate(color: const Color(0xFFD9FF00), fontSize: 22, fontWeight: FontWeight.w400)),
                        const SizedBox(width: 12),
                        Text('W', style: GoogleFonts.syncopate(color: const Color(0xFF008A6D), fontSize: 22, fontWeight: FontWeight.w400)),
                        const SizedBox(width: 12),
                        Text('R', style: GoogleFonts.syncopate(color: const Color(0xFFD57CFF), fontSize: 22, fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // === PLAY MODE SECTION ===
              const Text(
                'Play Mode',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildPlayModeSelector(),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              
              // === MIDI OUTPUT SECTION ===
              const Text(
                'MIDI Output',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildMidiOutputSelector(),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              
              // === XY PAD SECTION ===
              const Text(
                'XY Pad',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildCCDropdown(
                label: 'X Axis CC',
                value: widget.xAxisCC,
                onChanged: widget.onXAxisCCChanged,
              ),
              const SizedBox(height: 8),
              
              _buildCCDropdown(
                label: 'Y Axis CC',
                value: widget.yAxisCC,
                onChanged: widget.onYAxisCCChanged,
              ),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              
              // === GYROSCOPE SECTION ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gyroscope',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: widget.gyroEnabled,
                    onChanged: widget.onGyroEnabledChanged,
                    activeColor: Colors.purple,
                  ),
                ],
              ),
              
              if (widget.gyroEnabled) ...[
                const SizedBox(height: 12),
                _buildCCDropdown(
                  label: 'Tilt X (Roll)',
                  value: widget.gyroXCC,
                  onChanged: widget.onGyroXCCChanged,
                ),
                const SizedBox(height: 8),
                _buildCCDropdown(
                  label: 'Tilt Y (Pitch)',
                  value: widget.gyroYCC,
                  onChanged: widget.onGyroYCCChanged,
                ),
                const SizedBox(height: 8),
                _buildCCDropdown(
                  label: 'Tilt Z (Yaw)',
                  value: widget.gyroZCC,
                  onChanged: widget.onGyroZCCChanged,
                ),
              ],
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              
              // === GENERAL SECTION ===
              const Text(
                'General',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildToggleRow(
                label: 'Haptic Feedback',
                value: widget.hapticsEnabled,
                onChanged: widget.onHapticsChanged,
              ),
              const SizedBox(height: 8),
              
              _buildToggleRow(
                label: 'MIDI Debug Panel',
                value: widget.showMidiDebug,
                onChanged: widget.onMidiDebugChanged,
              ),
              const SizedBox(height: 8),
              
              // About link
              GestureDetector(
                onTap: () => setState(() => _showAbout = true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'About',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlayModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildModeButton('songwriter', 'Songwriter', 'Pads = degrees'),
          _buildModeButton('explorer', 'Explorer', 'Circle of 5ths'),
          _buildModeButton('parallel', 'Parallel', 'Major/minor'),
        ],
      ),
    );
  }
  
  Widget _buildModeButton(String mode, String label, String subtitle) {
    final isSelected = widget.playMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onPlayModeChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected 
                ? Border.all(color: Colors.purple, width: 1)
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.white54 : Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMidiOutputSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildMidiOutputButton(MidiOutputMode.apps, 'Apps / PC', 'Default mode'),
          _buildMidiOutputButton(MidiOutputMode.external, 'Hardware', 'OTG to synth'),
        ],
      ),
    );
  }
  
  Widget _buildMidiOutputButton(MidiOutputMode mode, String label, String subtitle) {
    final isSelected = widget.midiOutputMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onMidiOutputModeChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected 
                ? Border.all(color: Colors.green, width: 1)
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.white54 : Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCCDropdown({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF3A3A3A),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: widget.ccOptions.map((option) {
                return DropdownMenuItem<int>(
                  value: option['value'] as int,
                  child: Text(option['label'] as String),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ],
    );
  }
}

// ============== ABOUT MODAL ==============

class AboutModal extends StatelessWidget {
  final VoidCallback onClose;

  const AboutModal({super.key, required this.onClose});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevent tap-through
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 24,
                  ),
                ),
              ),

              // Logo text
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('F', style: GoogleFonts.syncopate(color: const Color(0xFFBF0000), fontSize: 32, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 16),
                  Text('L', style: GoogleFonts.syncopate(color: const Color(0xFFFF7C00), fontSize: 32, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 16),
                  Text('O', style: GoogleFonts.syncopate(color: const Color(0xFFD9FF00), fontSize: 32, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 16),
                  Text('W', style: GoogleFonts.syncopate(color: const Color(0xFF008A6D), fontSize: 32, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 16),
                  Text('R', style: GoogleFonts.syncopate(color: const Color(0xFFD57CFF), fontSize: 32, fontWeight: FontWeight.w400)),
                ],
              ),
              const SizedBox(height: 16),

              // Tagline
              const Text(
                'A modern composition tool',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Version
              const Text(
                'Version 2.0.0 (1)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Credits
              const Text(
                'Created by',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Daniel Cotugno-Cregin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Text(
                '& Claude De-Buglaiter',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Copyright
              const Text(
                '© 2026 Daniel Cotugno-Cregin',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 20),

              // Links
              GestureDetector(
                onTap: () => _launchUrl('https://getflowr.io'),
                child: const Text(
                  'getflowr.io',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _launchUrl('https://getflowr.io/privacy-policy'),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _launchUrl('https://getflowr.io/support'),
                child: const Text(
                  'Support',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== V1.0 CHORD BUTTON GRID ==============

class ChordButtonGrid extends StatelessWidget {
  final List<Color> buttonColors;
  final List<Map<String, dynamic>> chordTypes;
  final String selectedKey;
  final bool isMinor;
  final List<int> Function(List<int>) getChordNotes;
  final String Function(int) getChordName;
  final MidiService midiService;
  final Function(String) logMidi;
  final int xAxisCC;
  final int yAxisCC;

  const ChordButtonGrid({
    super.key,
    required this.buttonColors,
    required this.chordTypes,
    required this.selectedKey,
    required this.isMinor,
    required this.getChordNotes,
    required this.getChordName,
    required this.midiService,
    required this.logMidi,
    required this.xAxisCC,
    required this.yAxisCC,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: row == 0 ? 0 : 6,
                bottom: row == 2 ? 0 : 6,
              ),
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: col == 0 ? 0 : 6,
                          right: col == 2 ? 0 : 6,
                        ),
                        child: ChordButton(
                          key: ValueKey('chord_${row * 3 + col}'),
                          index: row * 3 + col,
                          color: buttonColors[row * 3 + col],
                          chordType: chordTypes[row * 3 + col],
                          selectedKey: selectedKey,
                          isMinor: isMinor,
                          getChordNotes: getChordNotes,
                          getChordName: getChordName,
                          midiService: midiService,
                          logMidi: logMidi,
                          xAxisCC: xAxisCC,
                          yAxisCC: yAxisCC,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============== V1.0 CHORD BUTTON ==============

class ChordButton extends StatefulWidget {
  final int index;
  final Color color;
  final Map<String, dynamic> chordType;
  final String selectedKey;
  final bool isMinor;
  final List<int> Function(List<int>) getChordNotes;
  final String Function(int) getChordName;
  final MidiService midiService;
  final Function(String) logMidi;
  final int xAxisCC;
  final int yAxisCC;

  const ChordButton({
    super.key,
    required this.index,
    required this.color,
    required this.chordType,
    required this.selectedKey,
    required this.isMinor,
    required this.getChordNotes,
    required this.getChordName,
    required this.midiService,
    required this.logMidi,
    required this.xAxisCC,
    required this.yAxisCC,
  });

  @override
  State<ChordButton> createState() => _ChordButtonState();
}

class _ChordButtonState extends State<ChordButton> {
  bool _isPressed = false;
  List<int> _currentNotes = [];

  String get _label {
    final suffix = widget.chordType['suffix'] as String;
    final base = '${widget.selectedKey}${widget.isMinor ? 'm' : ''}';
    return suffix.isEmpty ? base : '$base\n$suffix';
  }

  @override
  void didUpdateWidget(ChordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (_isPressed && 
        (oldWidget.selectedKey != widget.selectedKey || 
         oldWidget.isMinor != widget.isMinor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isPressed) {
          _retriggerChord();
        }
      });
    }
  }

  void _retriggerChord() {
    if (_currentNotes.isNotEmpty) {
      widget.midiService.sendChordOff(_currentNotes);
    }
    
    final intervals = List<int>.from(widget.chordType['intervals']);
    _currentNotes = widget.getChordNotes(intervals);
    
    widget.midiService.sendChordOn(_currentNotes, 100);
    widget.logMidi('ON: ${widget.getChordName(widget.index)} $_currentNotes');
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isPressed = true;
    });
    
    final intervals = List<int>.from(widget.chordType['intervals']);
    _currentNotes = widget.getChordNotes(intervals);
    
    widget.midiService.sendChordOn(_currentNotes, 100);
    widget.logMidi('ON: ${widget.getChordName(widget.index)} $_currentNotes');
    
    _sendCC(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _sendCC(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _release();
  }

  void _onPanCancel() {
    _release();
  }

  void _sendCC(Offset localPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final size = box.size;
    
    final ccX = (localPosition.dx / size.width * 127).clamp(0, 127).toInt();
    final ccY = (127 - (localPosition.dy / size.height * 127)).clamp(0, 127).toInt();
    
    widget.midiService.sendCC(widget.xAxisCC, ccX);
    widget.midiService.sendCC(widget.yAxisCC, ccY);
  }

  void _release() {
    if (_currentNotes.isNotEmpty) {
      widget.midiService.sendChordOff(_currentNotes);
      widget.logMidi('OFF: ${widget.getChordName(widget.index)}');
    }
    _currentNotes = [];
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: CustomPaint(
        painter: ButtonPainter(
          index: widget.index,
          color: widget.color,
          isFilled: _isPressed,
        ),
        child: Center(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isPressed ? Colors.white : widget.color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ============== BUTTON PAINTER ==============

class ButtonPainter extends CustomPainter {
  final int index;
  final Color color;
  final bool isFilled;

  static const double bigRadius = 35.0;
  static const double smallRadius = 10.0;

  ButtonPainter({
    required this.index,
    required this.color,
    required this.isFilled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getButtonPath(size);

    if (isFilled) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, strokePaint);
  }

  Path _getButtonPath(Size size) {
    final w = size.width;
    final h = size.height;
    
    final maxRadius = (w < h ? w : h) / 2;
    final big = bigRadius.clamp(0.0, maxRadius);
    final small = smallRadius.clamp(0.0, maxRadius);

    final path = Path();

    switch (index) {
      case 0:
        path.moveTo(0, big);
        path.quadraticBezierTo(0, 0, big, 0);
        path.lineTo(w - big, 0);
        path.quadraticBezierTo(w, 0, w, big);
        path.lineTo(w, h - small);
        path.quadraticBezierTo(w, h, w - small, h);
        path.lineTo(big, h);
        path.quadraticBezierTo(0, h, 0, h - big);
        path.close();
        break;

      case 1:
        path.moveTo(0, big);
        path.quadraticBezierTo(0, 0, big, 0);
        path.lineTo(w - big, 0);
        path.quadraticBezierTo(w, 0, w, big);
        path.lineTo(w, h - small);
        path.quadraticBezierTo(w, h, w - small, h);
        path.lineTo(small, h);
        path.quadraticBezierTo(0, h, 0, h - small);
        path.close();
        break;

      case 2:
        path.moveTo(big, 0);
        path.lineTo(w - big, 0);
        path.quadraticBezierTo(w, 0, w, big);
        path.lineTo(w, h - big);
        path.quadraticBezierTo(w, h, w - big, h);
        path.lineTo(small, h);
        path.quadraticBezierTo(0, h, 0, h - small);
        path.lineTo(0, big);
        path.quadraticBezierTo(0, 0, big, 0);
        path.close();
        break;

      case 3:
        path.moveTo(0, big);
        path.quadraticBezierTo(0, 0, big, 0);
        path.lineTo(w - small, 0);
        path.quadraticBezierTo(w, 0, w, small);
        path.lineTo(w, h - small);
        path.quadraticBezierTo(w, h, w - small, h);
        path.lineTo(big, h);
        path.quadraticBezierTo(0, h, 0, h - big);
        path.close();
        break;

      case 4:
        path.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h),
          Radius.circular(small),
        ));
        break;

      case 5:
        path.moveTo(small, 0);
        path.lineTo(w - big, 0);
        path.quadraticBezierTo(w, 0, w, big);
        path.lineTo(w, h - big);
        path.quadraticBezierTo(w, h, w - big, h);
        path.lineTo(small, h);
        path.quadraticBezierTo(0, h, 0, h - small);
        path.lineTo(0, small);
        path.quadraticBezierTo(0, 0, small, 0);
        path.close();
        break;

      case 6:
        path.moveTo(0, big);
        path.quadraticBezierTo(0, 0, big, 0);
        path.lineTo(w - small, 0);
        path.quadraticBezierTo(w, 0, w, small);
        path.lineTo(w, h - big);
        path.quadraticBezierTo(w, h, w - big, h);
        path.lineTo(big, h);
        path.quadraticBezierTo(0, h, 0, h - big);
        path.close();
        break;

      case 7:
        path.moveTo(small, 0);
        path.lineTo(w - small, 0);
        path.quadraticBezierTo(w, 0, w, small);
        path.lineTo(w, h - big);
        path.quadraticBezierTo(w, h, w - big, h);
        path.lineTo(big, h);
        path.quadraticBezierTo(0, h, 0, h - big);
        path.lineTo(0, small);
        path.quadraticBezierTo(0, 0, small, 0);
        path.close();
        break;

      case 8:
        path.moveTo(small, 0);
        path.lineTo(w - big, 0);
        path.quadraticBezierTo(w, 0, w, big);
        path.lineTo(w, h - big);
        path.quadraticBezierTo(w, h, w - big, h);
        path.lineTo(big, h);
        path.quadraticBezierTo(0, h, 0, h - big);
        path.lineTo(0, small);
        path.quadraticBezierTo(0, 0, small, 0);
        path.close();
        break;
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant ButtonPainter oldDelegate) {
    return oldDelegate.color != color || 
           oldDelegate.isFilled != isFilled ||
           oldDelegate.index != index;
  }
}