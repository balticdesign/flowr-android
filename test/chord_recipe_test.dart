import 'package:flutter_test/flutter_test.dart';
import '../lib/models/chord_recipe.dart';

void main() {
  group('ChordRecipe', () {
    test('major chord has correct intervals', () {
      expect(ChordRecipes.major.intervals, [0, 4, 7]);
    });

    test('minor chord has correct intervals', () {
      expect(ChordRecipes.minor.intervals, [0, 3, 7]);
    });

    test('toPitchClasses converts correctly from C', () {
      final pitchClasses = ChordRecipes.major.toPitchClasses(0); // C
      expect(pitchClasses, [0, 4, 7]); // C, E, G
    });

    test('toPitchClasses wraps around at 12', () {
      final pitchClasses = ChordRecipes.major.toPitchClasses(9); // A
      expect(pitchClasses, [9, 1, 4]); // A, C#, E
    });

    test('dom7 has four notes', () {
      expect(ChordRecipes.dom7.noteCount, 4);
    });

    test('maj9 has five notes', () {
      expect(ChordRecipes.maj9.noteCount, 5);
    });

    test('petalOrder has 12 recipes', () {
      expect(ChordRecipes.petalOrder.length, 12);
    });

    test('byPetalIndex returns correct recipe', () {
      expect(ChordRecipes.byPetalIndex(0), ChordRecipes.major);
      expect(ChordRecipes.byPetalIndex(6), ChordRecipes.min7);
    });

    test('byPetalIndex wraps around', () {
      expect(ChordRecipes.byPetalIndex(12), ChordRecipes.major);
      expect(ChordRecipes.byPetalIndex(-1), ChordRecipes.augmented);
    });
  });
}
