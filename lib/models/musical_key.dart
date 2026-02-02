import 'chord_recipe.dart';

/// Note names for display
const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// A musical key defines a tonic and mode (major/minor).
/// 
/// The key determines:
/// - Which notes are in the scale
/// - What the default chord is for each degree
/// - The root note for each scale degree
class MusicalKey {
  final String name;
  final int root; // 0-11 pitch class (C=0, C#=1, etc.)
  final bool isMinor;

  const MusicalKey({
    required this.name,
    required this.root,
    this.isMinor = false,
  });

  // Scale intervals in semitones from root
  static const _majorIntervals = [0, 2, 4, 5, 7, 9, 11];
  static const _minorIntervals = [0, 2, 3, 5, 7, 8, 10]; // Natural minor

  /// Get the scale intervals for this key's mode
  List<int> get scaleIntervals => isMinor ? _minorIntervals : _majorIntervals;

  /// Get the root pitch class (0-11) for a scale degree (1-7)
  int degreeRoot(int degree) {
    assert(degree >= 1 && degree <= 7, 'Degree must be 1-7');
    return (root + scaleIntervals[degree - 1]) % 12;
  }

  /// Get the note name for a scale degree
  String degreeName(int degree) {
    return _noteNames[degreeRoot(degree)];
  }

  /// Get the default diatonic chord recipe for a scale degree (1-7)
  ChordRecipe diatonicRecipe(int degree) {
    assert(degree >= 1 && degree <= 7, 'Degree must be 1-7');

    if (isMinor) {
      // Natural minor: i, ii°, III, iv, v, VI, VII
      const recipes = [
        ChordRecipes.minor, // i
        ChordRecipes.diminished, // ii°
        ChordRecipes.major, // III
        ChordRecipes.minor, // iv
        ChordRecipes.minor, // v
        ChordRecipes.major, // VI
        ChordRecipes.major, // VII
      ];
      return recipes[degree - 1];
    } else {
      // Major: I, ii, iii, IV, V, vi, vii°
      const recipes = [
        ChordRecipes.major, // I
        ChordRecipes.minor, // ii
        ChordRecipes.minor, // iii
        ChordRecipes.major, // IV
        ChordRecipes.major, // V
        ChordRecipes.minor, // vi
        ChordRecipes.diminished, // vii°
      ];
      return recipes[degree - 1];
    }
  }

  /// Get the full chord name for a degree (e.g., "Dm" for ii in C major)
  String chordName(int degree, [ChordRecipe? override]) {
    final recipe = override ?? diatonicRecipe(degree);
    final noteName = degreeName(degree);
    return '$noteName${recipe.symbol}';
  }

  /// Display name (e.g., "C major" or "A minor")
  String get displayName => '$name ${isMinor ? 'minor' : 'major'}';

  /// Short display (e.g., "C" or "Am")
  String get shortName => isMinor ? '${name}m' : name;

  /// Get the relative major/minor key
  MusicalKey get relative {
    if (isMinor) {
      // Relative major is 3 semitones up
      final majorRoot = (root + 3) % 12;
      return MusicalKeys.byRoot(majorRoot, isMinor: false);
    } else {
      // Relative minor is 3 semitones down
      final minorRoot = (root + 9) % 12; // +9 = -3 mod 12
      return MusicalKeys.byRoot(minorRoot, isMinor: true);
    }
  }

  /// Get the parallel major/minor key (same root, different mode)
  MusicalKey get parallel {
    return MusicalKeys.byRoot(root, isMinor: !isMinor);
  }

  @override
  String toString() => 'MusicalKey($shortName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicalKey &&
          runtimeType == other.runtimeType &&
          root == other.root &&
          isMinor == other.isMinor;

  @override
  int get hashCode => root.hashCode ^ isMinor.hashCode;
}

/// All available musical keys
class MusicalKeys {
  // Prevent instantiation
  MusicalKeys._();

  // === MAJOR KEYS ===

  static const cMajor = MusicalKey(name: 'C', root: 0);
  static const cSharpMajor = MusicalKey(name: 'C#', root: 1);
  static const dMajor = MusicalKey(name: 'D', root: 2);
  static const dSharpMajor = MusicalKey(name: 'D#', root: 3);
  static const eMajor = MusicalKey(name: 'E', root: 4);
  static const fMajor = MusicalKey(name: 'F', root: 5);
  static const fSharpMajor = MusicalKey(name: 'F#', root: 6);
  static const gMajor = MusicalKey(name: 'G', root: 7);
  static const gSharpMajor = MusicalKey(name: 'G#', root: 8);
  static const aMajor = MusicalKey(name: 'A', root: 9);
  static const aSharpMajor = MusicalKey(name: 'A#', root: 10);
  static const bMajor = MusicalKey(name: 'B', root: 11);

  // === MINOR KEYS ===

  static const cMinor = MusicalKey(name: 'C', root: 0, isMinor: true);
  static const cSharpMinor = MusicalKey(name: 'C#', root: 1, isMinor: true);
  static const dMinor = MusicalKey(name: 'D', root: 2, isMinor: true);
  static const dSharpMinor = MusicalKey(name: 'D#', root: 3, isMinor: true);
  static const eMinor = MusicalKey(name: 'E', root: 4, isMinor: true);
  static const fMinor = MusicalKey(name: 'F', root: 5, isMinor: true);
  static const fSharpMinor = MusicalKey(name: 'F#', root: 6, isMinor: true);
  static const gMinor = MusicalKey(name: 'G', root: 7, isMinor: true);
  static const gSharpMinor = MusicalKey(name: 'G#', root: 8, isMinor: true);
  static const aMinor = MusicalKey(name: 'A', root: 9, isMinor: true);
  static const aSharpMinor = MusicalKey(name: 'A#', root: 10, isMinor: true);
  static const bMinor = MusicalKey(name: 'B', root: 11, isMinor: true);

  // === LISTS ===

  /// All major keys in chromatic order (for petal wheel)
  static const chromaticMajor = [
    cMajor,
    cSharpMajor,
    dMajor,
    dSharpMajor,
    eMajor,
    fMajor,
    fSharpMajor,
    gMajor,
    gSharpMajor,
    aMajor,
    aSharpMajor,
    bMajor,
  ];

  /// All minor keys in chromatic order (for petal wheel)
  static const chromaticMinor = [
    cMinor,
    cSharpMinor,
    dMinor,
    dSharpMinor,
    eMinor,
    fMinor,
    fSharpMinor,
    gMinor,
    gSharpMinor,
    aMinor,
    aSharpMinor,
    bMinor,
  ];

  /// Major keys in circle of fifths order (for Explorer mode)
  static const circleOfFifthsMajor = [
    cMajor, // 12 o'clock
    gMajor,
    dMajor,
    aMajor,
    eMajor,
    bMajor,
    fSharpMajor, // 6 o'clock (enharmonic with Gb)
    cSharpMajor, // (enharmonic with Db)
    gSharpMajor, // (enharmonic with Ab)
    dSharpMajor, // (enharmonic with Eb)
    aSharpMajor, // (enharmonic with Bb)
    fMajor,
  ];

  /// Relative minors in circle of fifths order (for Explorer mode)
  static const circleOfFifthsMinor = [
    aMinor, // Relative of C
    eMinor, // Relative of G
    bMinor, // Relative of D
    fSharpMinor, // Relative of A
    cSharpMinor, // Relative of E
    gSharpMinor, // Relative of B
    dSharpMinor, // Relative of F#
    aSharpMinor, // Relative of C#
    fMinor, // Relative of G#/Ab
    cMinor, // Relative of D#/Eb
    gMinor, // Relative of A#/Bb
    dMinor, // Relative of F
  ];

  /// Get key by petal position (0-11) and ring (outer/inner)
  /// 
  /// In Songwriter mode: chromatic order, outer=major, inner=minor (parallel)
  /// In Explorer mode: circle of fifths, outer=major, inner=minor (relative)
  static MusicalKey byPetalChromatic(int position, {required bool inner}) {
    final list = inner ? chromaticMinor : chromaticMajor;
    return list[position % 12];
  }

  static MusicalKey byPetalCircleOfFifths(int position, {required bool inner}) {
    final list = inner ? circleOfFifthsMinor : circleOfFifthsMajor;
    return list[position % 12];
  }

  /// Get key by root pitch class and mode
  static MusicalKey byRoot(int root, {bool isMinor = false}) {
    final list = isMinor ? chromaticMinor : chromaticMajor;
    return list[root % 12];
  }

  /// All keys
  static const all = [...chromaticMajor, ...chromaticMinor];
}
