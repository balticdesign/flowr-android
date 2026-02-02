import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/chord_recipe.dart';
import '../lib/models/enums.dart';
import '../lib/models/petal_config.dart';

void main() {
  group('PetalLayout', () {
    test('allPetals has 24 items', () {
      expect(PetalLayout.allPetals.length, 24);
    });

    test('outerPetals has 12 items', () {
      expect(PetalLayout.outerPetals.length, 12);
    });

    test('innerPetals has 12 items', () {
      expect(PetalLayout.innerPetals.length, 12);
    });

    test('outer petals are at outer ring', () {
      for (final petal in PetalLayout.outerPetals) {
        expect(petal.ring, PetalRing.outer);
        expect(petal.isOuter, true);
        expect(petal.isInner, false);
      }
    });

    test('inner petals are at inner ring', () {
      for (final petal in PetalLayout.innerPetals) {
        expect(petal.ring, PetalRing.inner);
        expect(petal.isInner, true);
        expect(petal.isOuter, false);
      }
    });

    test('petal 0 is at 12 oclock (angle 0)', () {
      final petal = PetalLayout.getPetal(PetalRing.outer, 0);
      expect(petal.angle, 0);
    });

    test('petal 6 is at 6 oclock (angle pi)', () {
      final petal = PetalLayout.getPetal(PetalRing.outer, 6);
      expect(petal.angle, closeTo(math.pi, 0.001));
    });

    test('petal recipes match ChordRecipes.petalOrder', () {
      for (int i = 0; i < 12; i++) {
        final petal = PetalLayout.getPetal(PetalRing.outer, i);
        expect(petal.recipe, ChordRecipes.petalOrder[i]);
      }
    });

    test('inner petals have same recipes as outer', () {
      for (int i = 0; i < 12; i++) {
        final outer = PetalLayout.getPetal(PetalRing.outer, i);
        final inner = PetalLayout.getPetal(PetalRing.inner, i);
        expect(outer.recipe, inner.recipe);
      }
    });

    group('indexFromAngle', () {
      test('angle 0 returns index 0', () {
        expect(PetalLayout.indexFromAngle(0), 0);
      });

      test('angle pi returns index 6', () {
        expect(PetalLayout.indexFromAngle(math.pi), 6);
      });

      test('angle -pi/6 returns index 11', () {
        // Slightly before 12 oclock (counterclockwise)
        expect(PetalLayout.indexFromAngle(-math.pi / 6), 11);
      });

      test('angle 2*pi returns index 0 (wraps)', () {
        expect(PetalLayout.indexFromAngle(2 * math.pi), 0);
      });
    });

    group('petalFromPolar', () {
      test('returns null for center touches', () {
        expect(PetalLayout.petalFromPolar(0, 0.1), null);
      });

      test('returns outer petal for large radius', () {
        final petal = PetalLayout.petalFromPolar(0, 0.8);
        expect(petal?.ring, PetalRing.outer);
      });

      test('returns inner petal for small radius', () {
        final petal = PetalLayout.petalFromPolar(0, 0.4);
        expect(petal?.ring, PetalRing.inner);
      });

      test('returns correct index for angle', () {
        final petal = PetalLayout.petalFromPolar(math.pi, 0.8);
        expect(petal?.index, 6);
      });
    });

    group('petalFromCartesian', () {
      test('top center returns petal 0', () {
        final petal = PetalLayout.petalFromCartesian(0, -0.8);
        expect(petal?.index, 0);
      });

      test('right center returns petal 3', () {
        final petal = PetalLayout.petalFromCartesian(0.8, 0);
        expect(petal?.index, 3);
      });

      test('bottom center returns petal 6', () {
        final petal = PetalLayout.petalFromCartesian(0, 0.8);
        expect(petal?.index, 6);
      });

      test('left center returns petal 9', () {
        final petal = PetalLayout.petalFromCartesian(-0.8, 0);
        expect(petal?.index, 9);
      });
    });

    group('globalIndex', () {
      test('outer petals have globalIndex 0-11', () {
        for (int i = 0; i < 12; i++) {
          final petal = PetalLayout.getPetal(PetalRing.outer, i);
          expect(petal.globalIndex, i);
        }
      });

      test('inner petals have globalIndex 12-23', () {
        for (int i = 0; i < 12; i++) {
          final petal = PetalLayout.getPetal(PetalRing.inner, i);
          expect(petal.globalIndex, i + 12);
        }
      });

      test('getByGlobalIndex returns correct petal', () {
        for (int i = 0; i < 24; i++) {
          final petal = PetalLayout.getByGlobalIndex(i);
          expect(petal.globalIndex, i);
        }
      });
    });
  });
}
