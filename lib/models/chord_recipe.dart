/// A chord recipe defines the intervals that make up a chord type.
/// 
/// Intervals are in semitones from the root note.
/// For example, a major triad is [0, 4, 7] (root, major 3rd, perfect 5th).
class ChordRecipe {
  final String name;
  final String symbol;
  final List<int> intervals;

  const ChordRecipe({
    required this.name,
    required this.symbol,
    required this.intervals,
  });

  /// Convert intervals to pitch classes given a root pitch class (0-11)
  List<int> toPitchClasses(int rootPitchClass) {
    return intervals.map((i) => (rootPitchClass + i) % 12).toList();
  }

  /// Number of notes in the chord
  int get noteCount => intervals.length;

  /// Display name with symbol (e.g., "Major 7 (maj7)")
  String get displayName => symbol.isEmpty ? name : '$name ($symbol)';

  @override
  String toString() => 'ChordRecipe($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChordRecipe &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// All available chord recipes
class ChordRecipes {
  // Prevent instantiation
  ChordRecipes._();

  // === TRIADS ===

  static const major = ChordRecipe(
    name: 'Major',
    symbol: '',
    intervals: [0, 4, 7],
  );

  static const minor = ChordRecipe(
    name: 'Minor',
    symbol: 'm',
    intervals: [0, 3, 7],
  );

  static const diminished = ChordRecipe(
    name: 'Diminished',
    symbol: 'dim',
    intervals: [0, 3, 6],
  );

  static const augmented = ChordRecipe(
    name: 'Augmented',
    symbol: 'aug',
    intervals: [0, 4, 8],
  );

  // === SUSPENDED ===

  static const sus2 = ChordRecipe(
    name: 'Sus 2',
    symbol: 'sus2',
    intervals: [0, 2, 7],
  );

  static const sus4 = ChordRecipe(
    name: 'Sus 4',
    symbol: 'sus4',
    intervals: [0, 5, 7],
  );

  // === SIXTHS ===

  static const six = ChordRecipe(
    name: '6',
    symbol: '6',
    intervals: [0, 4, 7, 9],
  );

  // === SEVENTHS ===

  static const maj7 = ChordRecipe(
    name: 'Major 7',
    symbol: 'maj7',
    intervals: [0, 4, 7, 11],
  );

  static const min7 = ChordRecipe(
    name: 'Minor 7',
    symbol: 'm7',
    intervals: [0, 3, 7, 10],
  );

  static const dom7 = ChordRecipe(
    name: 'Dominant 7',
    symbol: '7',
    intervals: [0, 4, 7, 10],
  );

  // === NINTHS ===

  static const maj9 = ChordRecipe(
    name: 'Major 9',
    symbol: 'maj9',
    intervals: [0, 4, 7, 11, 14],
  );

  static const min9 = ChordRecipe(
    name: 'Minor 9',
    symbol: 'm9',
    intervals: [0, 3, 7, 10, 14],
  );

  static const add9 = ChordRecipe(
    name: 'Add 9',
    symbol: 'add9',
    intervals: [0, 4, 7, 14],
  );

  // === PETAL WHEEL ORDER ===
  // Clockwise from 12 o'clock
  // Bright hemisphere (12-5), Dark hemisphere (6-11)

  static const petalOrder = <ChordRecipe>[
    major, // 12:00 - bright
    maj7, //  1:00
    maj9, //  2:00
    add9, //  3:00
    six, //   4:00
    sus2, //  5:00
    min7, //  6:00 - dark
    min9, //  7:00
    sus4, //  8:00
    dom7, //  9:00
    diminished, // 10:00
    augmented, //  11:00
  ];

  /// Get recipe by petal index (0-11)
  static ChordRecipe byPetalIndex(int index) {
    return petalOrder[index % 12];
  }

  /// Get petal index for a recipe (-1 if not found)
  static int petalIndexOf(ChordRecipe recipe) {
    return petalOrder.indexOf(recipe);
  }

  /// All recipes as a list
  static const all = <ChordRecipe>[
    major,
    minor,
    diminished,
    augmented,
    sus2,
    sus4,
    six,
    maj7,
    min7,
    dom7,
    maj9,
    min9,
    add9,
  ];

  /// Find recipe by symbol
  static ChordRecipe? bySymbol(String symbol) {
    for (final recipe in all) {
      if (recipe.symbol == symbol) return recipe;
    }
    return null;
  }

  /// Find recipe by name
  static ChordRecipe? byName(String name) {
    for (final recipe in all) {
      if (recipe.name.toLowerCase() == name.toLowerCase()) return recipe;
    }
    return null;
  }
}
