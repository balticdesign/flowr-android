import 'dart:math' as math;
import 'chord_recipe.dart';
import 'enums.dart';

/// Configuration for a single petal
class PetalConfig {
  /// Petal index within its ring (0-11)
  final int index;

  /// Which ring (outer or inner)
  final PetalRing ring;

  /// Angle in radians (0 = top, clockwise)
  final double angle;

  /// Chord recipe for this petal
  final ChordRecipe recipe;

  const PetalConfig({
    required this.index,
    required this.ring,
    required this.angle,
    required this.recipe,
  });

  /// Angle in degrees (0 = top, clockwise)
  double get angleDegrees => angle * 180 / math.pi;

  /// Clock position (12 = top, 3 = right, etc.)
  int get clockPosition => ((index * 12 / 12) + 12).round() % 12;

  /// Is this an outer petal?
  bool get isOuter => ring == PetalRing.outer;

  /// Is this an inner petal?
  bool get isInner => ring == PetalRing.inner;

  /// Global index (0-23, outer first then inner)
  int get globalIndex => isOuter ? index : index + 12;
}

/// Layout configuration for the 24-petal wheel
class PetalLayout {
  // Prevent instantiation
  PetalLayout._();

  /// Number of petals per ring
  static const int petalsPerRing = 12;

  /// Total number of petals
  static const int totalPetals = 24;

  /// Angular spacing between petals (in radians)
  static final double petalSpacing = 2 * math.pi / petalsPerRing;

  /// Generate petal configs for both rings
  static List<PetalConfig> get allPetals {
    final petals = <PetalConfig>[];

    // Outer ring
    for (int i = 0; i < petalsPerRing; i++) {
      petals.add(PetalConfig(
        index: i,
        ring: PetalRing.outer,
        angle: i * petalSpacing,
        recipe: ChordRecipes.petalOrder[i],
      ));
    }

    // Inner ring (same recipes, different voicing behavior)
    for (int i = 0; i < petalsPerRing; i++) {
      petals.add(PetalConfig(
        index: i,
        ring: PetalRing.inner,
        angle: i * petalSpacing,
        recipe: ChordRecipes.petalOrder[i],
      ));
    }

    return petals;
  }

  /// Get outer ring petals only
  static List<PetalConfig> get outerPetals {
    return allPetals.where((p) => p.isOuter).toList();
  }

  /// Get inner ring petals only
  static List<PetalConfig> get innerPetals {
    return allPetals.where((p) => p.isInner).toList();
  }

  /// Get petal by ring and index
  static PetalConfig getPetal(PetalRing ring, int index) {
    final safeIndex = index % petalsPerRing;
    if (ring == PetalRing.outer) {
      return allPetals[safeIndex];
    } else {
      return allPetals[safeIndex + petalsPerRing];
    }
  }

  /// Get petal by global index (0-23)
  static PetalConfig getByGlobalIndex(int globalIndex) {
    final safeIndex = globalIndex % totalPetals;
    return allPetals[safeIndex];
  }

  /// Find petal index from angle (in radians)
  static int indexFromAngle(double angle) {
    // Normalize angle to 0-2π
    var normalized = angle % (2 * math.pi);
    if (normalized < 0) normalized += 2 * math.pi;

    // Add half spacing to center the detection zones
    normalized = (normalized + petalSpacing / 2) % (2 * math.pi);

    return (normalized / petalSpacing).floor() % petalsPerRing;
  }

  /// Find petal from polar coordinates
  /// 
  /// [angle] - Angle in radians (0 = top, clockwise)
  /// [radius] - Normalized radius (0 = center, 1 = edge)
  /// [innerThreshold] - Radius below which is inner ring (default 0.6)
  static PetalConfig? petalFromPolar(
    double angle,
    double radius, {
    double innerThreshold = 0.6,
    double minRadius = 0.2,
  }) {
    // Ignore touches too close to center
    if (radius < minRadius) return null;

    final index = indexFromAngle(angle);
    final ring = radius < innerThreshold ? PetalRing.inner : PetalRing.outer;

    return getPetal(ring, index);
  }

  /// Find petal from cartesian coordinates
  /// 
  /// [x], [y] - Position relative to center (-1 to 1)
  static PetalConfig? petalFromCartesian(
    double x,
    double y, {
    double innerThreshold = 0.6,
    double minRadius = 0.2,
  }) {
    final radius = math.sqrt(x * x + y * y);
    final angle = math.atan2(x, -y); // 0 at top, clockwise positive

    return petalFromPolar(
      angle,
      radius,
      innerThreshold: innerThreshold,
      minRadius: minRadius,
    );
  }

  /// Get the angle for a petal index (for drawing)
  static double angleForIndex(int index) {
    return index * petalSpacing;
  }

  /// Get chord recipe for a petal position
  static ChordRecipe recipeForPetal(PetalRing ring, int index) {
    return ChordRecipes.petalOrder[index % petalsPerRing];
  }
}
