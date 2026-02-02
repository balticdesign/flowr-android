import 'package:flutter_test/flutter_test.dart';
import '../lib/models/chord_recipe.dart';
import '../lib/models/musical_key.dart';

void main() {
  group('MusicalKey', () {
    group('degreeRoot', () {
      test('C major degrees return correct roots', () {
        const key = MusicalKeys.cMajor;
        expect(key.degreeRoot(1), 0); // C
        expect(key.degreeRoot(2), 2); // D
        expect(key.degreeRoot(3), 4); // E
        expect(key.degreeRoot(4), 5); // F
        expect(key.degreeRoot(5), 7); // G
        expect(key.degreeRoot(6), 9); // A
        expect(key.degreeRoot(7), 11); // B
      });

      test('G major degrees return correct roots', () {
        const key = MusicalKeys.gMajor;
        expect(key.degreeRoot(1), 7); // G
        expect(key.degreeRoot(2), 9); // A
        expect(key.degreeRoot(3), 11); // B
        expect(key.degreeRoot(4), 0); // C
        expect(key.degreeRoot(5), 2); // D
        expect(key.degreeRoot(6), 4); // E
        expect(key.degreeRoot(7), 6); // F#
      });

      test('A minor degrees return correct roots', () {
        const key = MusicalKeys.aMinor;
        expect(key.degreeRoot(1), 9); // A
        expect(key.degreeRoot(2), 11); // B
        expect(key.degreeRoot(3), 0); // C
        expect(key.degreeRoot(4), 2); // D
        expect(key.degreeRoot(5), 4); // E
        expect(key.degreeRoot(6), 5); // F
        expect(key.degreeRoot(7), 7); // G
      });
    });

    group('diatonicRecipe', () {
      test('C major diatonic chords are correct', () {
        const key = MusicalKeys.cMajor;
        expect(key.diatonicRecipe(1), ChordRecipes.major); // I
        expect(key.diatonicRecipe(2), ChordRecipes.minor); // ii
        expect(key.diatonicRecipe(3), ChordRecipes.minor); // iii
        expect(key.diatonicRecipe(4), ChordRecipes.major); // IV
        expect(key.diatonicRecipe(5), ChordRecipes.major); // V
        expect(key.diatonicRecipe(6), ChordRecipes.minor); // vi
        expect(key.diatonicRecipe(7), ChordRecipes.diminished); // vii°
      });

      test('A minor diatonic chords are correct', () {
        const key = MusicalKeys.aMinor;
        expect(key.diatonicRecipe(1), ChordRecipes.minor); // i
        expect(key.diatonicRecipe(2), ChordRecipes.diminished); // ii°
        expect(key.diatonicRecipe(3), ChordRecipes.major); // III
        expect(key.diatonicRecipe(4), ChordRecipes.minor); // iv
        expect(key.diatonicRecipe(5), ChordRecipes.minor); // v
        expect(key.diatonicRecipe(6), ChordRecipes.major); // VI
        expect(key.diatonicRecipe(7), ChordRecipes.major); // VII
      });
    });

    group('chordName', () {
      test('returns correct chord names in C major', () {
        const key = MusicalKeys.cMajor;
        expect(key.chordName(1), 'C');
        expect(key.chordName(2), 'Dm');
        expect(key.chordName(4), 'F');
        expect(key.chordName(5), 'G');
        expect(key.chordName(6), 'Am');
        expect(key.chordName(7), 'Bdim');
      });

      test('override recipe changes chord name', () {
        const key = MusicalKeys.cMajor;
        expect(key.chordName(5, ChordRecipes.dom7), 'G7');
        expect(key.chordName(1, ChordRecipes.maj7), 'Cmaj7');
        expect(key.chordName(2, ChordRecipes.min7), 'Dm7');
      });
    });

    group('relative', () {
      test('C major relative is A minor', () {
        expect(MusicalKeys.cMajor.relative, MusicalKeys.aMinor);
      });

      test('A minor relative is C major', () {
        expect(MusicalKeys.aMinor.relative, MusicalKeys.cMajor);
      });

      test('G major relative is E minor', () {
        expect(MusicalKeys.gMajor.relative, MusicalKeys.eMinor);
      });
    });

    group('parallel', () {
      test('C major parallel is C minor', () {
        expect(MusicalKeys.cMajor.parallel, MusicalKeys.cMinor);
      });

      test('A minor parallel is A major', () {
        expect(MusicalKeys.aMinor.parallel, MusicalKeys.aMajor);
      });
    });
  });

  group('MusicalKeys', () {
    test('chromaticMajor has 12 keys', () {
      expect(MusicalKeys.chromaticMajor.length, 12);
    });

    test('chromaticMinor has 12 keys', () {
      expect(MusicalKeys.chromaticMinor.length, 12);
    });

    test('byPetalChromatic returns correct major keys', () {
      expect(
        MusicalKeys.byPetalChromatic(0, inner: false),
        MusicalKeys.cMajor,
      );
      expect(
        MusicalKeys.byPetalChromatic(7, inner: false),
        MusicalKeys.gMajor,
      );
    });

    test('byPetalChromatic returns correct minor keys', () {
      expect(
        MusicalKeys.byPetalChromatic(0, inner: true),
        MusicalKeys.cMinor,
      );
      expect(
        MusicalKeys.byPetalChromatic(9, inner: true),
        MusicalKeys.aMinor,
      );
    });

    test('byRoot returns correct key', () {
      expect(MusicalKeys.byRoot(0), MusicalKeys.cMajor);
      expect(MusicalKeys.byRoot(0, isMinor: true), MusicalKeys.cMinor);
      expect(MusicalKeys.byRoot(7), MusicalKeys.gMajor);
    });
  });
}
