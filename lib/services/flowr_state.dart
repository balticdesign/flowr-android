import 'package:flutter/foundation.dart';

import '../models/chord_recipe.dart';
import '../models/enums.dart';
import '../models/musical_key.dart';
import '../models/pad_config.dart';
import '../models/petal_config.dart';
import 'chord_builder.dart';
import 'voice_leader.dart';

/// Callback for MIDI note events
typedef MidiNoteCallback = void Function(int note, int velocity, bool noteOn);

/// Callback for MIDI CC events
typedef MidiCCCallback = void Function(int cc, int value);

/// Main state manager for Flowr v2.0
/// 
/// Handles:
/// - Play mode (Songwriter/Explorer/Parallel)
/// - Key selection
/// - Pad input → chord generation
/// - Petal input → chord type override
/// - Voice leading
/// - MIDI output coordination
class FlowrState extends ChangeNotifier {
  // === CONFIGURATION ===

  PlayMode _playMode = PlayMode.songwriter;
  MusicalKey _currentKey = MusicalKeys.cMajor;
  int _baseOctave = 4;

  // === INPUT STATE ===

  /// Currently pressed pad index (null if none)
  int? _activePadIndex;

  /// Currently touched petal (null if none)
  PetalConfig? _activePetal;

  /// Is the function pad held?
  bool _functionHeld = false;

  /// Is sustain active?
  bool _sustainActive = false;

  /// Is sustain latched (toggle mode)?
  bool _sustainLatched = false;

  // === CHORD STATE ===

  /// Currently playing chord
  BuiltChord? _currentChord;

  /// Notes currently held (for note-off tracking)
  final Set<int> _heldNotes = {};

  /// Notes sustained (held by sustain pedal)
  final Set<int> _sustainedNotes = {};

  // === SERVICES ===

  final VoiceLeader _voiceLeader = VoiceLeader();
  late ChordBuilder _chordBuilder;

  // === CALLBACKS ===

  MidiNoteCallback? onMidiNote;
  MidiCCCallback? onMidiCC;

  // === CONSTRUCTOR ===

  FlowrState() {
    _chordBuilder = ChordBuilder(
      key: _currentKey,
      baseOctave: _baseOctave,
      voiceLeader: _voiceLeader,
    );
  }

  // === GETTERS ===

  PlayMode get playMode => _playMode;
  MusicalKey get currentKey => _currentKey;
  int get baseOctave => _baseOctave;
  int? get activePadIndex => _activePadIndex;
  PetalConfig? get activePetal => _activePetal;
  bool get functionHeld => _functionHeld;
  bool get sustainActive => _sustainActive || _sustainLatched;
  bool get sustainLatched => _sustainLatched;
  BuiltChord? get currentChord => _currentChord;
  Set<int> get heldNotes => Set.unmodifiable(_heldNotes);

  /// Get the chord recipe currently active (from petal or diatonic default)
  ChordRecipe? get activeRecipe => _activePetal?.recipe;

  /// Is auto-voicing active? (inner petal selected)
  bool get isAutoVoicing => _activePetal?.isInner ?? false;

  // === SETTERS ===

  void setPlayMode(PlayMode mode) {
    if (_playMode == mode) return;
    _playMode = mode;
    _voiceLeader.reset();
    notifyListeners();
  }

  void setKey(MusicalKey key) {
    if (_currentKey == key) return;
    _currentKey = key;
    _chordBuilder = _chordBuilder.withKey(key);
    _voiceLeader.reset();
    notifyListeners();
  }

  void setBaseOctave(int octave) {
    final clamped = octave.clamp(2, 6);
    if (_baseOctave == clamped) return;
    _baseOctave = clamped;
    _chordBuilder = _chordBuilder.withOctave(clamped);
    notifyListeners();
  }

  // === PAD INPUT ===

  /// Handle pad press
  void onPadDown(int padIndex) {
    final pad = PadLayout.getPad(padIndex);

    switch (pad.type) {
      case PadType.degree:
        _handleDegreePadDown(pad);
        break;
      case PadType.function:
        _handleFunctionPadDown();
        break;
      case PadType.sustain:
        _handleSustainPadDown();
        break;
    }
  }

  /// Handle pad release
  void onPadUp(int padIndex) {
    final pad = PadLayout.getPad(padIndex);

    switch (pad.type) {
      case PadType.degree:
        _handleDegreePadUp(pad);
        break;
      case PadType.function:
        _handleFunctionPadUp();
        break;
      case PadType.sustain:
        _handleSustainPadUp();
        break;
    }
  }

  void _handleDegreePadDown(PadConfig pad) {
    if (pad.degree == null) return;

    _activePadIndex = pad.index;

    // Build and play the chord
    _playChordForDegree(pad.degree!.number);

    notifyListeners();
  }

  void _handleDegreePadUp(PadConfig pad) {
    if (_activePadIndex != pad.index) return;

    _activePadIndex = null;

    // Release chord (unless sustained)
    if (!sustainActive) {
      _releaseCurrentChord();
    } else {
      // Add to sustained notes
      _sustainedNotes.addAll(_heldNotes);
      _heldNotes.clear();
    }

    notifyListeners();
  }

  void _handleFunctionPadDown() {
    _functionHeld = true;
    notifyListeners();
  }

  void _handleFunctionPadUp() {
    _functionHeld = false;
    notifyListeners();
  }

  void _handleSustainPadDown() {
    _sustainActive = true;

    // Send MIDI sustain CC
    onMidiCC?.call(64, 127);

    notifyListeners();
  }

  void _handleSustainPadUp() {
    _sustainActive = false;

    if (!_sustainLatched) {
      // Release all sustained notes
      _releaseSustainedNotes();

      // Send MIDI sustain CC off
      onMidiCC?.call(64, 0);
    }

    notifyListeners();
  }

  /// Toggle sustain latch mode
  void toggleSustainLatch() {
    _sustainLatched = !_sustainLatched;

    if (!_sustainLatched) {
      // Turning off latch - release sustained notes
      _releaseSustainedNotes();
      onMidiCC?.call(64, 0);
    } else {
      // Turning on latch
      onMidiCC?.call(64, 127);
    }

    notifyListeners();
  }

  // === PETAL INPUT ===

  /// Handle petal touch
  void onPetalDown(PetalConfig petal) {
    // If function held, this is key selection
    if (_functionHeld) {
      _handleKeySelection(petal);
      return;
    }

    _activePetal = petal;

    // If a pad is already pressed, update the chord
    if (_activePadIndex != null) {
      final pad = PadLayout.getPad(_activePadIndex!);
      if (pad.degree != null) {
        _playChordForDegree(pad.degree!.number);
      }
    }

    notifyListeners();
  }

  /// Handle petal release
  void onPetalUp() {
    if (_activePetal == null) return;

    _activePetal = null;

    // If a pad is still pressed, revert to diatonic chord
    if (_activePadIndex != null) {
      final pad = PadLayout.getPad(_activePadIndex!);
      if (pad.degree != null) {
        _playChordForDegree(pad.degree!.number);
      }
    }

    notifyListeners();
  }

  /// Handle petal move (finger dragged to different petal)
  void onPetalMove(PetalConfig? petal) {
    if (petal == _activePetal) return;

    if (petal == null) {
      onPetalUp();
    } else {
      onPetalDown(petal);
    }
  }

  void _handleKeySelection(PetalConfig petal) {
    // Outer = major, Inner = minor (parallel)
    final newKey = MusicalKeys.byPetalChromatic(
      petal.index,
      inner: petal.isInner,
    );

    setKey(newKey);
  }

  // === CHORD GENERATION ===

  void _playChordForDegree(int degree) {
    // Release previous chord first
    _releaseCurrentChord();

    // Build the new chord
    final chord = _chordBuilder.build(
      degree: degree,
      recipe: _activePetal?.recipe,
      autoVoice: _activePetal?.isInner ?? false,
    );

    _currentChord = chord;

    // Send MIDI note-ons
    for (final note in chord.notes) {
      _heldNotes.add(note);
      onMidiNote?.call(note, 100, true);
    }
  }

  void _releaseCurrentChord() {
    // Send note-offs for held notes
    for (final note in _heldNotes) {
      onMidiNote?.call(note, 0, false);
    }
    _heldNotes.clear();

    _currentChord = null;
  }

  void _releaseSustainedNotes() {
    for (final note in _sustainedNotes) {
      // Only release if not currently held
      if (!_heldNotes.contains(note)) {
        onMidiNote?.call(note, 0, false);
      }
    }
    _sustainedNotes.clear();
  }

  // === PANIC / RESET ===

  /// All notes off - panic button
  void panic() {
    // Release all held notes
    for (final note in _heldNotes) {
      onMidiNote?.call(note, 0, false);
    }
    _heldNotes.clear();

    // Release all sustained notes
    for (final note in _sustainedNotes) {
      onMidiNote?.call(note, 0, false);
    }
    _sustainedNotes.clear();

    // Reset sustain
    _sustainActive = false;
    _sustainLatched = false;
    onMidiCC?.call(64, 0);

    // Clear state
    _currentChord = null;
    _activePadIndex = null;
    _activePetal = null;
    _functionHeld = false;

    // Reset voice leading
    _voiceLeader.reset();

    notifyListeners();
  }

  /// Reset voice leading context only
  void resetVoiceLeading() {
    _voiceLeader.reset();
  }

  // === EXPLORER/PARALLEL MODE SUPPORT ===

  /// Play a chord by absolute root (for Explorer/Parallel modes)
  void playChordFromRoot(int rootPitchClass, ChordRecipe recipe, {bool autoVoice = false}) {
    _releaseCurrentChord();

    final chord = _chordBuilder.buildFromRoot(
      rootPitchClass: rootPitchClass,
      recipe: recipe,
      autoVoice: autoVoice,
    );

    _currentChord = chord;

    for (final note in chord.notes) {
      _heldNotes.add(note);
      onMidiNote?.call(note, 100, true);
    }

    notifyListeners();
  }

  /// Release current chord (for Explorer/Parallel modes)
  void releaseChord() {
    if (!sustainActive) {
      _releaseCurrentChord();
    } else {
      _sustainedNotes.addAll(_heldNotes);
      _heldNotes.clear();
    }
    notifyListeners();
  }

  // === DEBUG ===

  @override
  String toString() {
    return 'FlowrState('
        'mode: $playMode, '
        'key: ${currentKey.shortName}, '
        'pad: $_activePadIndex, '
        'petal: ${_activePetal?.recipe.name}, '
        'chord: ${_currentChord?.name}'
        ')';
  }
}
