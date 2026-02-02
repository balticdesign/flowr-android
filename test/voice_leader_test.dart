import 'package:flutter_test/flutter_test.dart';
import '../lib/services/voice_leader.dart';

void main() {
  group('VoiceLeader', () {
    late VoiceLeader voiceLeader;

    setUp(() {
      voiceLeader = VoiceLeader();
    });

    group('voice', () {
      test('first chord returns root position', () {
        // C major: C=0, E=4, G=7
        final result = voiceLeader.voice([0, 4, 7], 0);
        
        // Should be in octave 3 or 4, root position
        expect(result.length, 3);
        expect(result[0] % 12, 0); // C in bass
        expect(result[1] % 12, 4); // E
        expect(result[2] % 12, 7); // G
      });

      test('subsequent chord minimises movement', () {
        // First chord: C major (C-E-G)
        final c = voiceLeader.voice([0, 4, 7], 0);
        
        // Second chord: G major (G-B-D)
        // Closest voicing to C-E-G should have minimal movement
        final g = voiceLeader.voice([7, 11, 2], 7);
        
        // Calculate total movement
        int movement = 0;
        for (final newNote in g) {
          int minDist = 127;
          for (final oldNote in c) {
            final dist = (newNote - oldNote).abs();
            if (dist < minDist) minDist = dist;
          }
          movement += minDist;
        }
        
        // Movement should be reasonable (not huge jumps)
        expect(movement, lessThan(20));
      });

      test('respects pitch range', () {
        final voiceLeader = VoiceLeader(minPitch: 48, maxPitch: 72);
        
        final result = voiceLeader.voice([0, 4, 7], 0);
        
        for (final note in result) {
          expect(note, greaterThanOrEqualTo(48));
          expect(note, lessThanOrEqualTo(72));
        }
      });
    });

    group('voiceRootPosition', () {
      test('returns root position voicing', () {
        final result = voiceLeader.voiceRootPosition([0, 4, 7], octave: 4);
        
        expect(result.length, 3);
        expect(result[0], 48); // C4
        expect(result[1], 52); // E4
        expect(result[2], 55); // G4
      });
    });

    group('reset', () {
      test('clears previous chord context', () {
        // Voice a chord
        voiceLeader.voice([0, 4, 7], 0);
        expect(voiceLeader.hasContext, true);
        
        // Reset
        voiceLeader.reset();
        expect(voiceLeader.hasContext, false);
      });

      test('next chord after reset uses root position', () {
        // Voice some chords
        voiceLeader.voice([0, 4, 7], 0);
        voiceLeader.voice([7, 11, 2], 7);
        
        // Reset
        voiceLeader.reset();
        
        // Next chord should be root position
        final result = voiceLeader.voice([5, 9, 0], 5); // F major
        expect(result[0] % 12, 5); // F in bass
      });
    });

    group('progression example', () {
      test('C-G-Am-F progression has smooth voice leading', () {
        // C major: C-E-G
        final c = voiceLeader.voice([0, 4, 7], 0);
        
        // G major: G-B-D
        final g = voiceLeader.voice([7, 11, 2], 7);
        
        // A minor: A-C-E
        final am = voiceLeader.voice([9, 0, 4], 9);
        
        // F major: F-A-C
        final f = voiceLeader.voice([5, 9, 0], 5);
        
        // All chords should be within range
        for (final chord in [c, g, am, f]) {
          for (final note in chord) {
            expect(note, greaterThanOrEqualTo(48));
            expect(note, lessThanOrEqualTo(84));
          }
        }
        
        // Calculate average movement per chord change
        int totalMovement = 0;
        totalMovement += _chordMovement(c, g);
        totalMovement += _chordMovement(g, am);
        totalMovement += _chordMovement(am, f);
        
        final avgMovement = totalMovement / 3;
        
        // Average movement should be small (good voice leading)
        expect(avgMovement, lessThan(15));
      });
    });
  });
}

int _chordMovement(List<int> from, List<int> to) {
  int total = 0;
  for (final newNote in to) {
    int minDist = 127;
    for (final oldNote in from) {
      final dist = (newNote - oldNote).abs();
      if (dist < minDist) minDist = dist;
    }
    total += minDist;
  }
  return total;
}
