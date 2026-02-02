import '../models/chord_recipe.dart';
import '../models/musical_key.dart';
import 'voice_leader.dart';

/// Result of building a chord
class BuiltChord {
  /// MIDI note numbers
  final List<int> notes;

  /// The root note name (e.g., "C", "F#")
  final String rootName;

  /// The chord recipe used
  final ChordRecipe recipe;

  /// The full chord name (e.g., "Dm7", "Gmaj9")
  final String name;

  /// The scale degree (1-7) if applicable
  final int? degree;

  /// Whether auto-voicing was applied
  final bool autoVoiced;

  const BuiltChord({
    required this.notes,
    required this.rootName,
    required this.recipe,
    required this.name,
    this.degree,
    this.autoVoiced = false,
  });

  @override
  String toString() => 'BuiltChord($name: $notes)';
}

/// Builds chords by combining key, scale degree, and chord recipe.
/// 
/// This is the core engine that turns user input into MIDI notes.
class ChordBuilder {
  /// The current musical key
  final MusicalKey key;

  /// Base octave for chord voicing (default: 4 = middle C region)
  final int baseOctave;

  /// Voice leader for auto-voicing (optional)
  final VoiceLeader? voiceLeader;

  ChordBuilder({
    required this.key,
    this.baseOctave = 4,
    this.voiceLeader,
  });

  /// Build a chord for a scale degree with optional recipe override.
  /// 
  /// [degree] - Scale degree 1-7 (I through vii)
  /// [recipe] - Optional chord type override (null = use diatonic default)
  /// [autoVoice] - Use voice leading for smooth inversions
  BuiltChord build({
    required int degree,
    ChordRecipe? recipe,
    bool autoVoice = false,
  }) {
    assert(degree >= 1 && degree <= 7, 'Degree must be 1-7');

    // Get the actual recipe (override or diatonic default)
    final actualRecipe = recipe ?? key.diatonicRecipe(degree);

    // Get the root pitch class for this degree
    final rootPitchClass = key.degreeRoot(degree);
    final rootName = key.degreeName(degree);

    // Convert recipe intervals to pitch classes
    final pitchClasses = actualRecipe.toPitchClasses(rootPitchClass);

    // Generate MIDI notes
    final List<int> notes;
    final bool wasAutoVoiced;

    if (autoVoice && voiceLeader != null) {
      notes = voiceLeader!.voice(pitchClasses, rootPitchClass);
      wasAutoVoiced = true;
    } else {
      notes = _buildRootPosition(pitchClasses);
      wasAutoVoiced = false;
    }

    // Build chord name
    final chordName = '$rootName${actualRecipe.symbol}';

    return BuiltChord(
      notes: notes,
      rootName: rootName,
      recipe: actualRecipe,
      name: chordName,
      degree: degree,
      autoVoiced: wasAutoVoiced,
    );
  }

  /// Build a chord from an absolute root (for Explorer/Parallel modes)
  /// 
  /// [rootPitchClass] - Root note as pitch class (0-11, where C=0)
  /// [recipe] - Chord type recipe
  /// [autoVoice] - Use voice leading for smooth inversions
  BuiltChord buildFromRoot({
    required int rootPitchClass,
    required ChordRecipe recipe,
    bool autoVoice = false,
  }) {
    // Get root name
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final rootName = noteNames[rootPitchClass % 12];

    // Convert recipe intervals to pitch classes
    final pitchClasses = recipe.toPitchClasses(rootPitchClass);

    // Generate MIDI notes
    final List<int> notes;
    final bool wasAutoVoiced;

    if (autoVoice && voiceLeader != null) {
      notes = voiceLeader!.voice(pitchClasses, rootPitchClass);
      wasAutoVoiced = true;
    } else {
      notes = _buildRootPosition(pitchClasses);
      wasAutoVoiced = false;
    }

    // Build chord name
    final chordName = '$rootName${recipe.symbol}';

    return BuiltChord(
      notes: notes,
      rootName: rootName,
      recipe: recipe,
      name: chordName,
      autoVoiced: wasAutoVoiced,
    );
  }

  /// Build root position voicing from pitch classes
  List<int> _buildRootPosition(List<int> pitchClasses) {
    final notes = <int>[];
    int lastPitch = -1;

    for (final pc in pitchClasses) {
      int pitch = (baseOctave * 12) + pc;

      // Ensure each note is higher than the last
      while (pitch <= lastPitch) {
        pitch += 12;
      }

      notes.add(pitch);
      lastPitch = pitch;
    }

    return notes;
  }

  /// Reset voice leading context (call on key change, etc.)
  void resetVoiceLeading() {
    voiceLeader?.reset();
  }

  /// Create a new builder with a different key
  ChordBuilder withKey(MusicalKey newKey) {
    return ChordBuilder(
      key: newKey,
      baseOctave: baseOctave,
      voiceLeader: voiceLeader,
    );
  }

  /// Create a new builder with a different octave
  ChordBuilder withOctave(int newOctave) {
    return ChordBuilder(
      key: key,
      baseOctave: newOctave,
      voiceLeader: voiceLeader,
    );
  }
}
