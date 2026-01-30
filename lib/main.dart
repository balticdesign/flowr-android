import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'petal_wheel.dart';
import 'midi_service.dart';

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
  String _selectedKey = 'C';
  bool _isMinor = false;
  bool _showSettings = false;
  bool _showMidiDebug = false;
  bool _showMidiTooltip = false;
  bool _useParallelLayout = false;
  bool _hapticsEnabled = true;
  
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
  
  final List<String> _midiLog = [];
  static const int _maxLogEntries = 5;

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
    _initMidi();
  }

  Future<void> _initMidi() async {
    await _checkMidiConnection();
    setState(() {});
  }

  @override
  void dispose() {
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
    return _midiService.isConnected ? 'USB MIDI Connected' : 'MIDI Not Connected';
  }

  void _logMidi(String message) {
    setState(() {
      _midiLog.insert(0, message);
      if (_midiLog.length > _maxLogEntries) {
        _midiLog.removeLast();
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
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
                      useParallelLayout: _useParallelLayout,
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
          ),
          
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
          
          // MIDI indicator
          Positioned(
            bottom: 16,
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
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _midiService.isConnected 
                            ? Colors.green.withOpacity(0.9)
                            : Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getMidiStatusText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _onMidiTap,
                    child: SvgPicture.asset(
                      'assets/midi_connected.svg',
                      width: 32,
                      height: 32,
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
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'GYRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
              useParallelLayout: _useParallelLayout,
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
              onLayoutChanged: (value) {
                setState(() {
                  _useParallelLayout = value;
                });
              },
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
}

// ============== SETTINGS OVERLAY ==============

class SettingsOverlay extends StatefulWidget {
  final bool showMidiDebug;
  final bool useParallelLayout;
  final bool hapticsEnabled;
  final int xAxisCC;
  final int yAxisCC;
  final bool gyroEnabled;
  final int gyroXCC;
  final int gyroYCC;
  final int gyroZCC;
  final List<Map<String, dynamic>> ccOptions;
  final Function(bool) onMidiDebugChanged;
  final Function(bool) onLayoutChanged;
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
    required this.useParallelLayout,
    required this.hapticsEnabled,
    required this.xAxisCC,
    required this.yAxisCC,
    required this.gyroEnabled,
    required this.gyroXCC,
    required this.gyroYCC,
    required this.gyroZCC,
    required this.ccOptions,
    required this.onMidiDebugChanged,
    required this.onLayoutChanged,
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
        constraints: const BoxConstraints(maxHeight: 520),
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
              // FLOWR logo at top - rainbow colors
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
                label: 'Parallel Layout',
                subtitle: widget.useParallelLayout 
                    ? 'Cm inside C' 
                    : 'Am inside C (Circle of 5ths)',
                value: widget.useParallelLayout,
                onChanged: widget.onLayoutChanged,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
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

              // Logo text with Syncopate font - rainbow colors
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
              const SizedBox(height: 12),

              // Tagline
              const Text(
                'A modern composition tool',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Version
              const Text(
                'Version 1.0.0 (12)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Credits
              const Text(
                'Created by',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Daniel Cotugno-Cregin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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

// ============== CHORD BUTTON GRID ==============

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

// ============== CHORD BUTTON ==============

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
    
    // If key or minor changed while button is pressed, retrigger the chord
    if (_isPressed && 
        (oldWidget.selectedKey != widget.selectedKey || 
         oldWidget.isMinor != widget.isMinor)) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isPressed) {
          _retriggerChord();
        }
      });
    }
  }

  void _retriggerChord() {
    // Send note-off for old chord
    if (_currentNotes.isNotEmpty) {
      widget.midiService.sendChordOff(_currentNotes);
    }
    
    // Calculate and play new chord
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