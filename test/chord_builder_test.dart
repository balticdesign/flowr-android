import 'package:flutter_test/flutter_test.dart';
import '../lib/models/chord_recipe.dart';
import '../lib/models/musical_key.dart';
import '../lib/services/chord_builder.dart';
import '../lib/services/voice_leader.dart';

void main() {
  group('ChordBuilder', () {
    group('build with diatonic defaults', () {
      test('C major I chord is C major', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 1);
        
        expect(chord.name, 'C');
        expect(chord.recipe, ChordRecipes.major);
        expect(chord.rootName, 'C');
        expect(chord.degree, 1);
        
        // Check pitch classes
        final pitchClasses = chord.notes.map((n) => n % 12).toList();
        expect(pitchClasses, containsAll([0, 4, 7])); // C, E, G
      });

      test('C major ii chord is D minor', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 2);
        
        expect(chord.name, 'Dm');
        expect(chord.recipe, ChordRecipes.minor);
        expect(chord.rootName, 'D');
      });

      test('C major V chord is G major', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 5);
        
        expect(chord.name, 'G');
        expect(chord.recipe, ChordRecipes.major);
        expect(chord.rootName, 'G');
      });

      test('C major vii chord is B diminished', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 7);
        
        expect(chord.name, 'Bdim');
        expect(chord.recipe, ChordRecipes.diminished);
        expect(chord.rootName, 'B');
      });

      test('A minor i chord is A minor', () {
        final builder = ChordBuilder(key: MusicalKeys.aMinor);
        final chord = builder.build(degree: 1);
        
        expect(chord.name, 'Am');
        expect(chord.recipe, ChordRecipes.minor);
        expect(chord.rootName, 'A');
      });

      test('A minor III chord is C major', () {
        final builder = ChordBuilder(key: MusicalKeys.aMinor);
        final chord = builder.build(degree: 3);
        
        expect(chord.name, 'C');
        expect(chord.recipe, ChordRecipes.major);
        expect(chord.rootName, 'C');
      });
    });

    group('build with recipe override', () {
      test('C major V with dom7 override is G7', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 5, recipe: ChordRecipes.dom7);
        
        expect(chord.name, 'G7');
        expect(chord.recipe, ChordRecipes.dom7);
        expect(chord.notes.length, 4); // 4-note chord
      });

      test('C major ii with m7 override is Dm7', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 2, recipe: ChordRecipes.min7);
        
        expect(chord.name, 'Dm7');
        expect(chord.recipe, ChordRecipes.min7);
      });

      test('C major I with maj9 override is Cmaj9', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.build(degree: 1, recipe: ChordRecipes.maj9);
        
        expect(chord.name, 'Cmaj9');
        expect(chord.notes.length, 5); // 5-note chord
      });
    });

    group('build with auto-voicing', () {
      test('auto-voiced chord has smooth voice leading', () {
        final voiceLeader = VoiceLeader();
        final builder = ChordBuilder(
          key: MusicalKeys.cMajor,
          voiceLeader: voiceLeader,
        );
        
        // Build first chord
        final c = builder.build(degree: 1, autoVoice: true);
        expect(c.autoVoiced, true);
        
        // Build second chord
        final g = builder.build(degree: 5, autoVoice: true);
        expect(g.autoVoiced, true);
        
        // Check movement is reasonable
        int movement = 0;
        for (final newNote in g.notes) {
          int minDist = 127;
          for (final oldNote in c.notes) {
            final dist = (newNote - oldNote).abs();
            if (dist < minDist) minDist = dist;
          }
          movement += minDist;
        }
        
        expect(movement, lessThan(20));
      });
    });

    group('buildFromRoot', () {
      test('builds chord from absolute root', () {
        final builder = ChordBuilder(key: MusicalKeys.cMajor);
        final chord = builder.buildFromRoot(
          rootPitchClass: 7, // G
          recipe: ChordRecipes.dom7,
        );
        
        expect(chord.name, 'G7');
        expect(chord.rootName, 'G');
        expect(chord.degree, null); // No degree for absolute root
      });
    });

    group('withKey', () {
      test('creates new builder with different key', () {
        final builder1 = ChordBuilder(key: MusicalKeys.cMajor);
        final builder2 = builder1.withKey(MusicalKeys.gMajor);
        
        final chord1 = builder1.build(degree: 1);
        final chord2 = builder2.build(degree: 1);
        
        expect(chord1.name, 'C');
        expect(chord2.name, 'G');
      });
    });

    group('withOctave', () {
      test('creates new builder with different octave', () {
        final builder1 = ChordBuilder(key: MusicalKeys.cMajor, baseOctave: 4);
        final builder2 = builder1.withOctave(3);
        
        final chord1 = builder1.build(degree: 1);
        final chord2 = builder2.build(degree: 1);
        
        // Octave 3 chord should be 12 semitones lower
        expect(chord2.notes[0], chord1.notes[0] - 12);
      });
    });

    group('different keys', () {
      test('G major I is G', () {
        final builder = ChordBuilder(key: MusicalKeys.gMajor);
        final chord = builder.build(degree: 1);
        expect(chord.name, 'G');
      });

      test('G major IV is C', () {
        final builder = ChordBuilder(key: MusicalKeys.gMajor);
        final chord = builder.build(degree: 4);
        expect(chord.name, 'C');
      });

      test('D minor i is Dm', () {
        final builder = ChordBuilder(key: MusicalKeys.dMinor);
        final chord = builder.build(degree: 1);
        expect(chord.name, 'Dm');
      });
    });
  });
}
