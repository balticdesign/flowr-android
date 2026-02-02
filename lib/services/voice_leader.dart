/// Voice leader handles automatic chord voicing for smooth progressions.
/// 
/// When enabled, it selects the inversion of each chord that minimises
/// the total semitone movement from the previous chord. This creates
/// professional-sounding progressions with smooth voice leading.
class VoiceLeader {
  /// Previous chord notes for comparison
  List<int>? _previousChord;

  /// Minimum MIDI note (default C3 = 48)
  final int minPitch;

  /// Maximum MIDI note (default C6 = 84)
  final int maxPitch;

  /// Time of last chord for reset detection
  DateTime? _lastChordTime;

  /// Timeout for auto-reset (default 2 seconds)
  final Duration resetTimeout;

  VoiceLeader({
    this.minPitch = 48,
    this.maxPitch = 84,
    this.resetTimeout = const Duration(seconds: 2),
  });

  /// Get the best voicing for a chord given the previous context.
  /// 
  /// [pitchClasses] - List of pitch classes (0-11) in the chord
  /// [rootPitchClass] - The root note pitch class (for reference)
  /// 
  /// Returns MIDI note numbers for the voiced chord.
  List<int> voice(List<int> pitchClasses, int rootPitchClass) {
    // Check for timeout reset
    if (_shouldReset()) {
      reset();
    }

    final candidates = _generateInversions(pitchClasses);

    if (candidates.isEmpty) {
      // Fallback: generate a simple voicing
      return _buildSimpleVoicing(pitchClasses, 4);
    }

    // Update timestamp
    _lastChordTime = DateTime.now();

    // If no previous chord, return first candidate (root position)
    if (_previousChord == null) {
      _previousChord = candidates.first;
      return _previousChord!;
    }

    // Find the candidate with minimum movement
    var best = candidates.first;
    var bestScore = _movementScore(candidates.first, _previousChord!);

    for (final candidate in candidates.skip(1)) {
      final score = _movementScore(candidate, _previousChord!);
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    _previousChord = best;
    return best;
  }

  /// Generate a root position voicing (no voice leading)
  List<int> voiceRootPosition(List<int> pitchClasses, {int octave = 4}) {
    // Update timestamp but don't affect voice leading context
    _lastChordTime = DateTime.now();
    return _buildSimpleVoicing(pitchClasses, octave);
  }

  /// Check if we should reset due to timeout
  bool _shouldReset() {
    if (_lastChordTime == null) return false;
    return DateTime.now().difference(_lastChordTime!) > resetTimeout;
  }

  /// Generate all valid inversions of a chord within the pitch range
  List<List<int>> _generateInversions(List<int> pitchClasses) {
    final results = <List<int>>[];

    if (pitchClasses.isEmpty) return results;

    // Try different bass octaves
    for (int bassOctave = 3; bassOctave <= 5; bassOctave++) {
      // Try each inversion (rotate which pitch class is in bass)
      for (int inv = 0; inv < pitchClasses.length; inv++) {
        final rotated = _rotate(pitchClasses, inv);
        final voiced = _stackFromBass(rotated, bassOctave);

        // Check all notes are within range
        if (voiced.every((n) => n >= minPitch && n <= maxPitch)) {
          results.add(voiced);
        }
      }
    }

    return results;
  }

  /// Rotate a list so the element at [positions] becomes first
  List<int> _rotate(List<int> list, int positions) {
    if (list.isEmpty || positions == 0) return List.from(list);
    final n = positions % list.length;
    return [...list.sublist(n), ...list.sublist(0, n)];
  }

  /// Stack pitch classes upward from a bass octave
  List<int> _stackFromBass(List<int> pitchClasses, int bassOctave) {
    final notes = <int>[];
    int lastPitch = -1;

    for (final pc in pitchClasses) {
      int pitch = (bassOctave * 12) + pc;

      // Ensure each note is higher than the last
      while (pitch <= lastPitch) {
        pitch += 12;
      }

      notes.add(pitch);
      lastPitch = pitch;
    }

    return notes;
  }

  /// Build a simple root position voicing
  List<int> _buildSimpleVoicing(List<int> pitchClasses, int octave) {
    return _stackFromBass(pitchClasses, octave);
  }

  /// Calculate total semitone movement between two chords
  /// 
  /// For each note in the new chord, find the closest note in the old chord
  /// and sum up all the distances.
  int _movementScore(List<int> newChord, List<int> oldChord) {
    int total = 0;

    for (final newNote in newChord) {
      int minDistance = 127;

      for (final oldNote in oldChord) {
        final distance = (newNote - oldNote).abs();
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      total += minDistance;
    }

    return total;
  }

  /// Reset the voice leading context
  /// 
  /// Call this when:
  /// - Key changes
  /// - User manually requests reset
  /// - Long pause between chords
  /// - Mode changes
  void reset() {
    _previousChord = null;
    _lastChordTime = null;
  }

  /// Check if there's an active voice leading context
  bool get hasContext => _previousChord != null;

  /// Get the previous chord (for debugging/display)
  List<int>? get previousChord => _previousChord != null 
      ? List.unmodifiable(_previousChord!) 
      : null;
}
