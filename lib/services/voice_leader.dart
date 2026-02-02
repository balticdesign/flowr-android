/// Voice leader handles automatic chord voicing for smooth progressions.
/// 
/// Uses OPEN voicings (like outer petals) but selects inversions that
/// minimize movement in the voice-leading zone (middle voices).
/// 
/// Mental model:
/// ```
/// [ Bass anchor ]         ← root moves by chord root
/// [ Voice-leading zone ]  ← auto-voicing minimizes movement here
/// [ Top anchor ]          ← may shift octave to reduce total movement
/// ```
class VoiceLeader {
  /// Previous chord notes for comparison
  List<int>? _previousChord;

  /// Time of last chord for reset detection
  DateTime? _lastChordTime;

  /// Timeout for auto-reset (default 2 seconds)
  final Duration resetTimeout;

  VoiceLeader({
    this.resetTimeout = const Duration(seconds: 2),
  });

  /// Get the best voicing for a chord given the previous context.
  /// 
  /// [pitchClasses] - List of pitch classes (0-11) in the chord
  /// [rootPitchClass] - The root note pitch class (for reference)
  /// [baseOctave] - The user's selected base octave (2-6)
  /// 
  /// Returns MIDI note numbers for the voiced chord.
  List<int> voice(List<int> pitchClasses, int rootPitchClass, {int baseOctave = 4}) {
    // Check for timeout reset
    if (_shouldReset()) {
      reset();
    }

    // Generate open voicing candidates
    final candidates = _generateOpenVoicings(pitchClasses, rootPitchClass, baseOctave);

    if (candidates.isEmpty) {
      // Fallback: generate a basic open voicing
      return _buildOpenVoicing(pitchClasses, rootPitchClass, baseOctave);
    }

    // Update timestamp
    _lastChordTime = DateTime.now();

    // If no previous chord, return first candidate
    if (_previousChord == null) {
      _previousChord = candidates.first;
      return _previousChord!;
    }

    // Find the candidate with minimum movement in voice-leading zone
    var best = candidates.first;
    var bestScore = _voiceLeadingScore(candidates.first, _previousChord!);

    for (final candidate in candidates.skip(1)) {
      final score = _voiceLeadingScore(candidate, _previousChord!);
      if (score < bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    _previousChord = best;
    return best;
  }

  /// Check if we should reset due to timeout
  bool _shouldReset() {
    if (_lastChordTime == null) return false;
    return DateTime.now().difference(_lastChordTime!) > resetTimeout;
  }

  /// Generate open voicing candidates with different inversions
  /// 
  /// Structure: Bass (root) - Middle voices (spread) - Top (root octave up)
  List<List<int>> _generateOpenVoicings(List<int> pitchClasses, int rootPitchClass, int baseOctave) {
    final results = <List<int>>[];
    
    if (pitchClasses.length < 3) return results;
    
    final isLowOctave = baseOctave <= 3;
    
    // Get intervals relative to root
    final root = pitchClasses[0];
    final third = pitchClasses.length > 1 ? pitchClasses[1] : null;
    final fifth = pitchClasses.length > 2 ? pitchClasses[2] : null;
    final extensions = pitchClasses.length > 3 ? pitchClasses.sublist(3) : <int>[];
    
    // Try different voicing arrangements
    for (int bassOctaveOffset = -1; bassOctaveOffset <= 1; bassOctaveOffset++) {
      final bassOctave = baseOctave + bassOctaveOffset;
      if (bassOctave < 2 || bassOctave > 5) continue;
      
      final bassMidi = (bassOctave * 12) + root;
      
      // Skip if bass too low or high
      if (bassMidi < 36 || bassMidi > 72) continue; // C2 to C5
      
      // Generate variations of middle voice placement
      for (int middleOctaveOffset = 0; middleOctaveOffset <= 1; middleOctaveOffset++) {
        final notes = <int>[];
        
        // 1. Bass anchor (root)
        notes.add(bassMidi);
        
        // 2. Middle voices (3rd and 5th) - the voice-leading zone
        final middleOctave = isLowOctave ? bassOctave + 1 + middleOctaveOffset : bassOctave + middleOctaveOffset;
        
        if (fifth != null) {
          notes.add((middleOctave * 12) + fifth);
        }
        if (third != null) {
          var thirdMidi = (middleOctave * 12) + third;
          // Ensure 3rd is above 5th for some voicings, or below for others
          if (thirdMidi <= notes.last) {
            thirdMidi += 12;
          }
          notes.add(thirdMidi);
        }
        
        // 3. Extensions (7th, 9th) go higher
        for (final ext in extensions) {
          var extMidi = ((middleOctave + 1) * 12) + ext;
          while (extMidi <= notes.last) {
            extMidi += 12;
          }
          if (extMidi <= 96) { // Don't exceed C7
            notes.add(extMidi);
          }
        }
        
        // 4. Top anchor (root up 1-2 octaves)
        final topRoot = bassMidi + (isLowOctave ? 24 : 12);
        if (topRoot <= 96 && topRoot > notes.last) {
          notes.add(topRoot);
        }
        
        // Sort and validate
        notes.sort();
        if (notes.length >= 3 && notes.every((n) => n >= 36 && n <= 96)) {
          results.add(notes);
        }
      }
      
      // Also try inverted voicings (5th in bass, 3rd in bass)
      if (fifth != null) {
        final invBass = (bassOctave * 12) + fifth;
        if (invBass >= 36 && invBass <= 72) {
          final notes = <int>[invBass];
          final middleOctave = isLowOctave ? bassOctave + 1 : bassOctave;
          
          // Root above bass
          notes.add((middleOctave * 12) + root);
          
          // 3rd
          if (third != null) {
            var thirdMidi = (middleOctave * 12) + third;
            while (thirdMidi <= notes.last) thirdMidi += 12;
            notes.add(thirdMidi);
          }
          
          // Extensions
          for (final ext in extensions) {
            var extMidi = ((middleOctave + 1) * 12) + ext;
            while (extMidi <= notes.last) extMidi += 12;
            if (extMidi <= 96) notes.add(extMidi);
          }
          
          notes.sort();
          if (notes.length >= 3 && notes.every((n) => n >= 36 && n <= 96)) {
            results.add(notes);
          }
        }
      }
    }
    
    return results;
  }

  /// Build a basic open voicing (fallback)
  List<int> _buildOpenVoicing(List<int> pitchClasses, int rootPitchClass, int baseOctave) {
    final notes = <int>[];
    final bassMidi = (baseOctave * 12) + pitchClasses[0];
    final isLowOctave = baseOctave <= 3;
    
    notes.add(bassMidi);
    
    for (int i = 1; i < pitchClasses.length; i++) {
      final octaveOffset = isLowOctave ? (i <= 2 ? 1 : 2) : (i <= 2 ? 0 : 1);
      var midi = ((baseOctave + octaveOffset) * 12) + pitchClasses[i];
      while (midi <= notes.last) midi += 12;
      if (midi <= 96) notes.add(midi);
    }
    
    // Add top root
    final topRoot = bassMidi + (isLowOctave ? 24 : 12);
    if (topRoot <= 96 && topRoot > notes.last) {
      notes.add(topRoot);
    }
    
    notes.sort();
    return notes;
  }

  /// Calculate voice-leading score
  /// 
  /// Prioritizes minimal movement in middle voices (voice-leading zone)
  /// while allowing bass and top to move more freely.
  int _voiceLeadingScore(List<int> newChord, List<int> oldChord) {
    if (newChord.isEmpty || oldChord.isEmpty) return 1000;
    
    int total = 0;
    
    // Score each voice by closest match in old chord
    for (int i = 0; i < newChord.length; i++) {
      int minDistance = 127;
      
      for (final oldNote in oldChord) {
        final distance = (newChord[i] - oldNote).abs();
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
      
      // Weight middle voices more heavily (they should move least)
      final isMiddleVoice = i > 0 && i < newChord.length - 1;
      total += isMiddleVoice ? minDistance * 2 : minDistance;
    }
    
    return total;
  }

  /// Reset the voice leading context
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