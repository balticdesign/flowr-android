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
  /// [recipe] - Optional chord type override (null = use diatonic default with open voicing)
  /// [autoVoice] - Use voice leading for smooth inversions (inner petal)
  BuiltChord build({
    required int degree,
    ChordRecipe? recipe,
    bool autoVoice = false,
  }) {
    assert(degree >= 1 && degree <= 7, 'Degree must be 1-7');

    // Get the diatonic recipe for this degree
    final diatonicRecipe = key.diatonicRecipe(degree);
    
    // Determine actual recipe - handle quality toggle
    ChordRecipe actualRecipe;
    if (recipe != null && recipe.isQualityToggle) {
      // Quality toggle: flip major ↔ minor
      actualRecipe = _toggleQuality(diatonicRecipe);
    } else {
      actualRecipe = recipe ?? diatonicRecipe;
    }
    
    // Pads-only mode: no recipe override provided
    final isPadsOnly = recipe == null;

    // Get the root pitch class for this degree
    final rootPitchClass = key.degreeRoot(degree);
    final rootName = key.degreeName(degree);

    // Generate MIDI notes based on mode
    final List<int> notes;
    final bool wasAutoVoiced;

    if (autoVoice && voiceLeader != null) {
      // Inner petal: close-voiced with voice leading for smooth movement
      final pitchClasses = actualRecipe.toPitchClasses(rootPitchClass);
      notes = voiceLeader!.voice(pitchClasses, rootPitchClass, baseOctave: baseOctave);
      wasAutoVoiced = true;
    } else if (isPadsOnly) {
      // Pads-only: open triad voicing R - 3(+1) - 5(+1) - R(+2) or R - 3 - 5 - R(+1)
      notes = _buildOpenTriad(rootPitchClass, actualRecipe);
      wasAutoVoiced = false;
    } else {
      // Outer petal: spread voicing for clarity
      notes = _buildSpreadVoicing(rootPitchClass, actualRecipe);
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

  /// Build open triad voicing for pads-only
  /// 
  /// Lower octaves (2-3): R - 3(+1) - 5(+1) - R(+2) - spread to avoid mud
  /// Upper octaves (4+):  R - 3 - 5 - R(+1) - tighter, cleaner
  /// 
  /// Examples at octave 3:
  /// - C major: C3 - E4 - G4 - C5
  /// - A minor: A3 - C4 - E4 - A5
  /// - D sus4:  D3 - A4 - D5 (no third)
  List<int> _buildOpenTriad(int rootPitchClass, ChordRecipe recipe) {
    final baseMidi = (baseOctave * 12) + rootPitchClass;
    final isLowOctave = baseOctave <= 3;
    
    final notes = <int>[];
    
    // 1. Root (bass note)
    notes.add(baseMidi);
    
    // Determine intervals
    final hasMajorThird = recipe.intervals.contains(4);
    final hasMinorThird = recipe.intervals.contains(3);
    final isSus = (recipe.intervals.contains(2) || recipe.intervals.contains(5)) && 
                  !hasMajorThird && !hasMinorThird;
    
    // Fifth interval - handle dim (6) and aug (8)
    int fifthInterval = 7;
    if (recipe.intervals.contains(6) && !recipe.intervals.contains(7)) {
      fifthInterval = 6;
    } else if (recipe.intervals.contains(8) && !recipe.intervals.contains(7)) {
      fifthInterval = 8;
    }
    
    if (isLowOctave) {
      // R - 3(+1) - 5(+1) - R(+2) for octaves 2-3
      if (!isSus) {
        if (hasMinorThird) {
          notes.add(baseMidi + 12 + 3);  // 3rd up an octave
        } else if (hasMajorThird) {
          notes.add(baseMidi + 12 + 4);  // 3rd up an octave
        }
      }
      notes.add(baseMidi + 12 + fifthInterval);  // 5th up an octave
      notes.add(baseMidi + 24);  // Root up 2 octaves
    } else {
      // R - 3 - 5 - R(+1) for octaves 4+
      if (!isSus) {
        if (hasMinorThird) {
          notes.add(baseMidi + 3);  // 3rd same octave
        } else if (hasMajorThird) {
          notes.add(baseMidi + 4);  // 3rd same octave
        }
      }
      notes.add(baseMidi + fifthInterval);  // 5th same octave
      if (baseMidi + 12 <= 96) {  // Don't exceed C7
        notes.add(baseMidi + 12);  // Root up 1 octave
      }
    }
    
    notes.sort();
    return notes;
  }

  /// Build spread voicing for outer petals
  /// 
  /// Similar spread approach but handles extended chords (7ths, 9ths, etc.)
  /// Spreads notes across octaves for clarity without mud
  List<int> _buildSpreadVoicing(int rootPitchClass, ChordRecipe recipe) {
    final baseMidi = (baseOctave * 12) + rootPitchClass;
    final isLowOctave = baseOctave <= 3;
    final intervals = recipe.intervals;
    
    final notes = <int>[];
    
    // Always start with root
    notes.add(baseMidi);
    
    if (isLowOctave) {
      // Spread voicing for low octaves - push upper notes up
      for (int i = 1; i < intervals.length; i++) {
        final interval = intervals[i];
        if (i <= 2) {
          // 3rd and 5th go up one octave
          notes.add(baseMidi + 12 + interval);
        } else {
          // Extensions (7th, 9th, etc.) go up two octaves
          notes.add(baseMidi + 24 + (interval % 12));
        }
      }
    } else {
      // Tighter voicing for higher octaves
      for (int i = 1; i < intervals.length; i++) {
        final interval = intervals[i];
        int note = baseMidi + interval;
        // Keep notes ascending
        while (notes.isNotEmpty && note <= notes.last) {
          note += 12;
        }
        if (note <= 96) {  // Don't exceed C7
          notes.add(note);
        }
      }
    }
    
    notes.sort();
    return notes;
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
      notes = voiceLeader!.voice(pitchClasses, rootPitchClass, baseOctave: baseOctave);
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

  /// Toggle quality: flip major ↔ minor in a recipe
  /// 
  /// - Major triad → Minor triad
  /// - Minor triad → Major triad  
  /// - Maj7 → m7, m7 → Maj7
  /// - Diminished stays diminished
  /// - Augmented stays augmented
  ChordRecipe _toggleQuality(ChordRecipe original) {
    final intervals = List<int>.from(original.intervals);
    
    // Find and flip the 3rd
    final hasMinor3rd = intervals.contains(3);
    final hasMajor3rd = intervals.contains(4);
    
    if (hasMinor3rd) {
      // Minor → Major: change 3 to 4
      final idx = intervals.indexOf(3);
      intervals[idx] = 4;
      
      // Also flip 7th if present (m7 → maj7)
      if (intervals.contains(10)) {
        final idx7 = intervals.indexOf(10);
        intervals[idx7] = 11;
      }
      
      return ChordRecipe(
        name: 'Major',
        symbol: '',
        intervals: intervals,
      );
    } else if (hasMajor3rd) {
      // Major → Minor: change 4 to 3
      final idx = intervals.indexOf(4);
      intervals[idx] = 3;
      
      // Also flip 7th if present (maj7 → m7)
      if (intervals.contains(11)) {
        final idx7 = intervals.indexOf(11);
        intervals[idx7] = 10;
      }
      
      return ChordRecipe(
        name: 'Minor',
        symbol: 'm',
        intervals: intervals,
      );
    }
    
    // No 3rd to flip (sus, dim, aug) - return original
    return original;
  }
}