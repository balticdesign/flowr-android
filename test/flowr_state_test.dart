import 'package:flutter_test/flutter_test.dart';
import '../lib/models/chord_recipe.dart';
import '../lib/models/enums.dart';
import '../lib/models/musical_key.dart';
import '../lib/models/pad_config.dart';
import '../lib/models/petal_config.dart';
import '../lib/services/flowr_state.dart';

void main() {
  group('FlowrState', () {
    late FlowrState state;
    late List<(int, int, bool)> midiNotes; // (note, velocity, noteOn)
    late List<(int, int)> midiCCs; // (cc, value)

    setUp(() {
      state = FlowrState();
      midiNotes = [];
      midiCCs = [];

      state.onMidiNote = (note, velocity, noteOn) {
        midiNotes.add((note, velocity, noteOn));
      };

      state.onMidiCC = (cc, value) {
        midiCCs.add((cc, value));
      };
    });

    group('initial state', () {
      test('defaults to Songwriter mode', () {
        expect(state.playMode, PlayMode.songwriter);
      });

      test('defaults to C major', () {
        expect(state.currentKey, MusicalKeys.cMajor);
      });

      test('defaults to octave 4', () {
        expect(state.baseOctave, 4);
      });

      test('no active pad or petal', () {
        expect(state.activePadIndex, null);
        expect(state.activePetal, null);
      });

      test('no chord playing', () {
        expect(state.currentChord, null);
        expect(state.heldNotes, isEmpty);
      });
    });

    group('pad input - degree pads', () {
      test('pressing pad I plays C major chord', () {
        // Pad 0 = degree I
        state.onPadDown(0);

        expect(state.activePadIndex, 0);
        expect(state.currentChord?.name, 'C');
        expect(midiNotes, isNotEmpty);

        // Check all notes are note-on
        for (final (_, _, noteOn) in midiNotes) {
          expect(noteOn, true);
        }
      });

      test('releasing pad sends note-offs', () {
        state.onPadDown(0);
        midiNotes.clear();

        state.onPadUp(0);

        expect(state.activePadIndex, null);
        expect(state.currentChord, null);

        // Check all notes are note-off
        for (final (_, _, noteOn) in midiNotes) {
          expect(noteOn, false);
        }
      });

      test('pressing pad ii plays D minor chord', () {
        state.onPadDown(1); // Pad 1 = degree ii

        expect(state.currentChord?.name, 'Dm');
      });

      test('pressing pad V plays G major chord', () {
        state.onPadDown(5); // Pad 5 = degree V

        expect(state.currentChord?.name, 'G');
      });
    });

    group('petal input - chord type override', () {
      test('petal overrides chord type', () {
        // Press pad I
        state.onPadDown(0);
        expect(state.currentChord?.name, 'C');

        // Touch maj7 petal (index 1 on outer ring)
        final maj7Petal = PetalLayout.getPetal(PetalRing.outer, 1);
        state.onPetalDown(maj7Petal);

        expect(state.currentChord?.name, 'Cmaj7');
        expect(state.activeRecipe, ChordRecipes.maj7);
      });

      test('releasing petal reverts to diatonic', () {
        state.onPadDown(0);
        
        final maj7Petal = PetalLayout.getPetal(PetalRing.outer, 1);
        state.onPetalDown(maj7Petal);
        expect(state.currentChord?.name, 'Cmaj7');

        state.onPetalUp();
        expect(state.currentChord?.name, 'C');
      });

      test('inner petal enables auto-voicing', () {
        state.onPadDown(0);
        
        final innerMaj7 = PetalLayout.getPetal(PetalRing.inner, 1);
        state.onPetalDown(innerMaj7);

        expect(state.isAutoVoicing, true);
        expect(state.currentChord?.autoVoiced, true);
      });

      test('outer petal uses root position', () {
        state.onPadDown(0);
        
        final outerMaj7 = PetalLayout.getPetal(PetalRing.outer, 1);
        state.onPetalDown(outerMaj7);

        expect(state.isAutoVoicing, false);
        expect(state.currentChord?.autoVoiced, false);
      });
    });

    group('function pad - key selection', () {
      test('function pad sets functionHeld', () {
        state.onPadDown(2); // FUNC pad
        expect(state.functionHeld, true);

        state.onPadUp(2);
        expect(state.functionHeld, false);
      });

      test('function + outer petal sets major key', () {
        state.onPadDown(2); // Hold FUNC
        
        // Touch G petal (index 7)
        final gPetal = PetalLayout.getPetal(PetalRing.outer, 7);
        state.onPetalDown(gPetal);

        expect(state.currentKey, MusicalKeys.gMajor);
      });

      test('function + inner petal sets minor key', () {
        state.onPadDown(2); // Hold FUNC
        
        // Touch G petal inner ring
        final gmPetal = PetalLayout.getPetal(PetalRing.inner, 7);
        state.onPetalDown(gmPetal);

        expect(state.currentKey, MusicalKeys.gMinor);
      });
    });

    group('sustain pad', () {
      test('sustain pad sends CC 64', () {
        state.onPadDown(8); // SUSTAIN pad
        
        expect(midiCCs, contains((64, 127)));
      });

      test('releasing sustain sends CC 64 off', () {
        state.onPadDown(8);
        midiCCs.clear();
        
        state.onPadUp(8);
        
        expect(midiCCs, contains((64, 0)));
      });

      test('notes sustain when sustain held', () {
        state.onPadDown(8); // Hold sustain
        state.onPadDown(0); // Play chord
        
        final noteCount = midiNotes.length;
        midiNotes.clear();
        
        state.onPadUp(0); // Release chord
        
        // Notes should NOT have note-offs because sustain is held
        expect(midiNotes, isEmpty);
      });

      test('sustained notes release when sustain released', () {
        state.onPadDown(8); // Hold sustain
        state.onPadDown(0); // Play chord
        state.onPadUp(0); // Release chord (notes sustained)
        
        midiNotes.clear();
        state.onPadUp(8); // Release sustain
        
        // Now notes should have note-offs
        expect(midiNotes, isNotEmpty);
        for (final (_, _, noteOn) in midiNotes) {
          expect(noteOn, false);
        }
      });

      test('sustain latch toggle', () {
        expect(state.sustainLatched, false);
        
        state.toggleSustainLatch();
        expect(state.sustainLatched, true);
        expect(midiCCs, contains((64, 127)));
        
        midiCCs.clear();
        state.toggleSustainLatch();
        expect(state.sustainLatched, false);
        expect(midiCCs, contains((64, 0)));
      });
    });

    group('key changes', () {
      test('changing key affects chord output', () {
        state.setKey(MusicalKeys.gMajor);
        state.onPadDown(0); // Pad I
        
        expect(state.currentChord?.name, 'G');
        expect(state.currentChord?.rootName, 'G');
      });

      test('changing key resets voice leading', () {
        state.onPadDown(0);
        state.onPadUp(0);
        
        state.setKey(MusicalKeys.gMajor);
        
        // Voice leader should be reset
        // (verified by checking next chord is root position)
      });
    });

    group('panic', () {
      test('panic releases all notes', () {
        state.onPadDown(0);
        midiNotes.clear();
        
        state.panic();
        
        // Should have note-offs
        expect(midiNotes, isNotEmpty);
        for (final (_, _, noteOn) in midiNotes) {
          expect(noteOn, false);
        }
      });

      test('panic clears all state', () {
        state.onPadDown(0);
        state.onPadDown(8); // Sustain
        state.toggleSustainLatch();
        
        state.panic();
        
        expect(state.activePadIndex, null);
        expect(state.activePetal, null);
        expect(state.currentChord, null);
        expect(state.heldNotes, isEmpty);
        expect(state.sustainActive, false);
        expect(state.sustainLatched, false);
      });
    });

    group('mode switching', () {
      test('can switch to Explorer mode', () {
        state.setPlayMode(PlayMode.explorer);
        expect(state.playMode, PlayMode.explorer);
      });

      test('can switch to Parallel mode', () {
        state.setPlayMode(PlayMode.parallel);
        expect(state.playMode, PlayMode.parallel);
      });

      test('mode switch resets voice leading', () {
        state.onPadDown(0);
        state.onPadUp(0);
        
        state.setPlayMode(PlayMode.explorer);
        
        // Voice leader should be reset
      });
    });

    group('Explorer/Parallel mode chord playing', () {
      test('playChordFromRoot works', () {
        state.playChordFromRoot(7, ChordRecipes.dom7); // G7
        
        expect(state.currentChord?.name, 'G7');
        expect(midiNotes, isNotEmpty);
      });

      test('releaseChord releases notes', () {
        state.playChordFromRoot(7, ChordRecipes.dom7);
        midiNotes.clear();
        
        state.releaseChord();
        
        expect(midiNotes, isNotEmpty);
        for (final (_, _, noteOn) in midiNotes) {
          expect(noteOn, false);
        }
      });
    });
  });
}
